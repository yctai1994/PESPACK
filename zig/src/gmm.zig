const std = @import("std");
const math = std.math;

const GMM = @import("./GaussMixture.zig");
const WGMM = @import("./WeightGaussMixture.zig");

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

    var iter: usize = 1;
    while (iter < IMAX) : (iter += 1) {
        gmm.stepE(xvec, mvec, svec, pvec, &this_logL);
        if (this_logL <= prev_logL) {
            std.debug.print("terminate by this_logL <= prev_logL.\n", .{});
            break;
        }
        if ((this_logL - prev_logL) < 0x1p-52) { // EPS(f64)
            std.debug.print("terminate by (this_logL - prev_logL) < 0x1p-52.\n", .{});
            break;
        }
        gmm.stepM(xvec, mvec, svec, pvec);
    }

    if (iter == IMAX) {
        std.debug.print("terminate by max. iteration = {d}.\n", .{IMAX});
    }
    return;
}

export fn cSolveWGMM(
    xptr: [*]f64,
    wptr: [*]f64,
    mptr: [*]f64,
    sptr: [*]f64,
    pptr: [*]f64,
    numN: usize,
    numK: usize,
    IMAX: usize,
) void {
    const wgmm: WGMM = WGMM.init(numN, numK) catch {
        @panic("WGMM.init(...): Allocation fails.");
    };
    defer wgmm.deinit();

    const xvec: []f64 = xptr[0..numN];
    const wvec: []f64 = wptr[0..numN];
    const mvec: []f64 = mptr[0..numK];
    const svec: []f64 = sptr[0..numK];
    const pvec: []f64 = pptr[0..numK];

    var prev_logL: f64 = undefined;
    var this_logL: f64 = undefined;

    wgmm.stepE(xvec, wvec, mvec, svec, pvec, &prev_logL);
    wgmm.stepM(xvec, wvec, mvec, svec, pvec);

    var iter: usize = 1;
    while (iter < IMAX) : (iter += 1) {
        wgmm.stepE(xvec, wvec, mvec, svec, pvec, &this_logL);
        if (this_logL <= prev_logL) {
            std.debug.print("terminate by this_logL <= prev_logL.\n", .{});
            break;
        }
        if ((this_logL - prev_logL) < 0x1p-52) { // EPS(f64)
            std.debug.print("terminate by (this_logL - prev_logL) < 0x1p-52.\n", .{});
            break;
        }
        wgmm.stepM(xvec, wvec, mvec, svec, pvec);
    }

    if (iter == IMAX) {
        std.debug.print("terminate by max. iteration = {d}.\n", .{IMAX});
    }
    return;
}
