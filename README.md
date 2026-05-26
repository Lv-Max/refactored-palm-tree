# OpenClaw × Kalshi (via pmxt)

Conversational Kalshi trading for OpenClaw, built on the
[**pmxt**](https://github.com/pmxt-dev/pmxt) prediction-market engine instead of
a hand-maintained CLI.

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
   └── ensures ──────────►  pmxt-core server  (localhost:3847)
                                  │  signed RSA requests
                                  ▼
                              Kalshi API
```

- **`pmxt-core`** runs locally on `:3847` and makes the real, RSA-signed calls
  to Kalshi. It reads your key from `KALSHI_API_KEY` / `KALSHI_PRIVATE_KEY`.
- **`@pmxt/mcp`** is the official MCP server. In local mode (no `PMXT_API_KEY`)
  it just forwards tool calls to `pmxt-core`.
- **`bin/kalshi-mcp`** is the single command OpenClaw spawns. It loads `.env`,
  ensures `pmxt-core` is up, and hands stdio to `@pmxt/mcp`.

### Security posture

Your Kalshi RSA private key lives only in the local, gitignored `.env` and is
read only by the local `pmxt-core` server. It is **never** passed in MCP tool
calls, so it never enters the agent / LLM context, and **nothing is sent to
pmxt.dev** — local mode talks only to `localhost:3847`.

## Setup

```bash
npm run setup          # installs pmxt-core + @pmxt/mcp + @pmxt/cli, creates .env
$EDITOR .env           # fill in KALSHI_API_KEY and KALSHI_PRIVATE_KEY
npm run check          # smoke test: fetches real Kalshi markets (public, no key)
```

Then register the MCP server with OpenClaw. Add to your `openclaw.json` (see
`config/openclaw.example.json`), using the absolute path to `bin/kalshi-mcp`:

```json
{
  "mcpServers": {
    "kalshi": { "command": "/abs/path/to/refactored-palm-tree/bin/kalshi-mcp", "args": [] }
  }
}
```

Finally, install the skill: copy `skills/kalshi-trading/` into your OpenClaw
skills directory. The skill teaches the agent the tool catalog, the
real-money-vs-demo distinction, and the confirm-before-trading workflow.

## Credentials

Create a key in the Kalshi web UI (Account → Profile → API Keys). You get a Key
ID and a one-time RSA private-key download. Put both in `.env` — the private key
as a single line with literal `\n` between lines (see `.env.example`).

- `exchange: "kalshi"` → real money (`api.elections.kalshi.com`).
- `exchange: "kalshi-demo"` → paper trading (`demo-api.kalshi.co`), which needs a
  **separate** demo-account key.

## Keeping pmxt current

```bash
npm run update:pmxt    # bumps pmxt-core, @pmxt/mcp, @pmxt/cli together
```

Because the trading logic lives in pmxt, updating these packages is how you pick
up Kalshi API changes — no edits to this repo required.

## What's covered

Core trading: search markets/events, order book, prices, balance, positions,
open/closed orders, fills, place/cancel orders, order status. The
Kalshi-specific extras kalshi-cli had (RFQ/block trades, subaccounts,
settlements, order amend, batch-create, live WebSocket streaming, candlestick
charts) are **not** exposed by pmxt's unified API and are out of scope here.

## Layout

```
bin/kalshi-mcp              launcher OpenClaw spawns as the "kalshi" MCP server
skills/kalshi-trading/      the OpenClaw skill (SKILL.md)
config/openclaw.example.json  MCP registration snippet
scripts/setup.sh            install + scaffold
scripts/check.sh            public-data smoke test
.env.example                credentials template
```
