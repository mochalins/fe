const std = @import("std");

const core = @import("root").core;

const Allocator = std.mem.Allocator;

const FileBuffer = core.filebuffer.FileBuffer;

pub fn open(allocator: Allocator, file_path: []const u8) !FileBuffer {
    const file = try std.fs.cwd().createFile(file_path, .{
        .read = true,
        .truncate = false,
    });

    defer file.close();

    var file_bytes = try file.reader().readAllAlloc(allocator, std.math.maxInt(u32));

    return FileBuffer.init(file_bytes);
}
