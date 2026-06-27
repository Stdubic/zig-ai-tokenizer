# Cursor Setup

Count tokens and estimate API cost directly from Cursor chat.

## Prerequisites

```bash
git clone https://github.com/Stdubic/zig-ai-tokenizer.git
cd zig-ai-tokenizer
./scripts/fetch-vocab.sh
zig build
```

Requires Zig 0.14+ and Python 3.

## Configure Cursor

Create or edit `~/.cursor/mcp.json`:

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

Replace `/absolute/path/to/zig-ai-tokenizer` with your clone path.

Reload Cursor: **Cmd+Shift+P** → **Developer: Reload Window**

## Verify in Cursor Settings

1. Open **Cursor Settings** → **MCP**
2. Confirm `zig-ai-tokenizer` appears with status **Connected**
3. Two tools should be listed: `count_tokens`, `estimate_cost`

## Example Prompts

Ask Cursor:

```
Use count_tokens to count tokens in: "hello world"
```

Expected result: **2 tokens**

```
Use estimate_cost for this prompt with gpt4 and 500 output tokens:
"Write a Python function for Fibonacci using dynamic programming."
```

Expected result:

```
Input tokens: 16
Output tokens: 500
Estimated cost: $0.030480
```

## Tools

| Tool | Description |
| --- | --- |
| `count_tokens` | Count GPT-2 BPE tokens in text before sending to an LLM |
| `estimate_cost` | Estimate API cost from token count and model pricing |

Supported models: `gpt4`, `gpt35`, `claude_sonnet`, `claude_opus`

## Troubleshooting

**Server not connected**
- Run `zig build` in the repo directory
- Run `./scripts/fetch-vocab.sh` if `fixtures/tokenizer.json` is missing
- Check the `cwd` path in `mcp.json` is absolute and correct

**Empty tool responses**
- Rebuild after pulling latest: `zig build`
- CLI output must go to stdout (fixed in commit `3ddd456`)

**Token counts differ from API billing**
- v1 uses GPT-2 BPE, not cl100k/tiktoken
- Counts are approximate for cost planning, not exact API billing
