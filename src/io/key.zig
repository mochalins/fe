const builtin = @import("builtin");
const key = switch (builtin.target.os.tag) {
    .macos, .linux => @import("key/posix.zig"),
    else => @compileError("OS not supported"),
};

pub const Key = key.Key;
