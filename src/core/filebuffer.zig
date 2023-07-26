const std = @import("std");

const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualSlices = testing.expectEqualSlices;
const expectEqualStrings = testing.expectEqualStrings;

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

test {
    testing.refAllDeclsRecursive(@This());
}

const Piece = struct {
    const Self = @This();

    /// Index into array of caches.
    cache: usize,

    /// Index of piece's first byte in cache.
    byte_start: usize,

    /// Length of piece in bytes. Assumed above 0.
    byte_len: usize,

    /// Index of piece's first newline in cache; if `newline_count` is 0, then
    /// this value should not be used.
    newline_start: usize = 0,

    /// Number of newlines in piece.
    newline_count: usize,

    /// Return index of end to byte range (exclusive).
    fn getByteEnd(self: *const Self) usize {
        return self.byte_start + self.byte_len;
    }

    test getByteEnd {
        const test_piece = Piece{
            .cache = 0,
            .byte_start = 0,
            .byte_len = 1,
            .newline_start = 0,
            .newline_count = 0,
        };
        try expectEqual(@as(usize, 1), test_piece.getByteEnd());

        const test_piece_more = Piece{
            .cache = 1,
            .byte_start = 15,
            .byte_len = 21,
            .newline_start = 13,
            .newline_count = 53,
        };
        try expectEqual(@as(usize, 36), test_piece_more.getByteEnd());
    }

    fn hasNewlines(self: *const Self) bool {
        return self.newline_count > 0;
    }

    test hasNewlines {
        const test_piece_false = Piece{
            .cache = 0,
            .byte_start = 0,
            .byte_len = 10,
            .newline_count = 0,
        };
        try expect(!test_piece_false.hasNewlines());

        const test_piece_true = Piece{
            .cache = 1,
            .byte_start = 11,
            .byte_len = 2135,
            .newline_start = 45,
            .newline_count = 13,
        };
        try expect(test_piece_true.hasNewlines());
    }

    fn getNewlineStart(self: *const Self) ?usize {
        if (self.hasNewlines()) {
            return self.newline_start;
        } else return null;
    }

    test getNewlineStart {
        const test_piece_none = Piece{
            .cache = 1,
            .byte_start = 57,
            .byte_len = 12832,
            .newline_start = 57,
            .newline_count = 0,
        };
        try expectEqual(@as(?usize, null), test_piece_none.getNewlineStart());

        const test_piece_some = Piece{
            .cache = 1,
            .byte_start = 98,
            .byte_len = 1298,
            .newline_start = 289,
            .newline_count = 1,
        };
        try expectEqual(@as(usize, 289), test_piece_some.getNewlineStart().?);
    }

    fn getNewlineEnd(self: *const Self) ?usize {
        if (self.hasNewlines()) {
            return self.newline_start + self.newline_count;
        } else return null;
    }

    test getNewlineEnd {
        const test_piece_none = Piece{
            .cache = 0,
            .byte_start = 13,
            .byte_len = 1000,
            .newline_start = 987,
            .newline_count = 0,
        };
        try expectEqual(@as(?usize, null), test_piece_none.getNewlineEnd());

        const test_piece_some = Piece{
            .cache = 0,
            .byte_start = 0,
            .byte_len = 1298432,
            .newline_start = 1384,
            .newline_count = 1,
        };
        try expectEqual(
            @as(usize, 1385),
            test_piece_some.getNewlineEnd().?,
        );

        const test_piece_some_more = Piece{
            .cache = 1,
            .byte_start = 13,
            .byte_len = 1342,
            .newline_start = 15,
            .newline_count = 18,
        };
        try expectEqual(
            @as(usize, 33),
            test_piece_some_more.getNewlineEnd().?,
        );
    }
};

