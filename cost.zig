const std = @import("std");

pub const Model = enum {
    gpt4,
    gpt35,
    claude_sonnet,
    claude_opus,

    pub fn inputPricePerMillion(self: Model) f64 {
        return switch (self) {
            .gpt4 => 30.0,
            .gpt35 => 1.5,
            .claude_sonnet => 3.0,
            .claude_opus => 15.0,
        };
    }

    pub fn outputPricePerMillion(self: Model) f64 {
        return switch (self) {
            .gpt4 => 60.0,
            .gpt35 => 2.0,
            .claude_sonnet => 15.0,
            .claude_opus => 75.0,
        };
    }

    pub fn fromName(name: []const u8) ?Model {
        if (std.ascii.eqlIgnoreCase(name, "gpt4") or std.mem.eql(u8, name, "gpt-4")) return .gpt4;
        if (std.ascii.eqlIgnoreCase(name, "gpt35") or std.mem.eql(u8, name, "gpt-3.5")) return .gpt35;
        if (std.ascii.eqlIgnoreCase(name, "claude_sonnet") or std.mem.eql(u8, name, "claude-sonnet")) return .claude_sonnet;
        if (std.ascii.eqlIgnoreCase(name, "claude_opus") or std.mem.eql(u8, name, "claude-opus")) return .claude_opus;
        return null;
    }
};

pub fn estimateCost(model: Model, input_tokens: usize, output_tokens: usize) f64 {
    const input_cost = @as(f64, @floatFromInt(input_tokens)) / 1_000_000.0 * model.inputPricePerMillion();
    const output_cost = @as(f64, @floatFromInt(output_tokens)) / 1_000_000.0 * model.outputPricePerMillion();
    return input_cost + output_cost;
}

test "estimateCost for gpt4" {
    const cost = estimateCost(.gpt4, 1000, 500);
    try std.testing.expectApproxEqAbs(@as(f64, 0.06), cost, 0.0001);
}
