# Tab Reorder & Transitions — Design

**Date:** 2026-10-05 · **Status:** Approved

## Goal
Default the app to Accounts; order tabs Accounts → Ledger → Stats → Days; add
silky directional slide transitions between tabs and a launch entrance animation.

## Changes (DayDelta/DayDeltaApp.swift only; pure UI)
- Tab indices: 0 Accounts (default), 1 Ledger, 2 Stats, 3 Days. Bottom bar order
  Accounts, Ledger, (center Add only on Ledger), Stats, Days.
- `content` switch maps indices to AccountsView / LedgerView / StatsView / ContentView.
- Directional slide: track `prevTab`; `.id(tab)` + asymmetric `.move` transition
  whose edge follows the index delta (forward → in from trailing / out leading),
  combined with opacity, under the existing `.bouncy` tab animation.
- Launch entrance: `appeared` flag flips in `.task` with `.smooth`, fading +
  scaling the whole UI in once on open.

## Testing
UI-only; verify via Xcode build + simulator (opens on Accounts; tab switches
slide directionally; entrance plays on launch). Existing logic tests unaffected.
