file: posix.fd_t,

pub fn open(pth: []const u8) !@This() {
    const file: std.fs.File = try std.fs.cwd().createFile(pth, .{ .read = false });
    return .{ .file = file.handle };
}

pub fn close(self: *@This()) void {
    posix.close(self.file);
}

pub fn writeAll(self: *@This(), line: []const u8) !void {
    var index: usize = 0;
    while (index < line.len) index += try posix.write(self.file, line[index..]);
    return;
}

const std = @import("std");
const posix = std.posix;
