const std = @import("std");
const fmt = std.fmt;
const debug = std.debug;
const posix = std.posix;
const testing = std.testing;

const builtin = @import("builtin");
const native_endian = builtin.cpu.arch.endian();

const Status = @import("./Status.zig");
const Lexer = @import("./lexer.zig").Lexer;
const Waves = @import("./waves.zig").Waves;

const InfoWriter = @import("./InfoWriter.zig");
const DataWriter = @import("./DataWriter.zig");

test "Load Igor Text File" {
    debug.print("\n", .{});

    var lexer: Lexer = try Lexer.open("../../../assets/scan.itx");
    errdefer lexer.close();
    defer lexer.close();

    var waves: Waves = .{ .page = std.testing.allocator };
    errdefer waves.free();
    defer waves.free();

    var status: Status = Status.init();

    // = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

    var info: InfoWriter = try InfoWriter.open("../../../assets/scan.info");
    errdefer info.close();
    defer info.close();

    var data: DataWriter = try DataWriter.open("../../../assets/scan.data");
    errdefer data.close();
    defer data.close();

    // = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

    var line: []u8 = undefined;

    while (!lexer.halt) : ({
        line = try lexer.next(.Line);
        status.check(line);
    }) {
        switch (status.state) {
            .INIT => {
                line = try lexer.next(.Line);
                status.check(line);
            },
            .IGOR, .MISC => try info.writeAll(line),
            .WAVE => try waves.alloc(line),
            .DATA => {
                for (waves.data) |row| {
                    for (row) |*ptr| {
                        ptr.* = try fmt.parseFloat(f64, try lexer.next(.Data));
                    }
                }
                line = try lexer.next(.Line); // skip the tailed '\n' in the data block
                line = try lexer.next(.Line);
                status.check(line);
            },
        }
    } else try info.writeAll(line);

    // = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

    try data.writeHeader(waves.size);
    for (waves.data) |row| try data.writeRow(row);

    // = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

    var header: [20]u8 = undefined;
    _ = try data.seekTo(0);
    _ = try data.readHeader(&header);

    inline for (header[0..3], .{
        switch (native_endian) {
            .little => 'L',
            .big => 'B',
        },
        'F',
        64,
    }) |byte_get, byte_ans| {
        try testing.expectEqual(byte_get, byte_ans);
        debug.print("{c} ({c}),", .{ byte_get, byte_ans });
    }

    {
        const temp: usize = @bitCast(header[3..11].*);
        try testing.expectEqual(waves.size.nrow, temp);
    }
    {
        const temp: usize = @bitCast(header[11..19].*);
        try testing.expectEqual(waves.size.ncol, temp);
    }

    // = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

    const page = std.testing.allocator;
    const buffer: []f64 = try page.alloc(f64, waves.size.ncol);
    errdefer page.free(buffer);
    defer page.free(buffer);

    for (waves.data) |row| {
        _ = try data.readRow(buffer);
        try testing.expect(std.mem.eql(f64, row, buffer));
    }
}
