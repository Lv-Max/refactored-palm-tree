#!/usr/bin/env bash
#
# Smoke test: start the local pmxt-core engine and fetch real Kalshi market data
# over its REST surface. Uses only PUBLIC (read-only) endpoints, so no API key is
# required. If this returns markets, the "empty data" problem is gone.
#
# Uses node for HTTP (no curl dependency — node is always present here).
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PMXT_LOCAL_PORT:-38470}"
URL="http://127.0.0.1:${PORT}"
export PMXT_LOCAL_PORT="$PORT"

[ -d "$ROOT/node_modules/pmxt-core" ] || { echo "Run 'npm run setup' first." >&2; exit 1; }

health() {
  node -e 'fetch(process.argv[1]).then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))' "$URL/health" >/dev/null 2>&1
}

if ! health; then
  echo "==> Starting local pmxt-core engine on $URL ..."
  node "$ROOT/bin/pmxt-local-server.js" &
  SERVER_PID=$!
  trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT
  for _ in $(seq 1 50); do health && break; sleep 0.2; done
fi

echo "==> POST $URL/api/kalshi/fetchMarkets  (public, no auth)"
node -e '
const url = process.argv[1];
fetch(url, {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify({ args: [{ limit: 3 }] }),
})
  .then((r) => r.json())
  .then((j) => {
    const markets = j.data || [];
    if (!markets.length) { console.log("No markets returned:", JSON.stringify(j).slice(0, 300)); process.exit(1); }
    for (const m of markets) console.log("-", m.marketId, "::", m.title);
    console.log("==> Engine works:", markets.length, "live Kalshi markets returned.");
  })
  .catch((e) => { console.error("Request failed:", e.message); process.exit(1); });
' "$URL/api/kalshi/fetchMarkets"
