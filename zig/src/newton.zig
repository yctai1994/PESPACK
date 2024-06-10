//! Reference
//! William H. Press, Saul A. Teukolsky, William T. Vetterling, Brian P. Flannery 2007
//! Numerical Recipes 3rd Edition: The Art of Scientific Computing, Sec. 9.4
const std = @import("std");

const NewtonError = error{
    OutOfBounds,
    TimeOutError,
};

/// Using a combination of Newton-Raphson and bisection, return the root of a function bracketed
/// between x1 and x2. The root will be refined until its accuracy is known within ±xacc.
fn zFindRoot(
    func: *const fn (x: f64) f64,
    dfdx: *const fn (x: f64) f64,
    goal: f64,
    x1: f64,
    x2: f64,
) NewtonError!f64 {
    const MAXIT: usize = 20; // Maximum allowed number of iterations.
    const XACC: f64 = std.math.floatEps(f64);

    const fl: f64 = func(x1) - goal;
    const fh: f64 = func(x2) - goal;

    if ((fl > 0.0 and fh > 0.0) or (fl < 0.0 and fh < 0.0)) return error.OutOfBounds;
    if (fl == 0.0) return x1;
    if (fh == 0.0) return x2;

    var xl: f64 = undefined;
    var xh: f64 = undefined;

    if (fl < 0.0) {
        xl = x1;
        xh = x2;
    } else {
        xl = x2;
        xh = x1;
    }

    var rt: f64 = 0.5 * (x1 + x2); // init. the guess for root
    var dd: f64 = @abs(x2 - x1); // the stepsize before last
    var dx: f64 = dd; // the last step.

    var fv: f64 = func(rt) - goal;
    var df: f64 = dfdx(rt);

    for (0..MAXIT) |_| { // Loop over allowed iterations.
        // Use bisection if Newton is out of range, or not decreasing fast enough.
        if ((((rt - xh) * df - fv) * ((rt - xl) * df - fv) > 0.0) or (@abs(2.0 * fv) > @abs(dd * df))) {
            dd = dx;
            dx = 0.5 * (xh - xl);
            rt = xl + dx;
            if (xl == rt) return rt;
        } else {
            dd = dx;
            dx = fv / df;
            if (dx == 0.0) return rt else rt -= dx;
        }

        if (@abs(dx) < XACC) return rt;

        fv = func(rt) - goal;
        df = dfdx(rt);

        if (fv < 0.0) xl = rt else xh = rt;
    }

    return error.TimeOutError;
}

fn test_func(x: f64) f64 {
    return (@exp(-x) - 1.0) / x;
}

fn test_dfdx(x: f64) f64 {
    return -(@exp(-x) + test_func(x)) / x;
}

test "test" {
    var root: f64 = undefined;

    root = try zFindRoot(test_func, test_dfdx, -0.8, 0.01, 20.0);
    try std.testing.expectApproxEqAbs(0.4642127543788163, root, 1e-15);

    root = try zFindRoot(test_func, test_dfdx, -0.4, 0.01, 20.0);
    try std.testing.expectApproxEqAbs(2.231611884023023, root, 1e-15);

    root = try zFindRoot(test_func, test_dfdx, -0.2, 0.01, 20.0);
    try std.testing.expectApproxEqAbs(4.965114231744276, root, 1e-15);

    root = try zFindRoot(test_func, test_dfdx, -0.1, 0.01, 20.0);
    try std.testing.expectApproxEqAbs(9.999545794446535, root, 1e-15);
}
