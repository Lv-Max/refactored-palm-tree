# OpenClaw × Kalshi (via pmxt)

Conversational Kalshi trading for OpenClaw, built on the
[**pmxt**](https://github.com/pmxt-dev/pmxt) prediction-market engine instead of
a hand-maintained CLI.

> **Two audiences, two docs.**
> - **This file (README.md) is for the human/operator** setting the repo up.
> - **[AGENTS.md](AGENTS.md) is for the agent** (OpenClaw) — it tells the agent
>   what the repo is, how to check it's set up, and where the trading skill
>   lives. The runtime trading rules are in
>   [`skills/kalshi-trading/SKILL.md`](skills/kalshi-trading/SKILL.md).

## Why this instead of kalshi-cli

The previous setup (`openclaw-kalshi-trading-skill` → `6missedcalls/kalshi-cli`)
broke when Kalshi changed its API — some commands returned empty data, and
keeping the CLI current was on us.

pmxt is a unified, **very actively maintained** prediction-market API (multiple
releases per day). It absorbs Kalshi API changes upstream, so we don't track
them. It also already ships the agent interface we need — an official MCP
server — so there is **no custom CLI to build or maintain here**. We only
provide a launcher, a credentials template, and the OpenClaw skill.

## How it works

```
OpenClaw agent
   │  (MCP tool calls: fetchMarkets, createOrder, ...)
   ▼
bin/kalshi-mcp  ──spawns──►  @pmxt/mcp  (official, stdio, local mode)
   │                              │  POST /api/kalshi/<method>
   │                              ▼
   └── ensures ──────────►  pmxt-core engine  (127.0.0.1, loopback only)
                                  │  signed RSA requests
                                  ▼
                              Kalshi API
```

- **`pmxt-core`** runs locally and makes the real, RSA-signed calls to Kalshi.
  It reads your key from `KALSHI_API_KEY` / `KALSHI_PRIVATE_KEY`.
- **`@pmxt/mcp`** is the official MCP server. In local mode (no `PMXT_API_KEY`)
  it forwards tool calls to the local engine.
- **`bin/kalshi-mcp`** is the single command OpenClaw spawns. It loads `.env`,
  ensures the engine is up, and hands stdio to `@pmxt/mcp`.

### Why we boot the engine ourselves

`@pmxt/mcp`'s "local mode" sends an `Authorization: Bearer` header, but the
stock `pmxt-server` requires an `x-pmxt-access-token` header — so they don't
talk to each other out of the box (you get a 401). `bin/pmxt-local-server.js`
starts the same pmxt-core engine **without an access token, bound to 127.0.0.1
only**, which the official MCP server can reach. All Kalshi logic still lives in
pmxt-core, so upstream updates still flow through.

### Security posture

Your Kalshi RSA private key lives only in the local, gitignored `.env` and is
read only by the local engine. It is **never** passed in MCP tool calls, so it
never enters the agent / LLM context, and **nothing is sent to pmxt.dev** —
local mode talks only to `127.0.0.1`. The engine has no auth token because it
binds to loopback only; on a shared/multi-user host, front it with an
authenticating proxy.

## Setup (operator)

Handing over the repo is **setup + 3 short operator steps** — it is not fully
drop-and-go, by design: your Kalshi key must be entered by you (it never touches
the agent), and the MCP server must be registered with OpenClaw before the tools
exist. After that, conversational trading works and the agent follows
[AGENTS.md](AGENTS.md) / the skill.

```bash
npm run setup          # installs pmxt-core + @pmxt/mcp + @pmxt/cli, creates .env
$EDITOR .env           # fill in KALSHI_API_KEY and KALSHI_PRIVATE_KEY
npm run check          # smoke test: fetches real Kalshi markets (public, no key)
```

Then register the MCP server with OpenClaw. Add to your `openclaw.json` (see
`config/openclaw.example.json`), using the **absolute** path to `bin/kalshi-mcp`:

```json
{
  "mcpServers": {
    "kalshi": { "command": "/abs/path/to/refactored-palm-tree/bin/kalshi-mcp", "args": [] }
  }
}
```

Finally, install the skill: copy `skills/kalshi-trading/` into your OpenClaw
skills directory.

## Credentials

Create a key in the Kalshi web UI (Account → Profile → API Keys). You get a Key
ID and a one-time RSA private-key download. Put both in `.env` — the private key
as a single line with literal `\n` between lines (see `.env.example`).

- `exchange: "kalshi"` → real money (`api.elections.kalshi.com`).
- `exchange: "kalshi-demo"` → paper trading (`demo-api.kalshi.co`), which needs a
  **separate** demo-account key.

## Feature status

Verified working end-to-end (launcher → `@pmxt/mcp` → local engine returns live
Kalshi data). All tools take an `exchange` of `"kalshi"` (real) or
`"kalshi-demo"` (paper).

### Implemented (core Kalshi trading)

| Area | Tools |
|------|-------|
| Market discovery | `fetchMarkets`, `fetchMarketsPaginated`, `fetchMarket`, `fetchEvents`, `fetchEventsPaginated`, `fetchEvent`, `fetchRelatedMarkets`, `loadMarkets` |
| Prices / book / history | `fetchOrderBook`, `fetchOrderBooks`, `fetchTrades`, `fetchOHLCV` (candle data), `getExecutionPrice`, `getExecutionPriceDetailed` |
| Account | `fetchBalance`, `fetchPositions`, `fetchOpenOrders`, `fetchClosedOrders`, `fetchAllOrders`, `fetchOrder`, `fetchMyTrades` |
| Trading | `buildOrder`, `createOrder`, `submitOrder`, `cancelOrder` |

YES/NO is handled via the outcome you trade (buy the YES outcome vs. the NO
outcome); market and limit orders are both supported.

### Available but cross-venue / may need hosted mode

`compareMarketPrices`, `fetchArbitrage`, `fetchHedges`, `fetchMatchedMarkets`,
`fetchMatchedPrices`, `fetchMarketMatches`, `fetchEventMatches` — these compare
across venues and are not needed for single-venue Kalshi trading. Some require
pmxt's hosted/enterprise router.

### Not available (kalshi-cli had these; pmxt's unified API does not)

| Feature | Status / workaround |
|---------|--------------------|
| Order amend (change price/qty) | Not exposed → `cancelOrder` then `createOrder` |
| Batch create / order groups | Not exposed → place orders one by one |
| Order queue position | Not exposed |
| RFQ / block trades (quotes) | Not exposed |
| Subaccounts (list/create/transfer) | Not exposed |
| Settlements history | Not a dedicated tool; `fetchClosedOrders` / `fetchPositions` cover resolved orders/positions |
| Live WebSocket streaming (watch) | Not exposed via MCP (streaming methods are skipped) |
| ASCII candlestick charts | Raw candles available via `fetchOHLCV`; chart rendering is up to the client |
| Trade-confirmation share image | **No Kalshi/pmxt API for this.** Order results are reported as text |

If you later need the not-available items, keep `6missedcalls/kalshi-cli`
around for just those Kalshi-specific operations.

## Troubleshooting

- **`Exchange unreachable: self-signed certificate in certificate chain`** — the
  host routes outbound traffic through a TLS-intercepting proxy. Point Node at
  the proxy's CA bundle in the same environment that launches `bin/kalshi-mcp`:
  `export NODE_EXTRA_CA_CERTS=/path/to/ca-bundle.crt`. Do **not** use
  `NODE_TLS_REJECT_UNAUTHORIZED=0` for real-money trading. (Normal hosts with
  clean egress are unaffected.)
- **`kalshi` tools don't appear in OpenClaw** — the MCP server isn't registered,
  or OpenClaw wasn't reloaded after editing `openclaw.json`.
- **Balance/positions/orders error about credentials** — `.env` is missing or
  still has placeholder values; public market data works without a key, trading
  does not.
- **`429` / `Exchange unreachable ... retryable`** — a transient Kalshi rate
  limit. `npm run check` already uses a narrow query and retries with backoff.
  In normal use, retry the tool call after a short wait rather than treating it
  as a hard failure.

## Dependency audit

`npm audit` reports ~21 advisories (low/moderate). They are all inside the
blockchain/Solana wallet SDKs that pmxt-core bundles for **other** venues
(`ethers`/`@ethersproject/*`, `@solana/web3.js`, `@polymarket/clob-client`,
`@limitless-exchange/sdk`) — **none are on the Kalshi path**, which uses RSA
signing + HTTP only. Do **not** run `npm audit fix --force`: its only
"fix" downgrades pmxt-core to a 1.x major and throws away the API-drift
handling. These clear as pmxt updates its dependencies upstream — pick that up
with `npm run update:pmxt`.

## Keeping pmxt current

```bash
npm run update:pmxt    # bumps pmxt-core, @pmxt/mcp, @pmxt/cli together
```

Updating these packages is how you pick up Kalshi API changes — no edits to this
repo required.

## Layout

```
README.md                   this file — operator setup
AGENTS.md                   agent entrypoint — what OpenClaw should do
skills/kalshi-trading/      the OpenClaw skill (SKILL.md) — runtime trading rules
bin/kalshi-mcp              launcher OpenClaw spawns as the "kalshi" MCP server
bin/pmxt-local-server.js    boots the local pmxt-core engine (token-free, loopback)
config/openclaw.example.json  MCP registration snippet
scripts/setup.sh            install + scaffold
scripts/check.sh            public-data smoke test
.env.example                credentials template
```
