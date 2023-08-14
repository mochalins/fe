const std = @import("std");
const os = std.os;

pub const posix = @import("term/posix.zig");

const builtin = @import("builtin");
pub const impl = switch (builtin.os.tag) {
    .macos, .linux => posix,
    else => @compileError("OS not supported"),
};

const root = @import("root");
const core = root.core;
const Color = core.Color;

pub const Size = packed struct {
    rows: u16,
    cols: u16,
};

const MAX_BUFFER = 8192; // Enough for most reasonable terminal sizes
var buffer: [MAX_BUFFER]u8 = undefined;
var buffer_len: usize = 0;

pub var initialized: bool = false;
pub var size: Size = undefined;

pub fn init() !void {
    if (initialized) return;
    buffer_len = 0;
    try impl.init();
    errdefer impl.deinit();

    // TODO: Eventually replace all instances of `STDOUT_FILENO` with a `File`
    // and accompanying `isTty`, `supportsAnsiEscapeCodes` checks.

    // Enter alternate screen
    _ = try os.write(os.STDOUT_FILENO, "\x1b[?1049h");
    // Save cursor and attributes
    _ = try os.write(os.STDOUT_FILENO, "\x1b7");
    try pollSize();
    initialized = true;
}

pub fn deinit() void {
    if (!initialized) return;
    // Restore cursor and attributes
    _ = os.write(os.STDOUT_FILENO, "\x1b8") catch {};
    // Exit alternate screen
    _ = os.write(os.STDOUT_FILENO, "\x1b[?1049l") catch {};
    impl.deinit();
    initialized = false;
}

pub fn pollSize() !void {
    try impl.pollSize();
}

pub fn writeRaw(content: []const u8) !void {
    if (buffer_len > 0) {
        _ = try os.write(os.STDOUT_FILENO, buffer[0..buffer_len]);
        buffer_len = 0;
    }
    _ = try os.write(os.STDOUT_FILENO, content);
}

pub fn hideCursor() !void {
    try writeRaw("\x1b[?25l");
}

pub fn showCursor() !void {
    try writeRaw("\x1b[?25h");
}

pub fn homeCursor() !void {
    try writeRaw("\x1b[H");
}

pub fn moveCursorUp(rows: u16) !void {
    if (rows == 0) return;
    var buf: [8]u8 = undefined;
    try writeRaw(try std.fmt.bufPrint(&buf, "\x1b[{d}A", .{rows}));
}

pub fn moveCursorDown(rows: u16) !void {
    if (rows == 0) return;
    var buf: [8]u8 = undefined;
    try writeRaw(try std.fmt.bufPrint(&buf, "\x1b[{d}B", .{rows}));
}

pub fn moveCursorRight(cols: u16) !void {
    if (cols == 0) return;
    var buf: [8]u8 = undefined;
    try writeRaw(try std.fmt.bufPrint(&buf, "\x1b[{d}C", .{cols}));
}

pub fn moveCursorLeft(cols: u16) !void {
    if (cols == 0) return;
    var buf: [8]u8 = undefined;
    try writeRaw(try std.fmt.bufPrint(&buf, "\x1b[{d}D", .{cols}));
}

pub fn moveCursor(row: u16, col: u16) !void {
    // TODO
    _ = col;
    _ = row;
}

/// Write buffered output to terminal. Will flush buffer on call if buffer
/// is full.
pub fn writeBuffered(content: []const u8) !void {
    var cstart: usize = 0;
    while (cstart < content.len) {
        std.debug.assert(buffer_len <= MAX_BUFFER);
        if (buffer_len == MAX_BUFFER) {
            try flush();
            continue;
        }
        const buf_start: [*]u8 = &buffer;
        const clen: usize = @min(
            MAX_BUFFER - buffer_len,
            content.len - cstart,
        );
        @memcpy(buf_start + buffer_len, content[cstart .. cstart + clen]);
        buffer_len += clen;
        cstart += clen;
    }
}

pub fn writeNewlineBuffered() !void {
    try writeBuffered("\r\n");
}

/// Erase cursor's line, buffered. Cursor position unchanged.
pub fn eraseLineBuffered() !void {
    try writeBuffered("\x1b[2K");
}

/// Erase cursor's line from start to cursor's column, buffered. Cursor
/// position unchanged.
pub fn eraseLineStartBuffered() !void {
    try writeBuffered("\x1b[1K");
}

/// Erase cursor's line from cursor's column to end of line, buffered. Cursor
/// position unchanged.
pub fn eraseLineEndBuffered() !void {
    try writeBuffered("\x1b[0K");
}

pub fn setFgColorBuffered(color: Color) !void {
    var buf: [19]u8 = undefined;
    switch (color.kind) {
        .default => try writeBuffered("\x1b[39;m"),
        .extended => |val| switch (val) {
            0...7 => try writeBuffered(
                try std.fmt.bufPrint(&buf, "\x1b[{d}m", .{30 + val}),
            ),
            8...15 => try writeBuffered(
                try std.fmt.bufPrint(&buf, "\x1b[{d}m", .{90 + val - 8}),
            ),
            else => try writeBuffered(
                try std.fmt.bufPrint(&buf, "\x1b[38;5;{d}m", .{val}),
            ),
        },
        .rgb => |rgb| try writeBuffered(try std.fmt.bufPrint(
            &buf,
            "\x1b[38;2;{d};{d};{d};m",
            .{ rgb.red, rgb.green, rgb.blue },
        )),
        .none => return,
    }
}

pub fn setBgColorBuffered(color: Color) !void {
    var buf: [19]u8 = undefined;
    switch (color.kind) {
        .default => try writeBuffered("\x1b[49;m"),
        .extended => |val| switch (val) {
            0...7 => try writeBuffered(
                try std.fmt.bufPrint(&buf, "\x1b[{d}m", .{40 + val}),
            ),
            8...15 => try writeBuffered(
                try std.fmt.bufPrint(&buf, "\x1b[{d}m", .{100 + val - 8}),
            ),
            else => try writeBuffered(
                try std.fmt.bufPrint(&buf, "\x1b[48;5;{d}m", .{val}),
            ),
        },
        .rgb => |rgb| try writeBuffered(try std.fmt.bufPrint(
            &buf,
            "\x1b[48;2;{d};{d};{d};m",
            .{ rgb.red, rgb.green, rgb.blue },
        )),
        .none => return,
    }
}

pub fn resetStyleBuffered() !void {
    try writeBuffered("\x1b[0m");
}

pub fn flush() !void {
    if (buffer_len == 0) return;
    std.debug.assert(buffer_len <= MAX_BUFFER);
    _ = try os.write(os.STDOUT_FILENO, buffer[0..buffer_len]);
    buffer_len = 0;
}
