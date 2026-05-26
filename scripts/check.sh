#!/usr/bin/env bash
#
# Smoke test: start the local pmxt-core engine and fetch real Kalshi market data
# over its REST surface. Uses only PUBLIC (read-only) endpoints, so no API key is
# required. If this returns markets, the "empty data" problem is gone.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PMXT_LOCAL_PORT:-38470}"
URL="http://127.0.0.1:${PORT}"
export PMXT_LOCAL_PORT="$PORT"

[ -d "$ROOT/node_modules/pmxt-core" ] || { echo "Run 'npm run setup' first." >&2; exit 1; }

if ! curl -fsS "$URL/health" >/dev/null 2>&1; then
  echo "==> Starting local pmxt-core engine on $URL ..."
  node "$ROOT/bin/pmxt-local-server.js" &
  SERVER_PID=$!
  trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT
  for _ in $(seq 1 50); do curl -fsS "$URL/health" >/dev/null 2>&1 && break; sleep 0.2; done
fi

echo "==> POST $URL/api/kalshi/fetchMarkets  (public, no auth)"
curl -fsS -X POST "$URL/api/kalshi/fetchMarkets" \
  -H 'content-type: application/json' \
  -d '{"args":[{"limit":3}]}' \
  | head -c 2000
echo
echo "==> If you saw market objects above, the engine works."
