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

    for ("WAVES") |char| {
        if (char == str[ix]) ix += 1 else return error.KeywordError;
    }

    // debug.print("ix = {d}\n", .{ix}); // ix = 5

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

    for (str[ix..], ix..) |char, jx| {
        switch (char) {
            ' ', '\r', '\n' => return WavesInfo{
                .nrow = nrow,
                .ncol = ncol,
                .name = str[ix..jx],
            },
            else => {},
        }
    }

    return WavesInfo{
        .nrow = nrow,
        .ncol = ncol,
        .name = str[ix..],
    };
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
        const str: []const u8 = "WAVES/S/N=(201,132) 'ID_001'\r";
        const info: WavesInfo = parseWaves(str) catch unreachable;
        try testing.expect(info.nrow == 201);
        try testing.expect(info.ncol == 132);
        try testing.expect(std.mem.eql(u8, info.name, "'ID_001'"));
    }
    {
        const str: []const u8 = "WAVES/S/N=(201,132) 'ID_001'\n";
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

fn nextLine(file: posix.fd_t, buffer: []u8) ReadError![]u8 {
    var end: usize = 0;
    while (end < buffer.len) {
        if (readByte(file)) |byte| {
            if (byte == '\r') continue else {
                buffer[end] = byte;
                end += 1;
            }
            if (byte == '\n') return buffer[0..end];
        } else |err| {
            if (err != error.EndOfFile) return err else {
                if (end < buffer.len) {
                    buffer[end] = '\n';
                    return buffer[0 .. end + 1];
                } else return error.BufferTooShort;
            }
        }
    }
    return error.BufferTooShort;
}

fn writeLine(info: posix.fd_t, data: posix.fd_t, line: []const u8, stat: State) !void {
    switch (stat) {
        .IGOR, .MISC => _ = try posix.write(info, line),
        .DATA => _ = try posix.write(data, line),
        else => {},
    }
    return;
}

// For Igor Text File:
//
//     ------------------------- (INIT)
//     IGOR
//     ------------------------- (IGOR)
//     WAVES/D/N=(3,2) wave0 --- (WAVE)
//     BEGIN
//     ------------------------- (DATA)
//     .
//     .
//     .
//     ------------------------- (DATA)
//     END
//     ------------------------- (MISC)
const State = enum {
    INIT,
    IGOR,
    WAVE,
    DATA,
    MISC,

    fn peek(self: State) ?[]const u8 {
        return switch (self) {
            .INIT => "IGOR",
            .IGOR => "WAVES",
            .WAVE => "BEGIN",
            .DATA => "END",
            .MISC => null,
        };
    }

    fn next(self: State) State {
        return switch (self) {
            .INIT => .IGOR,
            .IGOR => .WAVE,
            .WAVE => .DATA,
            .DATA => .MISC,
            .MISC => unreachable,
        };
    }
};

fn openFile(pth: []const u8) !posix.fd_t {
    const file: fs.File = try fs.cwd().openFile(pth, .{ .mode = .read_only });
    return file.handle;
}

fn createFile(pth: []const u8) !posix.fd_t {
    const file: fs.File = try fs.cwd().createFile(pth, .{ .read = false });
    return file.handle;
}

test "test #2" {
    debug.print("\n", .{});

    const igor: posix.fd_t = try openFile("../../../assets/scan.itx");
    const info: posix.fd_t = try createFile("../../../assets/scan.info");
    const data: posix.fd_t = try createFile("../../../assets/scan.data");
    defer {
        posix.close(igor);
        posix.close(info);
        posix.close(data);
    }

    var buff: [128]u8 = undefined;
    var stat: State = .INIT;

    for (0..15) |_| {
        const line: []u8 = try nextLine(igor, &buff);

        debug.print("{d: >4}: {s}", .{ line.len, line });

        if (stat.peek()) |header| {
            if (mem.eql(u8, header, line[0..header.len])) {
                stat = stat.next();
            } else try writeLine(info, data, line, stat);
        } else try writeLine(info, data, line, stat);

        debug.print("\x1b[31mINFO: {any}\x1b[0m\n", .{stat});
    }
}
