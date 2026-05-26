# Agent guide

This repo gives you (the OpenClaw agent) the ability to **research and trade
Kalshi prediction markets through conversation**. Read this first; it tells you
what's here and how to get it working. The actual trading rules live in
[`skills/kalshi-trading/SKILL.md`](skills/kalshi-trading/SKILL.md) — follow that
whenever the user wants to look at Kalshi markets, check their balance/positions,
or buy/sell/hedge.

## What provides the capability

A pmxt-backed MCP server, registered in OpenClaw as the **`kalshi`** MCP server.
Its tools (e.g. `fetchMarkets`, `fetchBalance`, `createOrder`) are how you
interact with Kalshi. You never call Kalshi HTTP APIs directly and you never see
or handle the user's API key.

## Before you can trade: check setup

If the `kalshi` MCP tools aren't available, or a tool errors about credentials
or connection, the environment isn't set up yet. Determine the state and act:

1. **Dependencies installed?** If `node_modules/` is missing, this is an
   operator task — run `npm run setup` (installs the pmxt packages and scaffolds
   `.env`), or tell the user to.
2. **Credentials present?** Trading and account tools need `.env` filled with
   `KALSHI_API_KEY` and `KALSHI_PRIVATE_KEY`. If `.env` is missing or still has
   placeholder values, **stop and ask the user to fill it in** (see
   `.env.example`). You cannot and should not supply the key yourself — it stays
   on the machine, never in your context.
3. **MCP server registered?** The `kalshi` server must be in the user's
   `openclaw.json`, pointing at the absolute path of `bin/kalshi-mcp` (see
   `config/openclaw.example.json`). If it isn't, point the user to README.md.
4. **Sanity check (read-only, no key needed):** `npm run check` fetches live
   Kalshi markets. If that returns markets, the engine works.

Public/read-only market data works without a key; **balance, positions, and
placing/canceling orders require the key in `.env`.**

## The one rule for every tool call

Every `kalshi` MCP tool takes an `exchange` argument:

- `"kalshi"` — **real money**.
- `"kalshi-demo"` — paper-trading sandbox (fake money), for testing.

Never omit it. Never silently switch between live and demo — if unsure, ask.

## Money safety (also in SKILL.md)

Before any `createOrder` / `submitOrder` / `cancelOrder`: echo the full order
back (exchange, market/outcome by name, side, type, quantity, price, estimated
cost from `getExecutionPrice`) and get an explicit yes. Never guess a size. When
the user says "test"/"try", use `kalshi-demo`. There is no API for a Kalshi-style
trade-confirmation image — report fills as a clear text summary.

## What you can and can't do

You have the **core trading** surface: search markets/events, order book and
prices, balance, positions, open/closed orders, fills, and place/cancel orders.
You do **not** have order amend, batch orders, RFQ/block trades, subaccounts,
dedicated settlements, or live streaming — see the full matrix in README.md. If
a user asks for one of those, say it's out of scope here rather than improvising.
