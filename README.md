# zig-ai-tokenizer

BPE tokenizer and cost estimator for LLM prompts in Zig.

Count tokens locally before you call an API. Know the cost before you spend.

Uses GPT-2 byte-level BPE via HuggingFace `tokenizer.json`.

## Setup

```bash
./scripts/fetch-vocab.sh
export PATH="/path/to/zig-0.14.1:$PATH"
zig build
zig build test
```

## CLI

```bash
zig build run -- count "hello world"
# 2 tokens

zig build run -- encode "hello world"
# 31373, 995

zig build run -- cost "Your prompt here" --model gpt4 --output 500
# Input tokens: N
# Output tokens: 500
# Estimated cost: $X
```

Models: `gpt4`, `gpt35`, `claude_sonnet`, `claude_opus`

## Benchmark

```bash
zig build bench
```

## Cursor MCP

Count tokens and estimate cost from Cursor chat.

### Setup

1. Build the CLI (see Setup above)
2. Add to `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "zig-ai-tokenizer": {
      "command": "python3",
      "args": ["mcp/server.py"],
      "cwd": "/absolute/path/to/zig-ai-tokenizer"
    }
  }
}
```

3. Reload Cursor: **Cmd+Shift+P** → **Developer: Reload Window**
4. Check **Cursor Settings → MCP** — server should show **Connected**

See [docs/cursor-setup.md](docs/cursor-setup.md) for full guide and example prompts.

### Tools

| Tool | Example prompt |
| --- | --- |
| `count_tokens` | "Use count_tokens on: hello world" → **2 tokens** |
| `estimate_cost` | "Estimate gpt4 cost for this prompt with 500 output tokens" |

Supported models: `gpt4`, `gpt35`, `claude_sonnet`, `claude_opus`

## Notes

- v1 uses GPT-2 BPE vocabulary, not cl100k/tiktoken
- Token counts differ from Claude/GPT-4 API billing until cl100k support lands

## Related

[Token Tracking in Production](https://stdub.org/technical/2026/06/17/Token-Tracking-in-Production.html) on [stdub.org](https://stdub.org)

## License

Apache-2.0

BPE implementation patterns adapted from [alvarobartt/bpe.zig](https://github.com/alvarobartt/bpe.zig) (Apache-2.0).
