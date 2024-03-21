fd: posix.fd_t,

pub fn open(pth: []const u8) !@This() {
    const file: std.fs.File = try std.fs.cwd().createFile(pth, .{ .read = true });
    return .{ .fd = file.handle };
}

pub fn close(self: *@This()) void {
    posix.close(self.fd);
}

pub fn seekTo(self: *@This(), offset: u64) !void {
    return posix.lseek_SET(self.fd, offset);
}

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

fn readAll(fd: posix.fd_t, des: []u8) !usize {
    var index: usize = 0;
    while (index != des.len) {
        const count = try posix.read(fd, des[index..]);
        if (count == 0) break;
        index += count;
    }
    return index;
}

pub fn readRow(self: *@This(), des: []f64) !usize {
    const ptr: [*]align(align_of_u8) u8 = @ptrCast(@alignCast(des.ptr));
    const len: usize = size_of_f64 * des.len;
    return readAll(self.fd, ptr[0..len]);
}

pub fn readHeader(self: *@This(), des: []u8) !usize {
    if (des.len != 20) unreachable;
    return try readAll(self.fd, des);
}

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

fn writeAll(fd: posix.fd_t, line: []const u8) !void {
    var index: usize = 0;
    while (index < line.len) index += try posix.write(fd, line[index..]);
    return;
}

pub fn writeRow(self: *@This(), src: []f64) !void {
    const ptr: [*]align(align_of_u8) u8 = @ptrCast(@alignCast(src.ptr));
    const len: usize = size_of_f64 * src.len;
    return try writeAll(self.fd, ptr[0..len]);
}

pub fn writeHeader(self: *@This(), size: WaveSize) !void {
    var header: [20]u8 = undefined;

    header[0] = switch (native_endian) {
        .little => 'L',
        .big => 'B',
    };

    header[1] = 'F';
    header[2] = 64;

    for (
        @as([8]u8, @bitCast(size.nrow)),
        header[3..11],
    ) |val, *ptr| ptr.* = val;

    for (
        @as([8]u8, @bitCast(size.ncol)),
        header[11..19],
    ) |val, *ptr| ptr.* = val;

    header[19] = '\n';

    return try writeAll(self.fd, &header);
}

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

const std = @import("std");
const posix = std.posix;

const builtin = @import("builtin");
const native_endian = builtin.cpu.arch.endian();

const WaveSize = @import("./waves.zig").WaveSize;

const align_of_u8: comptime_int = @alignOf(u8);
const size_of_f64: comptime_int = @sizeOf(f64);
