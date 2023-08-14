const View = @This();

const StatusBar = @import("StatusBar.zig");

pub const Mode = enum(u1) { view, edit };

mode: Mode = .view,
size: packed struct { rows: u16, cols: u16 } = .{ .rows = 0, .cols = 0 },
cursor: packed struct { row: u16, col: u16 } = .{ .row = 0, .col = 0 },
row_offset: usize = 0,

status_bar: StatusBar,

pub fn init() View {}

pub fn deinit(self: *View) void {
    _ = self;
}
