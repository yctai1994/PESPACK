state: State,

pub fn init() @This() {
    return .{ .state = .INIT };
}

pub fn reset(self: *@This()) void {
    self.state = .INIT;
    return;
}

pub fn check(self: *@This(), line: []const u8) void {
    if (peek(self.state)) |head| {
        var matched: bool = true;
        for (head, 0..) |char, ix| {
            if (char != line[ix]) {
                matched = false;
                break;
            }
        }
        if (matched) self.state = next(self.state);
    }
    return;
}

// For Igor Text File:
//
//  ------------------------- (INIT)
//  IGOR
//  ------------------------- (IGOR)
//  WAVES/D/N=(3,2) wave0 --- (WAVE)
//  BEGIN
//  ------------------------- (DATA)
//  .
//  .
//  .
//  ------------------------- (DATA)
//  END
//  ------------------------- (MISC)
const State = enum {
    INIT,
    IGOR,
    WAVE,
    DATA,
    MISC,
};

fn peek(s: State) ?[]const u8 {
    return switch (s) {
        .INIT => "IGOR",
        .IGOR => "WAVES",
        .WAVE => "BEGIN",
        .DATA => "END",
        .MISC => null,
    };
}

fn next(s: State) State {
    return switch (s) {
        .INIT => .IGOR,
        .IGOR => .WAVE,
        .WAVE => .DATA,
        .DATA => .MISC,
        .MISC => unreachable,
    };
}