const PieceIndex = struct {
    /// Index into array of pieces.
    piece: usize,

    /// Byte offset from start of piece (piece's byte offset).
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

    test init {
        const test_cache_empty = try Cache.init(testing.allocator, "");
        try expectEqual(@as(usize, 0), test_cache_empty.bytes.items.len);
        try expectEqual(@as(usize, 0), test_cache_empty.newlines.items.len);
        test_cache_empty.deinit();

        const test_cache_no_newlines = try Cache.init(
            testing.allocator,
            "this has no newlines",
        );
        try expectEqualStrings(
            "this has no newlines",
            test_cache_no_newlines.bytes.items,
        );
        try expectEqual(
            @as(usize, 0),
            test_cache_no_newlines.newlines.items.len,
        );
        test_cache_no_newlines.deinit();

        const test_cache_newlines = try Cache.init(
            testing.allocator,
            "test\n\noh no\r\n",
        );
        try expectEqualStrings(
            "test\n\noh no\r\n",
            test_cache_newlines.bytes.items,
        );
        try expectEqualSlices(
            usize,
            &[_]usize{ 4, 5, 12 },
            test_cache_newlines.newlines.items,
        );
        test_cache_newlines.deinit();
    }

    fn deinit(self: *const Self) void {
        self.bytes.deinit();
        self.newlines.deinit();
    }

    fn size(self: *const Self) usize {
        return self.bytes.items.len;
    }

    fn newlineCount(self: *const Self) usize {
        return self.newlines.items.len;
    }

    fn lineCount(self: *const Self) usize {
        return self.newlineCount() + 1;
    }

    fn getNewlines(self: *const Self, piece: Piece) []usize {
        const start = piece.getNewlineStart() orelse return &[_]usize{};
        const end = piece.getNewlineEnd() orelse return &[_]usize{};
        return self.newlines.items[start..end];
    }

    fn append(self: *Self, content: []const u8) !Piece {
        const old_len = self.size();
        const old_newlines = self.newlineCount();
        var result = Piece{
            .cache = 1, // Appending assumes use of append cache, index 1.
            .byte_start = old_len,
            .byte_len = content.len,
            .newline_start = old_newlines,
            .newline_count = 0,
        };

        // Restore cache to original state if error.
        errdefer {
            self.bytes.shrinkRetainingCapacity(old_len);
            self.newlines.shrinkRetainingCapacity(old_newlines);
        }

        try self.bytes.appendSlice(content);

        // Scan for newlines in added content.
        for (content, 0..) |b, i| {
            if (b == '\n') {
                try self.newlines.append(i + old_len);
                result.newline_count += 1;
            }
        }

        return result;
    }

    test append {
        var test_cache = try Cache.init(testing.allocator, "");
        const piece_1 = try test_cache.append("testing append");
        try expectEqualStrings("testing append", test_cache.bytes.items);
        try expectEqual(@as(usize, 0), test_cache.newlines.items.len);
        try expectEqual(@as(usize, 0), piece_1.byte_start);
        try expectEqual(@as(usize, 14), piece_1.byte_len);
        try expectEqual(@as(usize, 0), piece_1.newline_count);
        test_cache.deinit();

        test_cache = try Cache.init(testing.allocator, "test one two\nthree");
        const piece_2 = try test_cache.append(" four\nfive");
        try expectEqualStrings(
            "test one two\nthree four\nfive",
            test_cache.bytes.items,
        );
        try expectEqualSlices(
            usize,
            &[_]usize{ 12, 23 },
            test_cache.newlines.items,
        );
        try expectEqual(@as(usize, 18), piece_2.byte_start);
        try expectEqual(@as(usize, 10), piece_2.byte_len);
        try expectEqual(@as(usize, 1), piece_2.newline_start);
        try expectEqual(@as(usize, 1), piece_2.newline_count);
        test_cache.deinit();
    }
};

