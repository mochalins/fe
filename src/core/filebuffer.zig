const std = @import("std");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

const Piece = struct {
    const Self = @This();

    /// Index into array of caches
    cache: usize,

    /// Index of piece's first byte in cache
    byte_start: usize,

    /// Length of piece in bytes
    byte_len: usize,

    /// Index of piece's first newline in cache
    newline_start: usize,

    /// Number of newlines in piece
    newline_num: usize,
};

const PieceIndex = struct {
    /// Index into array of pieces
    piece: usize,

    /// Byte offset from start of piece (piece's byte offset)
    offset: usize,
};

const Cache = struct {
    const Self = @This();

    bytes: ArrayList(u8),
    newlines: ArrayList(usize),

    fn init(allocator: Allocator, content: []const u8) !Cache {
        var result = Cache{
            .bytes = try ArrayList(u8).initCapacity(allocator, content.len),
            .newlines = ArrayList(usize).init(allocator),
        };

        if (content.len > 0) {
            result.bytes.appendSliceAssumeCapacity(content);

            for (content, 0..) |b, i| {
                if (b == '\n') {
                    try result.newlines.append(i);
                }
            }
        }

        return result;
    }

    fn deinit(self: *Self) void {
        self.bytes.deinit();
        self.newlines.deinit();
    }

    fn size(self: *const Self) usize {
        return self.bytes.items.len;
    }

    fn numNewlines(self: *const Self) usize {
        return self.newlines.items.len;
    }

    fn numLines(self: *const Self) usize {
        return self.numNewlines() + 1;
    }

    fn append(self: *Self, content: []const u8) !Piece {
        const old_len = self.size();
        const old_newlines = self.numNewlines();
        var result = Piece{
            .cache = 1, // Appending assumes use of append cache, index 1
            .byte_start = old_len,
            .byte_len = content.len,
            .newline_start = old_newlines,
            .newline_num = 0,
        };

        // Restore cache to original state if error
        errdefer {
            self.bytes.shrinkRetainingCapacity(old_len);
            self.newlines.shrinkRetainingCapacity(old_newlines);
        }

        try self.bytes.appendSlice(content);

        // Scan for newlines in added content
        for (content, 0..) |b, i| {
            if (b == '\n') {
                try self.newlines.append(i + old_len);
                result.newline_num += 1;
            }
        }

        return result;
    }
};

pub const FileBuffer = struct {
    const Self = @This();

    allocator: std.heap.ArenaAllocator,
    caches: [2]Cache,
    pieces: ArrayList(Piece),

    pub fn init(content: []const u8) !FileBuffer {
        var result = FileBuffer{
            .allocator = ArenaAllocator.init(std.heap.page_allocator),
            .caches = undefined,
            .pieces = undefined,
        };

        const allocator = result.allocator.allocator();
        result.pieces = ArrayList(Piece).init(allocator);

        result.caches[0] = try Cache.init(allocator, content);
        result.caches[1] = try Cache.init(allocator, "");

        try result.pieces.append(Piece{
            .cache = 0,
            .byte_start = 0,
            .byte_len = content.len,
            .newline_start = 0,
            .newline_num = result.caches[0].numNewlines(),
        });

        return result;
    }

    pub fn deinit(self: *Self) void {
        self.pieces.deinit();
        self.allocator.deinit();
    }
};
