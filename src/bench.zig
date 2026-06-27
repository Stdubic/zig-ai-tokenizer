const std = @import("std");
const Tokenizer = @import("root.zig").Tokenizer;

const sample_text =
    \\Token tracking is cheap. Do it everywhere.
    \\Batch processing is faster than individual operations.
    \\Arena allocators work well for session-based tracking.
    \\Budget enforcement prevents surprises.
    \\Performance is not the bottleneck. API calls are slower than tracking.
;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tokenizer = try Tokenizer.init(allocator, "fixtures/tokenizer.json");
    defer tokenizer.deinit();

    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();

    var i: usize = 0;
    while (i < 200) : (i += 1) {
        try text.appendSlice(sample_text);
    }

    const iterations: u64 = 1000;
    var timer = try std.time.Timer.start();
    var total_tokens: u64 = 0;

    var n: u64 = 0;
    while (n < iterations) : (n += 1) {
        const tokens = try tokenizer.encode(text.items);
        total_tokens += tokens.len;
        allocator.free(tokens);
    }

    const elapsed_ns = timer.read();
    const ns_per_op = elapsed_ns / iterations;
    const tokens_per_sec = if (elapsed_ns > 0)
        @as(f64, @floatFromInt(total_tokens)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0)
    else
        0;

    std.debug.print("Iterations: {d}\n", .{iterations});
    std.debug.print("Input size: {d} bytes\n", .{text.items.len});
    std.debug.print("Total tokens: {d}\n", .{total_tokens});
    std.debug.print("Time per encode: {d} ns\n", .{ns_per_op});
    std.debug.print("Throughput: {d:.0} tokens/sec\n", .{tokens_per_sec});
}
