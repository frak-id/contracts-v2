# Property Implementation Plan

Generated for the Frak Paywall reward/banking value flow. Spec IDs are stable and mirror `PROPERTIES.md`.

## Global properties (Properties.sol, public `property_*`)

| Spec ID | Property | Location | Guarantee | Priority | Source |
|---|---|---|---|---|---|
| GL-01 | `pendingBalance[t] == Σ_actors claimable[a][t]` | `property_pendingEqualsSumClaimable` | SHOULD-HOLD | HIGH | x-ray I-1 |
| GL-02 | `balanceOf(hub) >= pendingBalance[t]` | `property_hubSolvent` | SHOULD-HOLD | HIGH | x-ray I-2/E-1/E-2 |

## Specific properties (Properties.sol internal `_prop_*`, wired in handlers)

| Spec ID | Property | Wired in | Guarantee | Priority | Source |
|---|---|---|---|---|---|
| SP-01 | claim zeroes claimable & pays exact amount | `rewarderHub_claim_clamped` → `_prop_claimSettles` | SHOULD-HOLD | MEDIUM | x-ray claim Δ-pair |

## Harness invariant-soundness decisions

- All reward credits (`pushReward`, `batch`) remap the recipient wallet to the bounded actor set
  (`toActor`) in the unclamped layer, so GL-01's per-token sum is fully enumerable.
- Reward tokens are standard ERC20 (mUSD + a MockERC20), matching the contract's documented
  "standard ERC20 only" policy, so GL-02 is a true SHOULD-HOLD (no fee-on-transfer/rebasing).

## Summary

Generated 3 properties (2 HIGH, 1 MEDIUM; 3 SHOULD-HOLD, 0 EXPLORATORY).
