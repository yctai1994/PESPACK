mode: ?Mode,
input: ?[]const u8,
output: ?[]const u8,

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

const ProcArgsError = error{
    InvalidParamNumber,
    InvalidParamValue,
    InvalidParamFlag,
};

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

const Mode = enum {
    dynamic,
    static,
};

const FileExtension = enum {
    info,
    dat2,
    dat3,
};

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

pub fn init() !@This() {
    const osargv: [][*:0]u8 = std.os.argv;
    const argnum: usize = if (osargv.len & 1 == 1) osargv.len >> 1 else {
        try writeAll(STDERR, "\x1b[31mINFO: Invalid Param Number.\x1b[0m\n");
        return ProcArgsError.InvalidParamNumber;
    };

    var self: @This() = .{ .mode = null, .input = null, .output = null };

    for (0..argnum) |ind| {
        const param_flag: []const u8 = std.mem.sliceTo(osargv[2 * ind + 1], 0);
        const param_value: []const u8 = std.mem.sliceTo(osargv[2 * ind + 2], 0);

        self.parse(param_flag, param_value) catch |err| {
            try writeAll(STDERR, "\x1b[31mINFO: Invalid Param Flag: ");
            try writeAll(STDERR, param_flag);
            try writeAll(STDERR, "\x1b[0m\n");
            return err;
        };
    }

    return self;
}

fn parse(self: *@This(), param_flag: []const u8, param_value: []const u8) !void {
    if (param_flag.len != 2) return ProcArgsError.InvalidParamFlag;
    if (param_flag[0] != '-') return ProcArgsError.InvalidParamFlag;
    switch (param_flag[1]) {
        'm', 'M' => {
            if (std.mem.eql(u8, param_value, "static")) self.mode = .static;
            if (std.mem.eql(u8, param_value, "dynamic")) self.mode = .dynamic;
        },
        'i', 'I' => self.input = param_value,
        'o', 'O' => self.output = param_value,
        else => return ProcArgsError.InvalidParamFlag,
    }

    return;
}

pub fn getPath(
    self: *const @This(),
    allocator: std.mem.Allocator,
    comptime extension: FileExtension,
) ![]u8 {
    const input: []const u8 = self.input.?;
    const output: []const u8 = self.output.?;

    const basename: []const u8 = std.fs.path.basename(input);
    const new_path: []u8 = try allocator.alloc(u8, output.len + basename.len + 1);
    const split: usize = output.len + basename.len - 4;

    @memcpy(new_path[0..output.len], output);
    @memcpy(new_path[output.len..split], basename[0 .. basename.len - 4]);
    @memcpy(
        new_path[split..],
        comptime switch (extension) {
            .info => ".info",
            .dat2 => ".dat2",
            .dat3 => ".dat3",
        },
    );

    return new_path;
}

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

pub fn check(self: *const @This()) !void {
    // Print `header`
    try writeAll(STDOUT, "\x1b[33m[[ Igor Text File Splitter ]]\x1b[0m\n");

    const cwd: std.fs.Dir = std.fs.cwd();
    var success: bool = true;

    try writeAll(STDOUT, "   mode  : ");

    if (self.mode) |mode| {
        // Check `mode`
        try writeAll(
            STDOUT,
            switch (mode) {
                .static => "static\n",
                .dynamic => "dynamic\n",
            },
        );

        // Check `input`
        try writeAll(STDOUT, "   input : ");
        if (self.input) |input_pth| {
            try writeAll(STDOUT, input_pth);
            switch (mode) {
                .static => {
                    const len: usize = input_pth.len;
                    inline for (
                        .{ 4, 3, 2, 1 },
                        .{ '.', 'i', 't', 'x' },
                    ) |shift, char| {
                        if (input_pth[len - shift] != char) success = false;
                    }

                    if (success) {
                        if (cwd.openFile(input_pth, .{})) |input_file| {
                            try writeAll(STDOUT, " (\x1b[32mvalid file\x1b[0m)\n");
                            posix.close(input_file.handle);
                        } else |_| success = false;
                    }

                    if (!success) try writeAll(STDOUT, " (\x1b[31minvalid file\x1b[0m)\n");
                },
                .dynamic => {
                    if (cwd.openDir(input_pth, .{})) |input_dir| {
                        try writeAll(STDOUT, " (\x1b[32mvalid directory\x1b[0m)\n");
                        posix.close(input_dir.fd);
                    } else |_| {
                        try writeAll(STDOUT, " (\x1b[31minvalid directory\x1b[0m)\n");
                        success = false;
                    }
                },
            }
        } else {
            try writeAll(STDOUT, "\x1b[31mnull\x1b[0m\n");
            success = false;
        }

        // Check `output`
        try writeAll(STDOUT, "   output: ");
        if (self.output) |output_pth| {
            try writeAll(STDOUT, output_pth);

            if (cwd.openDir(output_pth, .{})) |output_dir| {
                try writeAll(STDOUT, " (\x1b[32mvalid directory\x1b[0m)\n");
                posix.close(output_dir.fd);
            } else |_| {
                try writeAll(STDOUT, " (\x1b[31minvalid directory\x1b[0m)\n");
                success = false;
            }
        } else {
            try writeAll(STDOUT, "\x1b[31mnull\x1b[0m\n");
            success = false;
        }
    } else {
        try writeAll(STDOUT, "\x1b[31mnull\x1b[0m\n");
        success = false;
    }

    // Print `Result`
    try writeAll(STDOUT, "   check : ");
    if (success) {
        try writeAll(STDOUT, "\x1b[32mpass (continue)\x1b[0m\n");
        return;
    } else {
        try writeAll(STDOUT, "\x1b[31mfail (exit)\x1b[0m\n");
        return ProcArgsError.InvalidParamNumber;
    }
}

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

fn writeAll(fd: posix.fd_t, str: []const u8) !void {
    var index: usize = 0;
    while (index < str.len) index += try posix.write(fd, str[index..]);
    return;
}

const std = @import("std");
const posix = std.posix;
const STDOUT: posix.fd_t = posix.STDOUT_FILENO;
const STDERR: posix.fd_t = posix.STDERR_FILENO;
