#!/usr/bin/env bash
#
# One-time setup: install the pmxt engine + MCP server locally and scaffold the
# credentials file.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> Installing pmxt-core, @pmxt/mcp, @pmxt/cli (local to this repo)..."
npm install

if [ ! -f "$ROOT/.env" ]; then
  cp "$ROOT/.env.example" "$ROOT/.env"
  echo "==> Created .env from template. Edit it and add your Kalshi key."
else
  echo "==> .env already exists; leaving it untouched."
fi

cat <<EOF

Setup complete.

Next steps:
  1. Edit .env and fill in KALSHI_API_KEY and KALSHI_PRIVATE_KEY.
  2. Smoke-test the engine against public data:  npm run check
  3. Register the MCP server with OpenClaw using config/openclaw.example.json
     (replace the path with: $ROOT/bin/kalshi-mcp).
  4. Install the skill: copy skills/kalshi-trading into your OpenClaw skills dir.

EOF
