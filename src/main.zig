const std = @import("std");
const Tokenizer = @import("root.zig").Tokenizer;
const cost = @import("cost.zig");

const default_vocab = "fixtures/tokenizer.json";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const raw_args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, raw_args);

    if (raw_args.len < 2) {
        printUsage();
        return;
    }

    const command = raw_args[1];
    var vocab_path: []const u8 = default_vocab;
    var model_name: ?[]const u8 = null;
    var output_tokens: usize = 0;
    var text: ?[]const u8 = null;

    var i: usize = 2;
    while (i < raw_args.len) : (i += 1) {
        const arg = raw_args[i];
        if (std.mem.eql(u8, arg, "--vocab")) {
            i += 1;
            if (i >= raw_args.len) return error.InvalidArgument;
            vocab_path = raw_args[i];
        } else if (std.mem.eql(u8, arg, "--model")) {
            i += 1;
            if (i >= raw_args.len) return error.InvalidArgument;
            model_name = raw_args[i];
        } else if (std.mem.eql(u8, arg, "--output")) {
            i += 1;
            if (i >= raw_args.len) return error.InvalidArgument;
            output_tokens = try std.fmt.parseInt(usize, raw_args[i], 10);
        } else if (text == null) {
            text = arg;
        } else {
            std.debug.print("Unexpected argument: {s}\n", .{arg});
            return error.InvalidArgument;
        }
    }

    if (std.mem.eql(u8, command, "mcp")) {
        try runMcp(allocator, vocab_path);
        return;
    }

    const input = text orelse {
        printUsage();
        return;
    };

    var tokenizer = try Tokenizer.init(allocator, vocab_path);
    defer tokenizer.deinit();

    if (std.mem.eql(u8, command, "count")) {
        const n = try tokenizer.count(input);
        std.debug.print("{d} tokens\n", .{n});
        return;
    }

    if (std.mem.eql(u8, command, "encode")) {
        const tokens = try tokenizer.encode(input);
        defer allocator.free(tokens);

        for (tokens, 0..) |token, idx| {
            if (idx > 0) std.debug.print(", ", .{});
            std.debug.print("{d}", .{token});
        }
        std.debug.print("\n", .{});
        return;
    }

    if (std.mem.eql(u8, command, "cost")) {
        const model = cost.Model.fromName(model_name orelse "gpt4") orelse {
            std.debug.print("Unknown model. Use: gpt4, gpt35, claude_sonnet, claude_opus\n", .{});
            return error.InvalidArgument;
        };

        const input_tokens = try tokenizer.count(input);
        const total = cost.estimateCost(model, input_tokens, output_tokens);

        std.debug.print("Input tokens: {d}\n", .{input_tokens});
        std.debug.print("Output tokens: {d}\n", .{output_tokens});
        std.debug.print("Estimated cost: ${d:.6}\n", .{total});
        return;
    }

    printUsage();
}

fn printUsage() void {
    std.debug.print(
        \\Usage:
        \\  zig-ai-tokenizer count "text" [--vocab fixtures/tokenizer.json]
        \\  zig-ai-tokenizer encode "text" [--vocab fixtures/tokenizer.json]
        \\  zig-ai-tokenizer cost "text" --model gpt4 [--output 500] [--vocab fixtures/tokenizer.json]
        \\  zig-ai-tokenizer mcp [--vocab fixtures/tokenizer.json]
        \\
    , .{});
}

fn runMcp(allocator: std.mem.Allocator, vocab_path: []const u8) !void {
    _ = allocator;
    _ = vocab_path;
    std.debug.print("Use mcp/server.py for Cursor MCP integration.\n", .{});
}
