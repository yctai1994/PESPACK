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

const IgorHeader = enum {};

const WavesInfo = struct {};

fn parseWaves(str: []const u8) void {
    const header: []const u8 = "WAVES";
    var index: usize = 0;

    for (header) |char| {
        if (char != str[index]) unreachable;
        index += 1;
    }

    if (str[index] == '/') {
        index += 1;
        if (str[index] != 'S' and str[index] != 'D') unreachable;
        index += 1;
    }

    if (str[index] == '/') {
        index += 1;
        if (str[index] == 'N') index += 1 else unreachable;
        if (str[index] == '=') index += 1 else unreachable;
    }

    std.debug.print("\n{any}\n", .{index});
}

test "test" {
    const str: []const u8 = "WAVES/S/N=(3,2) 'ID_001'";
    const ind: usize = 0;
    _ = .{ind};

    parseWaves(str);
}
