const StatusBar = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const root = @import("root");
const core = root.core;
const config = core.config;
const editor = core.editor;
const io = root.io;
const term = io.term;
const ui = root.ui;
const View = ui.View;

cols: u16,

pub fn drawBuffered(
    self: *const StatusBar,
    cursor_row: usize, // Row of cursor in file buffer.
    cursor_col: usize, // Column of cursor in file buffer.
    mode: View.Mode,
) !void {
    if (self.cols == 0) return;
    var cols_written: usize = 0;

    // Condensed status bar without filename
    if (self.cols < 20) {
        switch (mode) {
            .view => {
                try term.setFgColorBuffered(config.status_mode_view_color_fg);
                try term.setBgColorBuffered(config.status_mode_view_color_bg);
                try term.writeBuffered("V");
            },
            .edit => {
                try term.setFgColorBuffered(config.status_mode_edit_color_fg);
                try term.setBgColorBuffered(config.status_mode_edit_color_bg);
                try term.writeBuffered("E");
            },
        }
        cols_written += 1;
    }
    // Normal status bar with filename
    else {
        switch (mode) {
            .view => {
                try term.setFgColorBuffered(config.status_mode_view_color_fg);
                try term.setBgColorBuffered(config.status_mode_view_color_bg);
                try term.writeBuffered(" View ");
            },
            .edit => {
                try term.setFgColorBuffered(config.status_mode_edit_color_fg);
                try term.setBgColorBuffered(config.status_mode_edit_color_bg);
                try term.writeBuffered(" Edit ");
            },
        }
        cols_written += 6;
    }

    var buffer: [64]u8 = undefined;
    const cursor_indices: []const u8 = try std.fmt.bufPrint(
        &buffer,
        "{}:{}",
        .{ cursor_row, cursor_col },
    );

    try term.setFgColorBuffered(config.status_color_fg);
    try term.setBgColorBuffered(config.status_color_bg);
    while (cols_written + cursor_indices.len < self.cols) : (cols_written += 1) {
        try term.writeBuffered(" ");
    }
    try term.writeBuffered(cursor_indices);
}
