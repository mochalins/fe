//! POSIX specific implementations of virtual terminal abstractions.
const Term = @This();
const Self = @This();

const term = @import("../term.zig");

const std = @import("std");

const os = std.os;
const system = os.system;

const Key = @import("../key.zig").Key;

var orig_termios: os.termios = undefined;

pub fn init() !void {
    orig_termios = try os.tcgetattr(os.STDIN_FILENO);
    errdefer deinit();
    var termios = orig_termios;

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
}

pub fn deinit() void {
    os.tcsetattr(os.STDIN_FILENO, .FLUSH, orig_termios) catch {};
}

pub fn pollSize() !void {
    var size: system.winsize = undefined;
    const err = system.ioctl(os.STDOUT_FILENO, system.T.IOCGWINSZ, @intFromPtr(&size));
    if (os.errno(err) == .SUCCESS) {
        term.size.rows = size.ws_row;
        term.size.cols = size.ws_col;
    } else {
        // _ = try os.write(os.STDOUT_FILENO, "\x1b[999C\x1b[999B");
        // return getCursorPosition();
        return error.pollSizeFailed;
    }
}

pub fn getCursorPosition() !void {
    var buf: [32]u8 = undefined;

    _ = try os.write(os.STDOUT_FILENO, "\x1b[6n");

    for (0..buf.len - 1) |i| {
        _ = os.read(os.STDIN_FILENO, &buf) catch break;
        if (buf[i] == 'R') break;
    }

    if (buf[0] != '\x1b' or buf[1] != '[') return error.CursorError;
    _ = try Key.readKey();
}
