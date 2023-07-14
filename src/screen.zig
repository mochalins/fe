const std = @import("std");

const Key = @import("key.zig").Key;

pub const Screen = struct {
    const Self = @This();

    rows: u16 = 0,
    cols: u16 = 0,

    raw_mode: bool = false,
    orig_termios: std.os.termios = undefined,

    pub fn enableRawMode(self: *Self) !void {
        if (self.raw_mode) return;

        self.orig_termios = try std.os.tcgetattr(std.os.STDIN_FILENO); // So we can restore later
        var termios = self.orig_termios;

        const linux = std.os.linux;
        const VMIN = 5;
        const VTIME = 6;

        // input modes: no break, no CR to NL, no parity check, no strip char, no start/stop output ctrl.
        termios.iflag &= ~(linux.BRKINT | linux.ICRNL | linux.INPCK | linux.ISTRIP | linux.IXON);
        // output modes: disable post processing
        termios.oflag &= ~(linux.OPOST);
        // control modes: set 8 bit chars
        termios.cflag |= linux.CS8;
        // local modes: choign off, canonical off, no extended functions, no signal chars (^Z, ^C)
        termios.lflag &= ~(linux.ECHO | linux.ICANON | linux.IEXTEN | linux.ISIG);
        termios.cc[VMIN] = 0;
        termios.cc[VTIME] = 1;

        _ = linux.tcsetattr(linux.STDIN_FILENO, .FLUSH, &termios);
        self.raw_mode = true;
    }

    pub fn disableRawMode(self: *Self) !void {
        if (self.raw_mode) {
            _ = std.os.linux.tcsetattr(std.os.linux.STDIN_FILENO, .FLUSH, &self.orig_termios);
            self.raw_mode = false;
        }
    }

    fn getRawSize(self: *Self) !void {
        const linux = std.os.linux;
        var raw_size: linux.winsize = undefined;
        const fd = @as(usize, @bitCast(@as(isize, linux.STDOUT_FILENO)));
        if (linux.syscall3(.ioctl, fd, linux.T.IOCGWINSZ, @intFromPtr(&raw_size)) == -1 or raw_size.ws_col == 0) {
            _ = try std.os.write(linux.STDOUT_FILENO, "\x1b[999C\x1b[999B");
            return self.getCursorPosition();
        } else {
            self.rows = raw_size.ws_row;
            self.cols = raw_size.ws_col;
        }
    }

    pub fn updateSize(self: *Self) !void {
        try self.getRawSize();
        self.rows -= 2;
    }

    pub fn getCursorPosition(_: *Self) !void {
        var buf: [32]u8 = undefined;

        _ = try std.os.write(std.os.linux.STDOUT_FILENO, "\x1b[6n");

        for (0..buf.len - 1) |i| {
            _ = std.os.read(std.os.linux.STDIN_FILENO, &buf) catch break;
            if (buf[i] == 'R') break;
        }

        if (buf[0] != '\x1b' or buf[1] != '[') return error.CursorError;
        _ = try Key.readKey();
    }
};
