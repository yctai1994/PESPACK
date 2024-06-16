//! 64D Gaussian Mixture Model

resp: [][]f64,
host: Array,

pub fn init(nrow: usize, kcol: usize) !@This() {
    const ArrF64: Array = .{};
    const resp: [][]f64 = try ArrF64.matrix(nrow, kcol);
    return .{ .resp = resp, .host = ArrF64 };
}

pub fn deinit(self: *const @This()) void {
    self.host.free(self.resp);
    return;
}

// xvec: []f64, xvec.len == N <- data points
// mvec: []f64, mvec.len == K <- K-means
// svec: []f64, svec.len == K <- K-std. deviations
// pvec: []f64, pvec.len == K <- K-priors
// resp: [][]f64, resp.len == N, resp[n].len == K <- responsibility matrix

pub fn stepE(
    self: *const @This(),
    xvec: []f64,
    mvec: []f64,
    svec: []f64,
    pvec: []f64,
    logL: *f64,
) void {
    for (self.resp, xvec) |resp_n, x_n| {
        for (resp_n, mvec, svec, pvec) |*resp_nk, m_k, s_k, p_k| {
            resp_nk.* = @log(p_k) - @log(s_k) - 0.5 * abs2((x_n - m_k) / s_k) - LOG_SQRT_TWOPI;
        }
    }

    var znmax: f64 = undefined;
    var temp: f64 = undefined;

    logL.* = 0.0;

    for (self.resp) |resp_n| {
        znmax = -INF;
        for (resp_n) |resp_nk| {
            if (resp_nk > znmax) znmax = resp_nk;
        }

        temp = 0.0;
        for (resp_n) |resp_nk| temp += @exp(resp_nk - znmax);

        temp = znmax + @log(temp);
        for (resp_n) |*resp_nk| resp_nk.* = @exp(resp_nk.* - temp);

        logL.* += temp;
    }

    return;
}

pub fn stepM(
    self: *const @This(),
    xvec: []f64,
    mvec: []f64,
    svec: []f64,
    pvec: []f64,
) void {
    const N: f64 = @floatFromInt(xvec.len);
    var N_k: f64 = undefined;
    var tmp: f64 = undefined;

    for (mvec, svec, pvec, 0..) |*m_k, *s_k, *p_k, k| {
        N_k = 0.0;
        for (self.resp) |resp_n| N_k += resp_n[k];

        p_k.* = N_k / N;

        tmp = 0.0;
        for (self.resp, xvec) |resp_n, x_n| tmp += resp_n[k] * x_n;

        m_k.* = tmp / N_k;

        tmp = 0.0;
        for (self.resp, xvec) |resp_n, x_n| tmp += resp_n[k] * abs2(x_n - m_k.*);

        s_k.* = @sqrt(tmp / N_k);
    }

    return;
}

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

inline fn abs2(x: f64) f64 {
    return x * x;
}

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

const std = @import("std");
const math = std.math;

const INF: comptime_float = math.inf(f64);
const LOG_SQRT_TWOPI: comptime_float = @log(@sqrt(2.0 * math.pi));

const Array = @import("./array.zig").Array;