pub const FileBuffer = struct {
    const Self = @This();

    allocator: Allocator,
    caches: [2]Cache,
    pieces: ArrayList(Piece),

    pub fn init(allocator: Allocator, content: []const u8) !FileBuffer {
        var result = FileBuffer{
            .allocator = allocator,
            .caches = undefined,
            .pieces = undefined,
        };

        result.caches[0] = try Cache.init(allocator, content);
        result.caches[1] = try Cache.init(allocator, "");

        result.pieces = ArrayList(Piece).init(allocator);
        try result.pieces.append(Piece{
            .cache = 0,
            .byte_start = 0,
            .byte_len = content.len,
            .newline_start = 0,
            .newline_count = result.caches[0].newlineCount(),
        });

        return result;
    }

    test init {
        var allocator = testing.allocator;

        const fb_empty = try FileBuffer.init(allocator, "");
        try expectEqual(@as(usize, 2), fb_empty.caches.len);
        try expectEqualStrings("", fb_empty.caches[0].bytes.items);
        try expectEqualStrings("", fb_empty.caches[1].bytes.items);
        try expectEqual(@as(usize, 1), fb_empty.pieces.items.len);
        const fb_empty_piece = fb_empty.pieces.items[0];
        fb_empty.deinit();
        try expectEqual(@as(usize, 0), fb_empty_piece.cache);
        try expectEqual(@as(usize, 0), fb_empty_piece.byte_start);
        try expectEqual(@as(usize, 0), fb_empty_piece.byte_len);
        try expectEqual(@as(usize, 0), fb_empty_piece.newline_count);

        const fb_no_newline = try FileBuffer.init(allocator, "testing one line");
        try expectEqual(@as(usize, 2), fb_no_newline.caches.len);
        try expectEqualStrings(
            "testing one line",
            fb_no_newline.caches[0].bytes.items,
        );
        try expectEqualStrings("", fb_no_newline.caches[1].bytes.items);
        try expectEqual(@as(usize, 1), fb_no_newline.pieces.items.len);
        const fb_no_newline_piece = fb_no_newline.pieces.items[0];
        fb_no_newline.deinit();
        try expectEqual(@as(usize, 0), fb_no_newline_piece.cache);
        try expectEqual(@as(usize, 0), fb_no_newline_piece.byte_start);
        try expectEqual(@as(usize, 16), fb_no_newline_piece.byte_len);
        try expectEqual(@as(usize, 0), fb_no_newline_piece.newline_count);

        const fb_newline = try FileBuffer.init(allocator, "one two\nthree\nfour");
        try expectEqual(@as(usize, 2), fb_newline.caches.len);
        try expectEqualStrings(
            "one two\nthree\nfour",
            fb_newline.caches[0].bytes.items,
        );
        try expectEqualStrings("", fb_newline.caches[1].bytes.items);
        try expectEqual(@as(usize, 1), fb_newline.pieces.items.len);
        const fb_newline_piece = fb_newline.pieces.items[0];
        fb_newline.deinit();
        try expectEqual(@as(usize, 0), fb_newline_piece.cache);
        try expectEqual(@as(usize, 0), fb_newline_piece.byte_start);
        try expectEqual(@as(usize, 18), fb_newline_piece.byte_len);
        try expectEqual(@as(usize, 2), fb_newline_piece.newline_count);
        try expectEqual(@as(usize, 0), fb_newline_piece.newline_start);
    }

    pub fn deinit(self: *const Self) void {
        for (self.caches) |cache| {
            cache.deinit();
        }
        self.pieces.deinit();
    }

    pub fn size(self: *const Self) usize {
        var result: usize = 0;
        for (self.pieces.items) |piece| {
            result += piece.byte_len;
        }
        return result;
    }

    pub fn newlineCount(self: *const Self) usize {
        var result: usize = 0;
        for (self.pieces.items) |piece| {
            result += piece.newline_count;
        }
        return result;
    }

    pub fn lineCount(self: *const Self) usize {
        return self.newlineCount() + 1;
    }

    pub fn getContent(self: *const Self, allocator: Allocator) !ArrayList(u8) {
        var result = try ArrayList(u8).initCapacity(allocator, self.size());
        for (self.pieces.items) |piece| {
            const cache = self.caches[piece.cache];
            result.appendSliceAssumeCapacity(
                cache.bytes.items[piece.byte_start..piece.getByteEnd()],
            );
        }
        return result;
    }

    /// Get byte index of line start in file.
    pub fn getLineIndex(self: *const Self, line: usize) !usize {
        if (line > self.newlineCount()) return error.OutOfBounds;

        var lines_remaining: usize = line;
        var current_index: usize = 0;
        for (self.pieces.items) |piece| {
            // Keep iterating to find correct line.
            if (lines_remaining > piece.newline_count) {
                lines_remaining -= piece.newline_count;
                current_index += piece.byte_len;
                continue;
            }
            // Line starts in current piece.
            else {
                if (lines_remaining > 0) {
                    const newlines = self.caches[piece.cache].getNewlines(
                        piece,
                    );
                    const newline = newlines[lines_remaining - 1];
                    return current_index + (newline - piece.byte_start + 1);
                } else return current_index;
            }
        }
        unreachable;
    }

    /// Get line in file, excluding terminating newline.
    pub fn getLine(
        self: *const Self,
        allocator: Allocator,
        line: usize,
    ) !ArrayList(u8) {
        if (line > self.newlineCount()) return error.OutOfBounds;

        var result = ArrayList(u8).init(allocator);
        var lines_remaining: usize = line;

        for (self.pieces.items) |piece| {
            // Keep iterating to find correct line.
            if (lines_remaining > piece.newline_count) {
                lines_remaining -= piece.newline_count;
                continue;
            }
            // Line starts in current piece.
            else {
                const cache = self.caches[piece.cache];
                const cache_content = cache.bytes.items;
                const cache_newlines = cache.getNewlines(piece);

                const byte_start = if (lines_remaining > 0)
                    cache_newlines[lines_remaining - 1] + 1
                else
                    piece.byte_start;

                // Line ends in current piece.
                if (lines_remaining < piece.newline_count) {
                    const newline = cache_newlines[lines_remaining];
                    const byte_end = if (cache_content[newline - 1] == '\r')
                        newline - 1
                    else
                        newline;

                    if (byte_start < byte_end) {
                        try result.appendSlice(
                            cache_content[byte_start..byte_end],
                        );
                    }
                    break;
                }
                // Line continues to next piece.
                else {
                    const byte_end = piece.getByteEnd();
                    if (byte_start < byte_end) {
                        try result.appendSlice(
                            cache_content[byte_start..byte_end],
                        );
                    }
                    lines_remaining = 0;
                    continue;
                }
            }
        }

        return result;
    }

    test getLine {
        var allocator = testing.allocator;

        const fb_empty = try FileBuffer.init(allocator, "");
        const empty_line = try fb_empty.getLine(testing.allocator, 0);
        fb_empty.deinit();
        try expectEqualStrings("", empty_line.items);
        empty_line.deinit();

        const fb_one_line = try FileBuffer.init(allocator, "testing one line");
        const one_line = try fb_one_line.getLine(testing.allocator, 0);
        fb_one_line.deinit();
        try expectEqualStrings("testing one line", one_line.items);
        one_line.deinit();

        const fb_multi_line = try FileBuffer.init(
            allocator,
            "one two\r\nthree\nfour",
        );
        const multi_line_0 = try fb_multi_line.getLine(testing.allocator, 0);
        const multi_line_1 = try fb_multi_line.getLine(testing.allocator, 1);
        const multi_line_2 = try fb_multi_line.getLine(testing.allocator, 2);
        fb_multi_line.deinit();
        try expectEqualStrings("one two", multi_line_0.items);
        multi_line_0.deinit();
        try expectEqualStrings("three", multi_line_1.items);
        multi_line_1.deinit();
        try expectEqualStrings("four", multi_line_2.items);
        multi_line_2.deinit();
    }

    /// Retrieve piece based on index.
    fn findPiece(self: *const Self, index: usize) PieceIndex {
        var remaining_index = index;

        for (self.pieces.items, 0..) |piece, i| {
            if (remaining_index >= piece.byte_len) {
                remaining_index -= piece.byte_len;
                continue;
            } else {
                return PieceIndex{
                    .piece = i,
                    .offset = remaining_index,
                };
            }
        } else return PieceIndex{
            .piece = self.pieces.items.len,
            .offset = remaining_index,
        };
    }

    pub fn insert(self: *Self, index: usize, content: []const u8) !void {
        if (content.len == 0) return;
        var new_piece = try self.caches[1].append(content);
        const piece_index = self.findPiece(index);

        std.debug.assert(piece_index.piece <= self.pieces.items.len);

        if (piece_index.piece == self.pieces.items.len and
            piece_index.offset > 0)
        {
            return error.OutOfBounds;
        }

        // New piece can be appended to end of filebuffer.
        else if (piece_index.piece == self.pieces.items.len) {
            try self.pieces.append(new_piece);
            return;
        }

        // New piece can be inserted in front of piece index.
        else if (piece_index.offset == 0) {
            // Check if new piece can be merged into previous piece.
            if (piece_index.piece > 0) {
                const prev_ind = piece_index.piece - 1;
                const prev_piece = self.pieces.items[prev_ind];
                if (prev_piece.cache == new_piece.cache and
                    prev_piece.getByteEnd() == new_piece.byte_start)
                {
                    self.pieces.items[prev_ind].byte_len += new_piece.byte_len;
                    self.pieces.items[prev_ind].newline_count +=
                        new_piece.newline_count;
                    return;
                }
            }

            // New piece must be inserted.
            try self.pieces.insert(piece_index.piece, new_piece);

            return;
        }

        // New piece must be inserted by splitting an existing piece.
        else {
            const piece = self.pieces.items[piece_index.piece];
            std.debug.assert(piece.byte_len > piece_index.offset);

            var prefix_piece = Piece{
                .cache = piece.cache,
                .byte_start = piece.byte_start,
                .byte_len = piece_index.offset,
                .newline_start = piece.newline_start,
                .newline_count = 0,
            };
            var suffix_piece = Piece{
                .cache = piece.cache,
                .byte_start = piece.byte_start + piece_index.offset,
                .byte_len = piece.byte_len - piece_index.offset,
                .newline_start = piece.newline_start,
                .newline_count = 0,
            };

            for (self.caches[piece.cache].getNewlines(piece)) |newline| {
                if (newline >= prefix_piece.getByteEnd()) break;
                prefix_piece.newline_count += 1;
            }

            suffix_piece.newline_start += prefix_piece.newline_count;
            suffix_piece.newline_count = piece.newline_count -
                prefix_piece.newline_count;

            self.pieces.items[piece_index.piece] = prefix_piece;
            errdefer self.pieces.items[piece_index.piece] = piece;
            try self.pieces.insert(piece_index.piece + 1, new_piece);
            errdefer _ = self.pieces.orderedRemove(piece_index.piece + 1);
            try self.pieces.insert(piece_index.piece + 2, suffix_piece);
            return;
        }
    }

    test insert {
        var fb = try FileBuffer.init(testing.allocator, "one two");

        try fb.insert(7, " three");
        var fb_content = try fb.getContent(testing.allocator);
        try expectEqualStrings(
            "one two three",
            fb_content.items,
        );
        fb_content.deinit();

        try fb.insert(0, "zero ");
        fb_content = try fb.getContent(testing.allocator);
        try expectEqualStrings(
            "zero one two three",
            fb_content.items,
        );
        fb_content.deinit();

        try fb.insert(8, " one-point-five");
        fb_content = try fb.getContent(testing.allocator);
        try expectEqualStrings(
            "zero one one-point-five two three",
            fb_content.items,
        );
        fb_content.deinit();

        fb.deinit();
    }

    pub fn insertLine(self: *Self, line: usize, content: []const u8) !void {
        _ = content;
        _ = line;
        _ = self;
    }
};
