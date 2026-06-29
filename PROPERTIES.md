# Fuzz Properties — Frak Paywall

Stateful invariants implemented in the `test/fizz` suite. Each carries a **Guarantee** tag:
`SHOULD-HOLD` (a documented/mathematical guarantee — a violation is a confirmed bug) or
`EXPLORATORY` (inferred — a violation is a lead for human review).

## Global properties (always hold, checked by the fuzzer every step)

- [x] **GL-01** `pendingBalance[token] == Σ_wallet claimable[wallet][token]` for every reward token.
  Conservation: every `claimable` write in `RewarderHub` is matched 1:1 by a `pendingBalance`
  write (`pushReward`, `batch`, `claim`, `claimBatch`, `recoverFrozenFunds`). All reward credits
  are bounded to the actor set by the harness, so the sum is enumerable.
  `property_pendingEqualsSumClaimable` — **SHOULD-HOLD** (exact accounting identity, x-ray I-1).

- [x] **GL-02** `token.balanceOf(hub) >= pendingBalance[token]` for every reward token.
  Solvency: funds are pulled into the hub at credit time, so the hub always custodies at least
  its tracked liabilities. `property_hubSolvent` — **SHOULD-HOLD** for standard ERC20s
  (x-ray I-2 / E-1 / E-2). Both harness reward tokens are standard (no fee-on-transfer/rebasing).

## Specific properties (checked after the relevant action)

- [x] **SP-01** After a successful `claim(token)`: the caller's `claimable[token]` is `0` and the
  caller's token balance increased by exactly the previously-claimable amount.
  `_prop_claimSettles`, asserted in `rewarderHub_claim_clamped` — **SHOULD-HOLD** (x-ray claim Δ-pair).

## Notes / not implemented as fuzz assertions

- **I-3** (60-day freeze window), **I-4** (one-shot `rewarderHub` bind), **I-5/I-6** (passkey state
  machine) are enforced by on-chain guards and are exercised by handlers, but are not expressed as
  standalone global assertions (guard-enforced, low marginal signal).
- **I-2 fee-on-transfer gap / I-7 native-ETH `withdrawExcess`**: out of harness scope — the suite
  uses standard ERC20 reward tokens only, matching the contract's documented token policy.
- WebAuthn / kernel validators excluded from the fuzz scope (see `fizz_data/coverage-targets.md`).
