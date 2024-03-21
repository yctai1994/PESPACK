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

const WavesInfo = struct {};

fn parseWaves() WavesInfo {}

test "test" {
    const str: []const u8 = "WAVES/S/N=(3,2) 'ID_001'";
    const ind: usize = 0;
    _ = .{ str, ind };
}
