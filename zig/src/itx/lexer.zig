const std = @import("std");

const fs = std.fs;
const mem = std.mem;
const posix = std.posix;

const buffer_size: comptime_int = 128;

fn openFile(pth: []const u8) !posix.fd_t {
    const file: fs.File = try fs.cwd().openFile(pth, .{ .mode = .read_only });
    return file.handle;
}

fn readByte(fd: posix.fd_t) !?u8 {
    var result: [1]u8 = undefined;
    const amt_read = try posix.read(fd, result[0..]);
    if (amt_read < 1) return null;
    return result[0];
}

const Mode = enum { Line, Data };

pub const Lexer = struct {
    file: posix.fd_t,
    buff: [buffer_size]u8 = undefined,
    halt: bool = false,

    pub fn open(pth: []const u8) !Lexer {
        return .{ .file = try openFile(pth) };
    }

    pub fn close(self: *Lexer) void {
        posix.close(self.file);
    }

    pub fn next(self: *Lexer, comptime mode: Mode) ![]u8 {
        var end: usize = 0;

        switch (mode) {
            .Line => {
                while (end < buffer_size) {
                    if (try readByte(self.file)) |byte| {
                        if (byte == '\r') continue else {
                            self.buff[end] = byte;
                            end += 1;
                        }
                        if (byte == '\n') break;
                    } else { // end of file
                        self.halt = true;
                        break;
                    }
                }
            },

            .Data => {
                // Skip leading spaces
                while (true) {
                    if (try readByte(self.file)) |byte| {
                        switch (byte) {
                            '+', '-', '.', '0'...'9' => {
                                self.buff[end] = byte;
                                end += 1;
                                break;
                            },
                            else => continue,
                        }
                    } else unreachable;
                }

                while (end < buffer_size) {
                    if (try readByte(self.file)) |byte| {
                        switch (byte) {
                            '+', '-', '.', '0'...'9' => {
                                self.buff[end] = byte;
                                end += 1;
                            },
                            else => break,
                        }
                    } else unreachable;
                }
            },
        }

        return self.buff[0..end];
    }
};
