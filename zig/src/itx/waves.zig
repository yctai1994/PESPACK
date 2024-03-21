const Allocator = @import("std").mem.Allocator;

// already comptime scope
const slice_al: comptime_int = @alignOf([]f64);
const child_al: comptime_int = @alignOf(f64);
const slice_sz: comptime_int = @sizeOf(usize) * 2;
const child_sz: comptime_int = @sizeOf(f64);

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

pub const WaveSize = struct {
    nrow: usize,
    ncol: usize,
};

pub const Waves = struct {
    page: Allocator,
    buff: []u8 = undefined,
    data: [][]f64 = undefined,
    size: WaveSize = undefined,

    pub fn free(self: *Waves) void {
        self.page.free(self.buff);
    }

    pub fn alloc(self: *Waves, line: []const u8) !void {
        var ix: usize = 5;

        while (line[ix] == '/') {
            ix += 1;
            defer ix += 1;
            switch (line[ix]) {
                'S', 'D' => continue,
                'N' => break,
                else => return error.FlagError,
            }
        }

        if (line[ix] == '=') ix += 1 else return error.FlagError;
        if (line[ix] == '(') ix += 1 else return error.FlagError;

        var nrow: usize = 0;
        while (line[ix] != ',') : (ix += 1) {
            nrow = nrow * 10 + intFromChar(line[ix]);
        } else ix += 1;

        var ncol: usize = 0;
        while (line[ix] != ')') : (ix += 1) {
            ncol = ncol * 10 + intFromChar(line[ix]);
        } else ix += 1;

        self.buff = try self.page.alloc(u8, nrow * ncol * child_sz + nrow * slice_sz);
        self.data = blk: {
            const ptr: [*]align(slice_al) []f64 = @ptrCast(@alignCast(self.buff.ptr));
            break :blk ptr[0..nrow];
        };

        const chunk_sz: usize = ncol * child_sz;
        var padding: usize = nrow * slice_sz;

        for (self.data) |*row| {
            row.* = blk: {
                const ptr: [*]align(child_al) f64 = @ptrCast(@alignCast(self.buff.ptr + padding));
                break :blk ptr[0..ncol];
            };
            padding += chunk_sz;
        }

        self.size = .{ .nrow = nrow, .ncol = ncol };

        return;
    }
};
