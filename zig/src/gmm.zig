const std = @import("std");
const math = std.math;

const GMM = @import("./GaussMix.zig");

export fn cSolveGMM(
    xptr: [*]f64,
    mptr: [*]f64,
    sptr: [*]f64,
    pptr: [*]f64,
    numN: usize,
    numK: usize,
    IMAX: usize,
) void {
    const gmm: GMM = GMM.init(numN, numK) catch {
        @panic("GMM.init(...): Allocation fails.");
    };
    defer gmm.deinit();

    const xvec: []f64 = xptr[0..numN];
    const mvec: []f64 = mptr[0..numK];
    const svec: []f64 = sptr[0..numK];
    const pvec: []f64 = pptr[0..numK];

    var prev_logL: f64 = undefined;
    var this_logL: f64 = undefined;

    gmm.stepE(xvec, mvec, svec, pvec, &prev_logL);
    gmm.stepM(xvec, mvec, svec, pvec);

    for (1..IMAX) |_| {
        gmm.stepE(xvec, mvec, svec, pvec, &this_logL);
        if (this_logL <= prev_logL) {
            std.debug.print("terminate by this_logL <= prev_logL.\n", .{});
            break;
        }
        if ((this_logL - prev_logL) < 0x1p-52) {
            std.debug.print("terminate by (this_logL - prev_logL) < 0x1p-52.\n", .{});
            break;
        }
        gmm.stepM(xvec, mvec, svec, pvec);
    }

    std.debug.print("terminate by max. iteration = {d}.\n", .{IMAX});
    return;
}
