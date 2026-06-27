const std = @import("std");
const c = @cImport(@cInclude("regex.h"));

pub const Regex = struct {
    allocator: std.mem.Allocator,
    regex: c.regex_t,

    pub fn init(allocator: std.mem.Allocator, pattern: []const u8) !Regex {
        var regex: c.regex_t = undefined;
        const pattern_z = try allocator.dupeZ(u8, pattern);
        defer allocator.free(pattern_z);

        if (c.regcomp(&regex, pattern_z, c.REG_EXTENDED) != 0) {
            return error.RegexCompilationFailed;
        }

        return .{
            .allocator = allocator,
            .regex = regex,
        };
    }

    pub fn deinit(self: Regex) void {
        c.regfree(@constCast(&self.regex));
    }

    pub fn findAll(self: *Regex, text: []const u8) ![][]const u8 {
        const allocator = self.allocator;

        var buffer: ?[]u8 = null;
        defer if (buffer) |b| allocator.free(b);

        const text_null_terminated = if (text.len == 0 or text[text.len - 1] != 0) blk: {
            buffer = try allocator.alloc(u8, text.len + 1);
            @memcpy(buffer.?[0..text.len], text);
            buffer.?[text.len] = 0;
            break :blk buffer.?;
        } else text;

        var matches = std.ArrayList([]const u8).init(allocator);
        errdefer {
            for (matches.items) |m| allocator.free(m);
            matches.deinit();
        }

        var offset: usize = 0;
        while (offset < text.len) {
            var pmatch: [1]c.regmatch_t = undefined;
            const exec_result = c.regexec(&self.regex, text_null_terminated[offset..].ptr, 1, &pmatch, 0);
            if (exec_result != 0) break;

            const start = offset + @as(usize, @intCast(pmatch[0].rm_so));
            const end = offset + @as(usize, @intCast(pmatch[0].rm_eo));

            const match_text = try allocator.dupe(u8, text_null_terminated[start..end]);
            errdefer allocator.free(match_text);

            try matches.append(match_text);
            offset = end;
        }

        return matches.toOwnedSlice();
    }
};

test "GPT-2 pretokenizer regex splits text" {
    const allocator = std.testing.allocator;
    const pattern = "('s|'t|'re|'ve|'m|'ll|'d| ?[[:alpha:]]+| ?[[:digit:]]+| ?[^[:alnum:][:space:]]+| +[[:space:]]*| +)";

    var regex = try Regex.init(allocator, pattern);
    defer regex.deinit();

    const text = "Hello, I'm a test string with numbers 123 and symbols @#$!";
    const matches = try regex.findAll(text);
    defer {
        for (matches) |m| allocator.free(m);
        allocator.free(matches);
    }

    try std.testing.expectEqual(@as(usize, 13), matches.len);
    try std.testing.expectEqualStrings("Hello", matches[0]);
    try std.testing.expectEqualStrings(" I", matches[2]);
}
