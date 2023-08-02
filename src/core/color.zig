pub const ColorDefault = struct {};

/// 3 bit ANSI escape code color names.
pub const Color8 = enum(u3) {
    const Self = @This();

    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,

    pub fn ordinal(self: Self) u8 {
        return @as(u8, @intFromEnum(self));
    }

    pub fn ordinalType(self: Self, comptime T: type) T {
        return @as(T, @intFromEnum(self));
    }
};

/// 4 bit ANSI escape code color names.
pub const Color16 = enum(u4) {
    const Self = @This();

    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,
    bright_black,
    bright_red,
    bright_green,
    bright_yellow,
    bright_blue,
    bright_magenta,
    bright_cyan,
    bright_white,

    pub fn ordinal(self: Self) u8 {
        return @as(u8, @intFromEnum(self));
    }

    pub fn ordinalType(self: Self, comptime T: type) T {
        return @as(T, @intFromEnum(self));
    }
};

/// 8 bit ANSI escape code colors; 0-15 correspond to Color16 ordinal values,
/// 16-231 are values in a 6x6x6 color cube (16 + 36*r + 6*g + b), and 232-255
/// are grayscale from dark to light.
pub const Color256 = u8;

pub const ColorRgb = packed struct {
    red: u8,
    green: u8,
    blue: u8,
};

pub const ColorType = enum {
    color_default,
    color_8,
    color_16,
    color_256,
    color_rgb,
};

pub const Color = union(ColorType) {
    color_default: ColorDefault,
    color_8: Color8,
    color_16: Color16,
    color_256: Color256,
    color_rgb: ColorRgb,

    pub fn initDefault() Color {
        return .{ .color_default = .{} };
    }

    pub fn init8(color: Color8) Color {
        return .{ .color_8 = color };
    }

    pub fn init16(color: Color16) Color {
        return .{ .color_16 = color };
    }

    pub fn init256(color: Color256) Color {
        return .{ .color_256 = color };
    }

    pub fn initRgb(red: u8, green: u8, blue: u8) Color {
        return .{ .color_rgb = .{ .red = red, .green = green, .blue = blue } };
    }
};
