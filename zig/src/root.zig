const std = @import("std");
const debug = std.debug;
const testing = std.testing;

export fn sum(arr: [*]f64, num: usize) f64 {
    var tot: f64 = 0.0;
    for (arr[0..num]) |val| tot += val;
    return tot;
}

export fn showAll(arr: [*]f64, num: usize) void {
    for (arr[0..num]) |val| {
        debug.print("{d}, ", .{val});
    }
    return;
}

pub usingnamespace @import("./newton.zig");
pub usingnamespace @import("./statistics.zig");
