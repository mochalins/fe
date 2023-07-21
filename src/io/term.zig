const builtin = @import("builtin");
const term = switch (builtin.os.tag) {
    .macos, .linux => @import("term/posix.zig"),
    else => @compileError("OS not supported"),
};

pub const Term = term.Term;
