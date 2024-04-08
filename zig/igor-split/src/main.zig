const std = @import("std");

const ProcArgs = @import("./ProcArgs.zig");

pub fn main() !void {
    const proc_args = ProcArgs.init() catch |err| {
        switch (err) {
            error.InvalidParamFlag, error.InvalidParamNumber => return,
            else => return err,
        }
    };

    proc_args.check() catch |err| {
        switch (err) {
            error.InvalidParamNumber => return,
            else => return err,
        }
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.print("Memory Leaks: {any}\n", .{gpa.detectLeaks()});
    const page: std.mem.Allocator = gpa.allocator();

    const info_path: []u8 = try proc_args.getPath(page, .info);
    defer { // including errdefer
        std.debug.print("defer page.free(info_path)\n", .{});
        page.free(info_path);
    }

    const data_path: []u8 = try proc_args.getPath(page, .dat2);
    defer { // including errdefer
        std.debug.print("defer page.free(data_path)\n", .{});
        page.free(data_path);
    }

    std.debug.print("info_path: {s}\n", .{info_path});
    std.debug.print("data_path: {s}\n", .{data_path});
}
