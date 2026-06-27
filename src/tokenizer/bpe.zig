const std = @import("std");
const Pair = @import("pair.zig").Pair;
const PairContext = @import("pair.zig").PairContext;
const bytesToTokens = @import("byte_encoding.zig").bytesToTokens;
const Regex = @import("pretokenize.zig").Regex;

pub const Tokenizer = struct {
    vocab: std.StringHashMap(u32),
    merges: std.ArrayList(Pair),
    merges_map: std.HashMap(Pair, u32, PairContext, std.hash_map.default_max_load_percentage),
    regex: Regex,
    special_tokens: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, path: []const u8) !Tokenizer {
        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const buffer = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(buffer);

        var parsed = try std.json.parseFromSlice(std.json.Value, allocator, buffer, .{});
        defer parsed.deinit();

        var vocab = std.StringHashMap(u32).init(allocator);
        errdefer vocab.deinit();

        var merges = std.ArrayList(Pair).init(allocator);
        errdefer merges.deinit();

        var merges_map = std.HashMap(Pair, u32, PairContext, std.hash_map.default_max_load_percentage).initContext(allocator, PairContext{});
        errdefer merges_map.deinit();

        var special_tokens = std.ArrayList([]const u8).init(allocator);
        errdefer special_tokens.deinit();

        const model = parsed.value.object.get("model") orelse return error.InvalidTokenizerJson;
        if (model != .object) return error.InvalidTokenizerJson;

        const vocab_json = model.object.get("vocab") orelse return error.InvalidTokenizerJson;
        if (vocab_json != .object) return error.InvalidTokenizerJson;

        var vocab_idx: usize = 0;
        while (vocab_idx < vocab_json.object.count()) : (vocab_idx += 1) {
            const key = try allocator.dupe(u8, vocab_json.object.keys()[vocab_idx]);
            const value = @as(u32, @intCast(vocab_json.object.values()[vocab_idx].integer));
            try vocab.put(key, value);
        }

        const merges_json = model.object.get("merges") orelse return error.InvalidTokenizerJson;
        if (merges_json != .array) return error.InvalidTokenizerJson;

        var rank: u32 = 0;
        for (merges_json.array.items) |merge| {
            var splits = std.mem.splitScalar(u8, merge.string, ' ');
            const left = splits.next() orelse continue;
            const right = splits.next() orelse continue;

            const left_owned = try allocator.dupe(u8, left);
            const right_owned = try allocator.dupe(u8, right);

            try merges.append(.{ .left = left_owned, .right = right_owned });
            try merges_map.put(.{ .left = left_owned, .right = right_owned }, rank);
            rank += 1;
        }

        if (parsed.value.object.get("added_tokens")) |added_tokens| {
            if (added_tokens == .array) {
                for (added_tokens.array.items) |added_token| {
                    if (added_token != .object) continue;
                    const is_special = added_token.object.get("special") orelse continue;
                    const content = added_token.object.get("content") orelse continue;
                    if (is_special == .bool and content == .string and is_special.bool) {
                        try special_tokens.append(try allocator.dupe(u8, content.string));
                    }
                }
            }
        }

        const regex = try Regex.init(
            allocator,
            "('s|'t|'re|'ve|'m|'ll|'d| ?[[:alpha:]]+| ?[[:digit:]]+| ?[^[:alnum:][:space:]]+| +[[:space:]]*| +)",
        );

        return .{
            .vocab = vocab,
            .merges = merges,
            .merges_map = merges_map,
            .regex = regex,
            .special_tokens = special_tokens,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Tokenizer) void {
        var vocab_it = self.vocab.iterator();
        while (vocab_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.vocab.deinit();

        for (self.merges.items) |merge| {
            self.allocator.free(merge.left);
            self.allocator.free(merge.right);
        }
        self.merges.deinit();
        self.merges_map.deinit();

        for (self.special_tokens.items) |item| {
            self.allocator.free(item);
        }
        self.special_tokens.deinit();

        self.regex.deinit();
    }

    pub fn encode(self: *Tokenizer, text: []const u8) ![]u32 {
        const allocator = self.allocator;

        var byte_encoding = std.ArrayList([]const u8).init(allocator);
        defer {
            for (byte_encoding.items) |item| allocator.free(item);
            byte_encoding.deinit();
        }

        var current = text;
        while (current.len > 0) {
            var earliest_special_token: ?[]const u8 = null;
            var earliest_index: usize = current.len;

            for (self.special_tokens.items) |special_token| {
                if (std.mem.indexOf(u8, current, special_token)) |index| {
                    if (index < earliest_index) {
                        earliest_special_token = special_token;
                        earliest_index = index;
                    }
                }
            }

            if (earliest_special_token == null or earliest_index > 0) {
                const chunk = if (earliest_index > 0) current[0..earliest_index] else current;
                const matches = try self.regex.findAll(chunk);
                defer {
                    for (matches) |m| allocator.free(m);
                    allocator.free(matches);
                }

                for (matches) |match| {
                    const encoded = try bytesToTokens(allocator, match);
                    try byte_encoding.append(encoded);
                }
            }

            if (earliest_special_token == null) break;

            try byte_encoding.append(try allocator.dupe(u8, earliest_special_token.?));
            current = current[earliest_index + earliest_special_token.?.len ..];
        }

        var token_ids = std.ArrayList(u32).init(allocator);
        errdefer token_ids.deinit();

        for (byte_encoding.items) |encoding| {
            if (self.vocab.get(encoding)) |id| {
                try token_ids.append(id);
                continue;
            }

            var code_points = std.ArrayList([]const u8).init(allocator);
            defer {
                for (code_points.items) |code_point| allocator.free(code_point);
                code_points.deinit();
            }

            var pos: usize = 0;
            while (pos < encoding.len) {
                const len = std.unicode.utf8ByteSequenceLength(encoding[pos]) catch return error.InvalidUtf8;
                if (pos + len > encoding.len) return error.InvalidUtf8;

                try code_points.append(try allocator.dupe(u8, encoding[pos .. pos + len]));
                pos += len;
            }

            while (code_points.items.len > 1) {
                var best_idx: ?usize = null;
                var best_rank: u32 = std.math.maxInt(u32);

                for (0..code_points.items.len - 1) |i| {
                    const pair = Pair{
                        .left = code_points.items[i],
                        .right = code_points.items[i + 1],
                    };

                    if (self.merges_map.get(pair)) |pair_rank| {
                        if (pair_rank < best_rank) {
                            best_rank = pair_rank;
                            best_idx = i;
                        }
                    }
                }

                const merge_idx = best_idx orelse break;

                const merged = try allocator.alloc(u8, code_points.items[merge_idx].len + code_points.items[merge_idx + 1].len);
                @memcpy(merged[0..code_points.items[merge_idx].len], code_points.items[merge_idx]);
                @memcpy(merged[code_points.items[merge_idx].len..], code_points.items[merge_idx + 1]);

                allocator.free(code_points.items[merge_idx]);
                allocator.free(code_points.items[merge_idx + 1]);

                code_points.items[merge_idx] = merged;
                _ = code_points.orderedRemove(merge_idx + 1);
            }

            for (code_points.items) |token| {
                try token_ids.append(self.vocab.get(token) orelse return error.TokenNotInVocab);
            }
        }

        return try token_ids.toOwnedSlice();
    }

    pub fn count(self: *Tokenizer, text: []const u8) !usize {
        const tokens = try self.encode(text);
        defer self.allocator.free(tokens);
        return tokens.len;
    }
};

test "encode hello world with GPT-2 vocab" {
    const allocator = std.testing.allocator;
    var tokenizer = try Tokenizer.init(allocator, "fixtures/tokenizer.json");
    defer tokenizer.deinit();

    const tokens = try tokenizer.encode("hello world");
    defer allocator.free(tokens);

    try std.testing.expectEqual(@as(usize, 2), tokens.len);
    try std.testing.expectEqual(@as(u32, 31373), tokens[0]);
    try std.testing.expectEqual(@as(u32, 995), tokens[1]);
}

test "encode edge cases" {
    const allocator = std.testing.allocator;
    var tokenizer = try Tokenizer.init(allocator, "fixtures/tokenizer.json");
    defer tokenizer.deinit();

    const empty = try tokenizer.encode("");
    defer allocator.free(empty);
    try std.testing.expectEqual(@as(usize, 0), empty.len);

    const single = try tokenizer.encode("a");
    defer allocator.free(single);
    try std.testing.expectEqual(@as(usize, 1), single.len);
}
