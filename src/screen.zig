const std = @import("std");

const os = std.os;
const system = os.system;

const Key = @import("key.zig").Key;

pub const Screen = struct {
    const Self = @This();

    rows: u16 = 0,
    cols: u16 = 0,

    raw_mode: bool = false,
    orig_termios: os.termios = undefined,

    pub fn enableRawMode(self: *Self) !void {
        if (self.raw_mode) return;

        self.orig_termios = try os.tcgetattr(os.STDIN_FILENO); // So we can restore later
        var termios = self.orig_termios;

        // input modes: no break, no CR to NL, no parity check, no strip char, no start/stop output ctrl.
        termios.iflag &= ~(system.BRKINT | system.ICRNL | system.INPCK | system.ISTRIP | system.IXON);
        // output modes: disable post processing
        termios.oflag &= ~(system.OPOST);
        // control modes: set 8 bit chars
        termios.cflag |= system.CS8;
        // local modes: choign off, canonical off, no extended functions, no signal chars (^Z, ^C)
        termios.lflag &= ~(system.ECHO | system.ICANON | system.IEXTEN | system.ISIG);
        termios.cc[system.V.MIN] = 1;
        termios.cc[system.V.TIME] = 0;

        try os.tcsetattr(os.STDIN_FILENO, .FLUSH, termios);
        self.raw_mode = true;
    }

    pub fn disableRawMode(self: *Self) !void {
        if (self.raw_mode) {
            try os.tcsetattr(os.STDIN_FILENO, .FLUSH, self.orig_termios);
            self.raw_mode = false;
        }
    }

    fn getRawSize(self: *Self) !void {
        var raw_size: system.winsize = undefined;
        const err = system.ioctl(os.STDOUT_FILENO, system.T.IOCGWINSZ, @intFromPtr(&raw_size));
        if (os.errno(err) != .SUCCESS) {
            _ = try os.write(os.STDOUT_FILENO, "\x1b[999C\x1b[999B");
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

        _ = try os.write(os.STDOUT_FILENO, "\x1b[6n");

        for (0..buf.len - 1) |i| {
            _ = os.read(os.STDIN_FILENO, &buf) catch break;
            if (buf[i] == 'R') break;
        }

        if (buf[0] != '\x1b' or buf[1] != '[') return error.CursorError;
        _ = try Key.readKey();
    }
};
