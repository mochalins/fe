const std = @import("std");

pub const Key = enum(u8) {
    ctrl_c = 3,
    ctrl_f = 6,
    ctrl_h = 8,
    tab = 9,
    ctrl_l = 12,
    enter = 13,
    ctrl_q = 17,
    ctrl_s = 19,
    ctrl_u = 21,
    esc = 27,
    backspace = 127,
    arrow_left = 128,
    arrow_right,
    arrow_up,
    arrow_down,
    del,
    home,
    end,
    page_up,
    page_down,
    _,

    /// Read a key from the terminal put in raw mode, trying to handle
    /// escape sequences.
    pub fn readKey() !u8 {
        const linux = std.os.linux;

        var c: [1]u8 = [1]u8{0};
        var seq: [3]u8 = undefined;
        _ = try std.os.read(linux.STDIN_FILENO, &c);

        switch (c[0]) {
            @intFromEnum(Key.esc) => {
                _ = try std.os.read(linux.STDIN_FILENO, seq[0..1]);
                _ = try std.os.read(linux.STDIN_FILENO, seq[1..2]);

                if (seq[0] == '[') {
                    switch (seq[1]) {
                        '0'...'9' => {
                            _ = try std.os.read(linux.STDIN_FILENO, seq[2..3]);
                            if (seq[2] == '~') {
                                switch (seq[1]) {
                                    '1' => return @intFromEnum(Key.home),
                                    '3' => return @intFromEnum(Key.del),
                                    '4' => return @intFromEnum(Key.end),
                                    '5' => return @intFromEnum(Key.page_up),
                                    '6' => return @intFromEnum(Key.page_down),
                                    '7' => return @intFromEnum(Key.home),
                                    '8' => return @intFromEnum(Key.end),
                                    else => {},
                                }
                            }
                        },
                        'A' => return @intFromEnum(Key.arrow_up),
                        'B' => return @intFromEnum(Key.arrow_down),
                        'C' => return @intFromEnum(Key.arrow_right),
                        'D' => return @intFromEnum(Key.arrow_left),
                        'H' => return @intFromEnum(Key.home),
                        'F' => return @intFromEnum(Key.end),
                        else => {},
                    }
                } else if (seq[0] == 'O') {
                    switch (seq[1]) {
                        'H' => return @intFromEnum(Key.home),
                        'F' => return @intFromEnum(Key.end),
                        else => {},
                    }
                }

                return @intFromEnum(Key.esc);
            },
            else => return c[0],
        }

        return c[0];
    }
};
