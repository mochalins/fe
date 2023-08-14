const Color = @This();

kind: union(enum(u2)) {
    default: struct {},
    extended: u8,
    rgb: packed struct {
        red: u8,
        green: u8,
        blue: u8,
    },
    none,
},

pub const Default = Color{ .kind = .{ .default = .{} } };
pub const None = Color{ .kind = .none };

pub const Black = Color{ .kind = .{ .extended = 0 } };
pub const Red = Color{ .kind = .{ .extended = 1 } };
pub const Green = Color{ .kind = .{ .extended = 2 } };
pub const Yellow = Color{ .kind = .{ .extended = 3 } };
pub const Blue = Color{ .kind = .{ .extended = 4 } };
pub const Magenta = Color{ .kind = .{ .extended = 5 } };
pub const Cyan = Color{ .kind = .{ .extended = 6 } };
pub const White = Color{ .kind = .{ .extended = 7 } };
pub const BrightBlack = Color{ .kind = .{ .extended = 8 } };
pub const BrightRed = Color{ .kind = .{ .extended = 9 } };
pub const BrightGreen = Color{ .kind = .{ .extended = 10 } };
pub const BrightYellow = Color{ .kind = .{ .extended = 11 } };
pub const BrightBlue = Color{ .kind = .{ .extended = 12 } };
pub const BrightMagenta = Color{ .kind = .{ .extended = 13 } };
pub const BrightCyan = Color{ .kind = .{ .extended = 14 } };
pub const BrightWhite = Color{ .kind = .{ .extended = 15 } };

pub fn Extended(value: u8) Color {
    return .{ .kind = .{ .extended = value } };
}

pub fn Rgb(red: u8, green: u8, blue: u8) Color {
    return .{ .kind = .{ .rgb = .{
        .red = red,
        .green = green,
        .blue = blue,
    } } };
}
