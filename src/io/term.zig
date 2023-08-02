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
const Color = core.color.Color;
const ColorType = core.color.ColorType;

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
    var buf: [8]u8 = undefined;
    try writeRaw(try std.fmt.bufPrint(&buf, "\x1b[{d}A", .{rows}));
}

pub fn moveCursorDown(rows: u16) !void {
    var buf: [8]u8 = undefined;
    try writeRaw(try std.fmt.bufPrint(&buf, "\x1b[{d}B", .{rows}));
}

pub fn moveCursorRight(cols: u16) !void {
    var buf: [8]u8 = undefined;
    try writeRaw(try std.fmt.bufPrint(&buf, "\x1b[{d}C", .{cols}));
}

pub fn moveCursorLeft(cols: u16) !void {
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

pub fn setFgColorBuffered(color: Color) !void {
    var buf: [19]u8 = undefined;
    switch (color) {
        ColorType.color_default => try writeBuffered("\x1b[39;m"),
        ColorType.color_8 => |val| try writeBuffered(try std.fmt.bufPrint(
            &buf,
            "\x1b[{d}m",
            .{30 + val.ordinal()},
        )),
        ColorType.color_16 => |val| switch (val.ordinal()) {
            0...7 => |i| try writeBuffered(
                try std.fmt.bufPrint(&buf, "\x1b[{d}m", .{30 + i}),
            ),
            8...15 => |i| {
                // Try both methods of "bright" colors for compatibility
                try writeBuffered(
                    try std.fmt.bufPrint(&buf, "\x1b[1;{d}m", .{30 + i}),
                );
                try writeBuffered(
                    try std.fmt.bufPrint(&buf, "\x1b[{d}m", .{90 + i}),
                );
            },
            else => unreachable,
        },
        ColorType.color_256 => |val| try writeBuffered(
            try std.fmt.bufPrint(&buf, "\x1b[38;5;{d}m", .{val}),
        ),
        ColorType.color_rgb => |rgb| try writeBuffered(try std.fmt.bufPrint(
            &buf,
            "\x1b[38;2;{d};{d};{d};m",
            .{ rgb.red, rgb.green, rgb.blue },
        )),
    }
}

pub fn setBgColorBuffered(color: Color) !void {
    var buf: [19]u8 = undefined;
    switch (color) {
        ColorType.color_default => try writeBuffered("\x1b[49;m"),
        ColorType.color_8 => |val| try writeBuffered(try std.fmt.bufPrint(
            &buf,
            "\x1b[{d}m",
            .{40 + val.ordinal()},
        )),
        ColorType.color_16 => |val| switch (val.ordinal()) {
            0...7 => |i| try writeBuffered(
                try std.fmt.bufPrint(&buf, "\x1b[{d}m", .{40 + i}),
            ),
            8...15 => |i| {
                // Try both methods of "bright" colors for compatibility
                try writeBuffered(
                    try std.fmt.bufPrint(&buf, "\x1b[1;{d}m", .{40 + i}),
                );
                try writeBuffered(
                    try std.fmt.bufPrint(&buf, "\x1b[{d}m", .{100 + i}),
                );
            },
            else => unreachable,
        },
        ColorType.color_256 => |val| try writeBuffered(
            try std.fmt.bufPrint(&buf, "\x1b[48;5;{d}m", .{val}),
        ),
        ColorType.color_rgb => |rgb| try writeBuffered(try std.fmt.bufPrint(
            &buf,
            "\x1b[48;2;{d};{d};{d};m",
            .{ rgb.red, rgb.green, rgb.blue },
        )),
    }
}

pub fn flush() !void {
    if (buffer_len == 0) return;
    std.debug.assert(buffer_len <= MAX_BUFFER);
    _ = try os.write(os.STDOUT_FILENO, buffer[0..buffer_len]);
    buffer_len = 0;
}
