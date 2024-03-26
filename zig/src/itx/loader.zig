// - Introduce comments with “X //”.
//
// - The WAVES keyword accepts the following optional flags:
//
//     Flag     | Effect
//     --------------------------------------------------------------------------
//     /N=(...) | Specifies size of each dimension for multidimensional waves.
//     /O       | Overwrites existing waves.
//     /R       | Makes waves real (default).
//     /C       | Makes waves complex.
//     /S       | Makes waves single (32-bit) precision floating point (default).
//     /D       | Makes waves double (64-bit) precision floating point.
//     /I       | Makes waves 32 bit integer.
//     /W       | Makes waves 16 bit integer.
//     /B       | Makes waves 8 bit integer.
//     /U       | Makes integer waves unsigned.
//     /T       | Specifies text data type.
//
// - Example #1:
//
//     IGOR
//     WAVES/D/N=(3,2) wave0
//     BEGIN
//     1 2
//     3 4
//     5 6
//     END
//
// - Example #2:
//
//     IGOR
//     WAVES/D/N=(3,2,2) wave0
//     BEGIN
//     1 2
//     3 4
//     5 6
//
//     11 12
//     13 14
//     15 16
//     END

const fs = std.fs;
const io = std.io;
const os = std.os;
const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const debug = std.debug;
const posix = std.posix;
const testing = std.testing;

const ReadError = error{
    BufferTooShort,
    EndOfFile,
} || posix.ReadError;

fn intFromChar(char: u8) u8 {
    return switch (char) {
        '0'...'9' => char - 48,
        else => unreachable,
    };
}

const IgorTextError = error{
    KeywordError,
    FlagError,
    SizeError,
};

const IgorHeader = enum {
    IGOR,
    WAVES,
    BEGIN,
    END,

    fn getString(e: IgorHeader) []const u8 {
        return switch (e) {
            .IGOR => "IGOR",
            .WAVES => "WAVES",
            .BEGIN => "BEGIN",
            .END => "END",
        };
    }
};

const WavesInfo = struct {
    nrow: usize,
    ncol: usize,
    name: []const u8,
};

fn parseWaves(str: []const u8) !WavesInfo {
    var ix: usize = 0;

    for (IgorHeader.getString(.WAVES)) |char| {
        if (char == str[ix]) ix += 1 else return error.KeywordError;
    }

    while (str[ix] == '/') {
        ix += 1;
        defer ix += 1;
        switch (str[ix]) {
            'S', 'D' => continue,
            'N' => break,
            else => return error.FlagError,
        }
    }

    if (str[ix] == '=') ix += 1 else return error.FlagError;
    if (str[ix] == '(') ix += 1 else return error.FlagError;

    var nrow: usize = 0;
    while (str[ix] != ',') : (ix += 1) {
        nrow = nrow * 10 + intFromChar(str[ix]);
    } else ix += 1;

    var ncol: usize = 0;
    while (str[ix] != ')') : (ix += 1) {
        ncol = ncol * 10 + intFromChar(str[ix]);
    } else ix += 1;

    while (str[ix] == ' ') ix += 1;

    return WavesInfo{ .nrow = nrow, .ncol = ncol, .name = str[ix..] };
}

fn parseRow(des: []f64, src: []const u8) !void {
    var px: usize = 0;
    var ix: usize = 0;

    for (src, 0..) |char, jx| {
        if (char != ' ') continue else {
            des[px] = try fmt.parseFloat(f64, src[ix..jx]);
            ix = jx + 1;
            px += 1;
        }
    }

    des[px] = try fmt.parseFloat(f64, src[ix..]);

    return;
}

test "test #1" {
    {
        const str: []const u8 = "WAVES/S/N=(201,132) 'ID_001'";
        const info: WavesInfo = parseWaves(str) catch unreachable;
        try testing.expect(info.nrow == 201);
        try testing.expect(info.ncol == 132);
        try testing.expect(std.mem.eql(u8, info.name, "'ID_001'"));
    }
    {
        const str: []const u8 = "WAVE//S/N=(201,132) 'ID_001'";
        _ = parseWaves(str) catch |err| {
            try testing.expect(err == error.KeywordError);
        };
    }
    {
        const str: []const u8 = "WAVES/I/N=(201,132) 'ID_001'";
        _ = parseWaves(str) catch |err| {
            try testing.expect(err == error.FlagError);
        };
    }
    {
        const src: []const u8 = "111.1 222.2 333.3";
        var des: [3]f64 = undefined;
        try parseRow(&des, src);
        debug.print("\n{any}\n", .{des});
    }
}

fn readByte(fd: posix.fd_t) ReadError!u8 {
    var result: [1]u8 = undefined;
    const amt_read = try posix.read(fd, result[0..]);
    if (amt_read < 1) return error.EndOfFile;
    return result[0];
}

fn nextline(buffer: []u8, file: posix.fd_t) ReadError![]u8 {
    var end: usize = 0;
    for (buffer) |*ptr| {
        if (readByte(file)) |byte| {
            if (byte == '\r') continue;
            if (byte == '\n') return buffer[0..end];
            ptr.* = byte;
            end += 1;
        } else |err| {
            if (err == error.EndOfFile) {
                return buffer[0..end];
            } else return err;
        }
    }
    return error.BufferTooShort;
}

// For Igor Text File:
//
//     ------------------------- (INIT)
//     IGOR
//     ------------------------- (IGOR)
//     WAVES/D/N=(3,2) wave0 --- (WAVES)
//     BEGIN
//     ------------------------- (BLOCK)
//     .
//     .
//     .
//     ------------------------- (BLOCK)
//     END
//     ------------------------- (MICS)
const State = enum {
    INIT,
    IGOR,
    WAVES,
    BLOCK,
    MICS,

    fn peek(self: State) ?[]const u8 {
        return switch (self) {
            .INIT => "IGOR",
            .IGOR => "WAVES",
            .WAVES => "BEGIN",
            .BLOCK => "END",
            .MICS => null,
        };
    }

    fn next(self: State) ?State {
        return switch (self) {
            .INIT => .IGOR,
            .IGOR => .WAVES,
            .WAVES => .BLOCK,
            .BLOCK => .MICS,
            .MICS => null,
        };
    }
};

test "test #2" {
    debug.print("\n", .{});

    const file: posix.fd_t = (try fs.cwd().openFile(
        "../../../assets/scan.itx",
        .{ .mode = .read_only },
    )).handle;
    defer posix.close(file);

    var buff: [128]u8 = undefined;
    var stat: ?State = .INIT;

    for (0..13) |_| {
        const line: []u8 = try nextline(&buff, file);

        debug.print(
            "{d: >4}: {s} (has \\r: {any})",
            .{ line.len, line, line[line.len - 1] == '\r' },
        );

        if (stat) |s| {
            if (s.peek()) |header| {
                if (mem.eql(u8, header, line[0..header.len])) {
                    debug.print(
                        " \x1b[31m=> INFO: from {any} to {any}\x1b[0m",
                        .{ s, s.next() },
                    );
                    stat = s.next();
                } else debug.print(" \x1b[31m=> INFO: state = {any}\x1b[0m", .{s});
            } else debug.print(" \x1b[31m=> INFO: state = {any}\x1b[0m", .{s});
        }

        debug.print("\n", .{});
    }
}
