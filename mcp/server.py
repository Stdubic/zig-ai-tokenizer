#!/usr/bin/env python3
"""Minimal MCP server for Cursor. Wraps the zig-ai-tokenizer CLI."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BINARY = ROOT / "zig-out" / "bin" / "zig-ai-tokenizer"
VOCAB = ROOT / "fixtures" / "tokenizer.json"


def run_cli(args: list[str]) -> str:
    cmd = [str(BINARY), *args, "--vocab", str(VOCAB)]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    return result.stdout.strip()


def send(message: dict) -> None:
    sys.stdout.write(json.dumps(message) + "\n")
    sys.stdout.flush()


def handle_request(request: dict) -> None:
    method = request.get("method")
    req_id = request.get("id")

    if method == "initialize":
        send({
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "zig-ai-tokenizer", "version": "0.1.0"},
            },
        })
        return

    if method == "notifications/initialized":
        return

    if method == "tools/list":
        send({
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "tools": [
                    {
                        "name": "count_tokens",
                        "description": "Count GPT-2 BPE tokens in text before sending to an LLM API",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "text": {"type": "string"},
                            },
                            "required": ["text"],
                        },
                    },
                    {
                        "name": "estimate_cost",
                        "description": "Estimate API cost from token count and model pricing",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "text": {"type": "string"},
                                "model": {"type": "string", "default": "gpt4"},
                                "output_tokens": {"type": "integer", "default": 500},
                            },
                            "required": ["text"],
                        },
                    },
                ],
            },
        })
        return

    if method == "tools/call":
        params = request.get("params", {})
        name = params.get("name")
        arguments = params.get("arguments", {})

        try:
            if name == "count_tokens":
                text = arguments["text"]
                output = run_cli(["count", text])
                content = [{"type": "text", "text": output}]
            elif name == "estimate_cost":
                text = arguments["text"]
                model = arguments.get("model", "gpt4")
                output_tokens = str(arguments.get("output_tokens", 500))
                output = run_cli(["cost", text, "--model", model, "--output", output_tokens])
                content = [{"type": "text", "text": output}]
            else:
                raise ValueError(f"Unknown tool: {name}")

            send({
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {"content": content, "isError": False},
            })
        except Exception as exc:  # noqa: BLE001
            send({
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {
                    "content": [{"type": "text", "text": str(exc)}],
                    "isError": True,
                },
            })
        return

    if req_id is not None:
        send({
            "jsonrpc": "2.0",
            "id": req_id,
            "error": {"code": -32601, "message": f"Method not found: {method}"},
        })


def main() -> None:
    if not BINARY.exists():
        raise SystemExit(f"Build the CLI first: zig build (expected {BINARY})")
    if not VOCAB.exists():
        raise SystemExit(f"Download vocab first: ./scripts/fetch-vocab.sh")

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        handle_request(json.loads(line))


if __name__ == "__main__":
    main()
