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

const std = @import("std");
const fmt = std.fmt;
const debug = std.debug;
const testing = std.testing;

fn intFromChar(char: u8) u8 {
    return switch (char) {
        '0'...'9' => char - 48,
        else => unreachable,
    };
}

const IgorTextErr = error{
    KeywordError,
    FlagError,
    SizeError,
};

const IgorHeader = enum {
    WAVES,

    fn getString(e: IgorHeader) []const u8 {
        return switch (e) {
            .WAVES => "WAVES",
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

test "test" {
    {
        const str: []const u8 = "WAVES/S/N=(201,132) 'ID_001'";
        const info: WavesInfo = parseWaves(str) catch unreachable;
        try testing.expect(info.nrow == 201);
        try testing.expect(info.ncol == 132);
        try testing.expect(std.mem.eql(u8, info.name, "'ID_001'"));
    }
    {
        const str: []const u8 = "WAVE//S/N=(3,2) 'ID_001'";
        _ = parseWaves(str) catch |err| {
            try testing.expect(err == error.KeywordError);
        };
    }
    {
        const str: []const u8 = "WAVES/I/N=(3,2) 'ID_001'";
        _ = parseWaves(str) catch |err| {
            try testing.expect(err == error.FlagError);
        };
    }
}
