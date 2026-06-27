#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURES="$ROOT/fixtures"
URL="https://huggingface.co/openai-community/gpt2/resolve/main/tokenizer.json"

mkdir -p "$FIXTURES"

if [[ -f "$FIXTURES/tokenizer.json" ]]; then
  echo "Fixture already present: $FIXTURES/tokenizer.json"
  exit 0
fi

echo "Downloading GPT-2 tokenizer.json..."
curl -L "$URL" -o "$FIXTURES/tokenizer.json"
echo "Saved to $FIXTURES/tokenizer.json"
