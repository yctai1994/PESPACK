const weight = @import("./weight.zig");

export fn cWeightedMeanVar(
    dest: [*]f64,
    xvec: [*]f64,
    wvec: [*]f64,
    dims: usize,
) void {
    const temp: [2]f64 = weight.weightedMeanVar(xvec[0..dims], wvec[0..dims]);
    dest[0] = temp[0];
    dest[1] = temp[1];
    return;
}
