const std = @import("std");
const math = std.math;

pub fn weightedMeanVar(
    xdat: []f64,
    wdat: []f64,
) [2]f64 {
    var tmp: f64 = undefined;
    var wsum: f64 = 0.0;
    var wxsum: f64 = 0.0;
    var wxxsum: f64 = 0.0;

    for (xdat, wdat) |xval, wval| {
        tmp = xval * wval;
        wsum += wval;
        wxsum += tmp;
        wxxsum += tmp * xval;
    }

    if (wsum == 0.0) {
        return .{ math.nan(f64), math.nan(f64) };
    } else {
        const wmean: f64 = wxsum / wsum;
        return .{ wmean, wxxsum / wsum - wmean * wmean };
    }
}
