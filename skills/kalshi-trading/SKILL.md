---
name: kalshi-trading
description: >-
  Trade and research Kalshi prediction markets through conversation: search
  markets, read order books and prices, check balance/positions/orders, and
  place or cancel orders. Use when the user wants to look at Kalshi markets, see
  their Kalshi balance or positions, or buy/sell/hedge Kalshi event contracts.
  Backed by the pmxt MCP server (exchange "kalshi" for real money,
  "kalshi-demo" for paper trading).
---

# Kalshi trading

You trade and research Kalshi (a CFTC-regulated event-contract exchange) through
the **pmxt MCP server**, which is registered in OpenClaw as the `kalshi` MCP
server. All Kalshi work goes through that server's tools — you never call Kalshi
HTTP APIs directly and never handle the user's API key.

## The one rule that applies to every tool call

Every pmxt tool takes an **`exchange`** parameter. For this skill it is always
one of:

- `"kalshi"` — **real money**, live exchange.
- `"kalshi-demo"` — paper-trading sandbox (fake money). Use for testing.

Never call a tool without `exchange`. Never silently switch between live and
demo — if you're unsure which the user means, ask.

## Money safety — read before placing any order

Placing or canceling orders spends/moves real money on `kalshi`. Before calling
any **`createOrder`**, **`submitOrder`**, or **`cancelOrder`**:

1. The user must have clearly expressed trading intent ("buy", "sell", "bet",
   "hedge", "cancel", etc.).
2. You must echo back the exact order and get an explicit yes:
   - exchange (`kalshi` = real money, or `kalshi-demo`),
   - market / outcome (human-readable title, not just the ID),
   - side (buy / sell), order type (market / limit),
   - quantity (number of contracts),
   - price (for limit orders) and the estimated cost from `getExecutionPrice`.
3. Only after the user confirms do you call the trading tool.

If the user hasn't named an amount, ask — never guess a size. Default to caution:
if they say "test" or "try it out", use `kalshi-demo`.

## IDs: always discover, never invent

Kalshi identifiers (`marketId`, `outcomeId`) are tickers that change. Never
hardcode or guess them. Always resolve them live with `fetchMarkets` /
`fetchEvents` / `fetchMarket`, then use the IDs those return.

## Prices

pmxt normalizes prices to a **0–1 probability** (e.g. `0.62` ≈ a 62¢ Kalshi
contract; contracts settle at `1` if the event happens, `0` if not). `amount` is
the **number of contracts**. Because conventions matter with real money, always
read the live `fetchOrderBook` / `getExecutionPrice` first and confirm the
human-readable price and estimated cost with the user before ordering.

## Workflows

### Research a market
1. `fetchMarkets { exchange, query, limit }` — search by keyword (e.g. "Fed",
   "Super Bowl"). Use `fetchEvents` to browse groups of related markets.
2. `fetchMarket { exchange, marketId }` — full detail on one market.
3. `fetchOrderBook { exchange, outcomeId }` — current bids/asks.
4. `getExecutionPrice { exchange, outcomeId, side, amount }` — volume-weighted
   price + est. cost for a hypothetical order. This is the preview to show the
   user; it is read-only.
5. `fetchTrades` / `fetchOHLCV` — recent trades and price history.

### Check the account
- `fetchBalance { exchange }` — cash available.
- `fetchPositions { exchange }` — open positions with P&L.
- `fetchOpenOrders { exchange }` / `fetchClosedOrders { exchange }` /
  `fetchAllOrders { exchange }` — order status.
- `fetchMyTrades { exchange }` — your fills.

Always check `fetchBalance` before proposing a buy, so you don't suggest an order
the user can't afford.

### Place an order
1. Resolve the `marketId` / `outcomeId` via `fetchMarkets`.
2. Preview cost with `getExecutionPrice`.
3. Confirm the full order with the user (see "Money safety" above).
4. `createOrder { exchange, marketId, outcomeId, side, type, amount, price }`
   - `type: "market"` executes immediately; `type: "limit"` rests at `price`
     (price is required for limit orders).
   - For a two-step review you can call `buildOrder` (returns the order for
     inspection), show it, then `submitOrder` to execute.
5. Report back the returned order id, fill status, and any fee.

### Cancel an order
1. `fetchOpenOrders { exchange }` to find the order id.
2. Confirm with the user which order.
3. `cancelOrder { exchange, orderId }`.

## When something looks empty or wrong
- A `fetchBalance` / `fetchPositions` call that errors about credentials means
  the local pmxt-core server wasn't started with the Kalshi key — tell the user
  to check their `.env` and that `bin/kalshi-mcp` is the configured launcher.
- Empty market results usually mean the query was too narrow; broaden it or use
  `fetchEvents`.
- Don't paper over a failed trade as success. Report the actual tool error.
