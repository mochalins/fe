const std = @import("std");

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.MultiArrayList;
const FileBuffer = @import("filebuffer.zig");

const MAX_PATH_BYTES = std.fs.MAX_PATH_BYTES;

var initialized: bool = false;

var buffer_paths: std.BufMap = undefined;
var buffers: std.StringHashMap(*Buffer) = undefined;

var buffers: std.ArrayList(*Buffer);

pub const Buffer = struct {
    arena: ArenaAllocator,
    path: []const u8,
    content: FileBuffer,
    last_modified: ?i128 = null,
    references: usize = 0,

    pub fn init(
        path: []const u8,
    ) !Buffer {
        var result = Buffer{
            .buffer = undefined,
            .arena = ArenaAllocator.init(std.heap.page_allocator),
            .last_modified = last_modified,
        };

        result.buffer = FileBuffer.init(result.arena.allocator(), content);

        return result;
    }

    pub fn deinit(self: *Buffer) void {
        self.buffer.deinit();
        self.arena.deinit();
    }
};

pub fn init(allocator: Allocator) void {
    if (initialized) return;
    buffers = std.StringHashMap(Buffer).init(allocator);
    initialized = true;
}

pub fn deinit() void {
    if (!initialized) return;
    var buffers_it = buffers.iterator();
    while (buffers_it.next()) |entry| {
        entry.value_ptr.deinit();
    }
    buffers.deinit();
    initialized = false;
}
