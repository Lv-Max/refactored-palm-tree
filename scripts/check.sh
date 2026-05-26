#!/usr/bin/env bash
#
# Smoke test: start the local pmxt-core engine and fetch real Kalshi market data
# over its REST surface. Uses only PUBLIC (read-only) endpoints, so no API key is
# required. If this returns markets, the "empty data" problem is gone.
#
# Uses node for HTTP (no curl dependency). Uses a narrow query + retry/backoff so
# a transient upstream 429 (rate limit) doesn't fail the check.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PMXT_LOCAL_PORT:-38470}"
URL="http://127.0.0.1:${PORT}"
QUERY="${PMXT_CHECK_QUERY:-bitcoin}"
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

echo "==> POST $URL/api/kalshi/fetchMarkets  (query=\"$QUERY\", public, no auth)"
node -e '
const [url, query] = process.argv.slice(1);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function attempt() {
  const res = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ args: [{ query, limit: 2 }] }),
  });
  const json = await res.json();
  // pmxt wraps errors as { success:false, error:{ retryable } } even on HTTP 200.
  const retryable = json && json.success === false && json.error && json.error.retryable;
  return { ok: res.ok && json.success !== false, retryable, json };
}

(async () => {
  const backoff = [1000, 2000, 4000, 8000];
  for (let i = 0; i <= backoff.length; i++) {
    let r;
    try { r = await attempt(); }
    catch (e) { r = { ok: false, retryable: true, json: { error: { message: e.message } } }; }
    if (r.ok) {
      const markets = r.json.data || [];
      if (!markets.length) { console.log("Reachable, but no markets for that query. Try PMXT_CHECK_QUERY=..."); process.exit(0); }
      for (const m of markets) console.log("-", m.marketId, "::", m.title);
      console.log("==> Engine works:", markets.length, "live Kalshi markets returned.");
      process.exit(0);
    }
    const msg = (r.json && r.json.error && r.json.error.message) || "unknown error";
    if (r.retryable && i < backoff.length) {
      console.log(`   transient error (${msg}); retrying in ${backoff[i] / 1000}s...`);
      await sleep(backoff[i]);
      continue;
    }
    console.error("Request failed:", msg);
    process.exit(1);
  }
})();
' "$URL/api/kalshi/fetchMarkets" "$QUERY"
