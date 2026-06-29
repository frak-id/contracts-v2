# Invariant Map

> Frak Paywall (Reward & Banking) | 17 guards | 11 inferred | 5 not enforced on-chain

---

## 1. Enforced Guards (Reference)

Per-call preconditions. Heading IDs below (`G-N`) are anchor targets from x-ray.md attack surfaces.

#### G-1
`if (_wallet == address(0)) revert InvalidAddress()` · `RewarderHub.sol:160` · Prevents crediting `claimable`/`pendingBalance` to the zero address where funds would become permanently unclaimable.

#### G-2
`if (_amount == 0) revert InvalidAmount()` · `RewarderHub.sol:161` · Rejects no-op reward pushes that would still emit events and waste a `safeTransferFrom`.

#### G-3
`if ($.frozen[_wallet] != 0) revert UserAlreadyFrozen()` · `RewarderHub.sol:234` · Protects the freeze timestamp from being overwritten (which would reset the 60-day recovery clock).

#### G-4
`if ($.frozen[_wallet] == 0) revert UserNotFrozen()` · `RewarderHub.sol:245` · Ensures unfreeze only acts on actually-frozen users; keeps the freeze state machine consistent.

#### G-5
`if (frozenAt == 0) revert UserNotFrozen()` · `RewarderHub.sol:269` · Recovery may only target frozen users — blocks compliance from sweeping arbitrary user balances.

#### G-6
`if (block.timestamp < frozenAt + FREEZE_DURATION) revert FreezePeriodNotElapsed()` · `RewarderHub.sol:270` · Enforces the 60-day cooling-off window before frozen funds can be seized (see I-3).

#### G-7
`if (_recipient == address(0)) revert InvalidAddress()` · `RewarderHub.sol:264` · Prevents recovered/excess funds from being burned to the zero address.

#### G-8
`if ($.frozen[msg.sender] != 0) revert UserIsFrozen()` · `RewarderHub.sol:333` · Core compliance gate: a frozen user cannot withdraw claimable balances (also at `:352` for `claimBatch`).

#### G-9
`if (claimed == 0) revert NothingToClaim()` · `RewarderHub.sol:337` · Rejects empty claims that would emit a misleading `RewardClaimed` event.

#### G-10
`if (excess == 0) revert NothingToWithdraw()` · `RewarderHub.sol:314` · Blocks no-op excess sweeps when contract balance equals tracked pending balance.

#### G-11
`if (_rewarderHub == address(0)) revert InvalidAddress()` · `CampaignBank.sol:91` · One-shot validation that the bank is bound to a real hub at init (see I-4).

#### G-12
`if (!$.isOpen) revert BankIsClosed()` · `CampaignBank.sol:126` · Allowances may only be (re)set while the bank is open (also at `:142`).

#### G-13
`if (_storage().isOpen) revert BankIsStillOpen()` · `CampaignBank.sol:183` · Direct withdrawals are blocked while the bank is open, forcing merchants to close before reclaiming principal.

#### G-14
`if (validatorStorage.mainAuthenticatorIdHash == 0) revert NotInitialized(msg.sender)` · `MultiWebAuthNValidator.sol:106` · Blocks passkey management before the validator is installed for the account (also at `:125`, `:138`).

#### G-15
`if (pubKey.x != 0 || pubKey.y != 0) revert PassKeyAlreadyExist(...)` · `MultiWebAuthNValidator.sol:110` · Prevents overwriting an existing passkey via `addPassKey` (see I-6).

#### G-16
`if (validatorStorage.mainAuthenticatorIdHash == authenticatorId) revert CantRemoveMainPasskey(...)` · `MultiWebAuthNValidator.sol:126` · Guarantees an account can never delete its primary signer and lock itself out (see I-5).

#### G-17
`if (pubKeyX == 0 || pubKeyY == 0) revert InvalidInitData(...)` · `MultiWebAuthNValidator.sol:181` · Rejects degenerate P256 public keys at install (also `setPrimaryPassKey` existence check at `:142`).

---

## 2. Inferred Invariants (Single-Contract)

Inferred invariants are derived from structural analysis. Each cites a Δ-pair, guard-lift, state edge, temporal predicate, or NatSpec claim.

---

#### I-1

`Conservation` · On-chain: **Yes**

> For every token, `pendingBalance[token] == Σ_wallet claimable[wallet][token]`.

**Derivation** — Δ-pair: every write to `claimable` is matched by an equal write to `pendingBalance` in the same body. Credits: `RewarderHub.sol:167↔168` (pushReward), `:211↔(200/221)` (batch). Debits: `:338↔339` (claim), `:363↔364` (claimBatch), `:274↔275` (recoverFrozenFunds). No write site touches one side without the other.

**If violated** — `pendingBalance` would misreport solvency, letting `withdrawExcess` sweep funds still owed to users, or causing claim underflow reverts.

---

#### I-2

`Conservation` · On-chain: **No**

> Contract token balance covers all liabilities: `token.balanceOf(hub) >= pendingBalance[token]`.

**Derivation** — Δ-pair: `pushReward` credits `pendingBalance += _amount` (`:168`) after `safeTransferFrom(_bank, this, _amount)` (`:163`); `claim`/`claimBatch`/`recover` transfer out exactly the decremented amount. Holds for standard ERC20. **Gap**: a fee-on-transfer token delivers `< _amount` while `pendingBalance` is credited the full `_amount` (`:163↔168`), so balance falls below liabilities. Contract NatSpec explicitly declares such tokens unsupported (`RewarderHub.sol:34-43`), but nothing on-chain enforces it.

**If violated** — last claimers cannot be paid; `pendingBalance -= amount` reverts on the underfunded token, stranding rewards.

---

#### I-3

`Temporal` · On-chain: **Yes**

> Frozen funds are seizable only once `block.timestamp >= frozenAt + FREEZE_DURATION` (60 days).

**Derivation** — temporal: `if (block.timestamp < frozenAt + FREEZE_DURATION) revert FreezePeriodNotElapsed()` (`RewarderHub.sol:270`); `frozenAt` written check-then-store in `freezeUser` (`:234↔236`); `FREEZE_DURATION = 60 days` (`:103`).

**If violated** — compliance could seize user balances instantly with no appeal window.

---

#### I-4

`StateMachine` · On-chain: **Yes**

> A `CampaignBank`'s `rewarderHub` is set exactly once and never changes.

**Derivation** — edge: `rewarderHub == address(0)` at clone → concrete in `init` (`CampaignBank.sol:96`) guarded by `initializer`; no other write site for `rewarderHub` exists in the contract.

**If violated** — a mutable hub pointer would let allowances/pulls be redirected to an attacker-controlled spender.

---

#### I-5

`StateMachine` · On-chain: **Yes**

> An installed validator's `mainAuthenticatorIdHash` always references an existing public key (account cannot be locked out).

**Derivation** — edge: `setPrimaryPassKey` requires the target pubkey exist (`MultiWebAuthNValidator.sol:142`) before reassigning main (`:148`); `removePassKey` reverts on the main id (`:126`); `enable` sets main and its pubkey atomically (`:198-200`).

**If violated** — an account could point `main` at an empty/deleted key, bricking `validateUserOp`.

---

#### I-6

`StateMachine` · On-chain: **Yes**

> Each `(account, authenticatorId)` pubkey is write-once via `addPassKey` until explicitly removed.

**Derivation** — edge: `addPassKey` reverts if `pubKey.x != 0 || pubKey.y != 0` (`MultiWebAuthNValidator.sol:110`) then sets x/y (`:114-115`); cleared only by `removePassKey` `delete` (`:130`).

**If violated** — a silent key overwrite would let a stale/compromised authenticator be swapped without an explicit removal event.

---

#### I-7

`Conservation` · On-chain: **No**

> Native-ETH excess withdrawal is untracked: `withdrawExcess(address(0))` sends the full contract ETH balance.

**Derivation** — Conservation-negative: the `address(0)` branch sets `excess = address(this).balance` with no `pendingBalance` accounting (`RewarderHub.sol:303-304`), unlike the ERC20 branch (`:306-308`). No storage tracks native liabilities because rewards are ERC20-only.

**If violated** — N/A as designed (no native rewards), but any ETH forced into the contract is fully extractable by COMPLIANCE_ROLE — worth confirming no flow credits native claims.

---

#### I-8

`Bound` · On-chain: **Yes**

> Allowance writes only occur while `isOpen == true` (normal path); revokes (set-to-0) occur in any state.

**Derivation** — guard-lift: both non-zero allowance write sites enforce `!isOpen → revert` (`CampaignBank.sol:126`, `:142`); the only unguarded `safeApprove` write sites set the value to `0` (`revokeAllowance:205`, `revokeAllowances:215`), which cannot increase outflow capacity.

**If violated** — a closed bank could re-arm an allowance, contradicting the "closed = withdrawals only" model.

---

#### I-9

`StateMachine` · On-chain: **No**

> `CampaignBank.isOpen` is a togglable flag, NOT a monotonic latch.

**Derivation** — edge with reverse path: `setOpen(true)` and `setOpen(false)` both write `isOpen` (`CampaignBank.sol:108`) with no one-way constraint. Recorded as a non-invariant: any logic assuming "closed stays closed" is unsound.

**If violated** — N/A (documented behavior); flagged so auditors do not treat `isOpen` as a one-shot kill switch.

---

#### I-10

`StateMachine` · On-chain: **No**

> `frozen[wallet]` is togglable (freeze ⇄ unfreeze), not a one-shot.

**Derivation** — edge with reverse path: `freezeUser` sets `frozen = block.timestamp` (`:236`), `unfreezeUser` resets to `0` (`:247`). A re-freeze restarts the 60-day clock (I-3), so recovery eligibility is not monotonic.

**If violated** — N/A (documented); noted because repeated freeze/unfreeze can indefinitely defer or reset recovery timing.

---

#### I-11

`Conservation` · On-chain: **Yes**

> `batch` chunk aggregation conserves: Σ per-op `claimable` credits == Σ chunk `safeTransferFrom` amounts == Σ `pendingBalance` increments.

**Derivation** — Δ-pair across the loop: per-op `claimable[wallet] += op.amount` (`:211`) accumulates into `pendingAmount`; each chunk boundary and the tail transfer `safeTransferFrom(..., pendingAmount)` (`:199`, `:220`) with matching `pendingBalance += pendingAmount` (`:200`, `:221`). Aggregation key is `(bank, token)`.

**If violated** — mis-chunking would transfer a different total than credited, breaking I-1/I-2.

**Categories:** Conservation · Bound · Ratio · StateMachine · Temporal.

---

## 3. Inferred Invariants (Cross-Contract)

---

#### X-1

On-chain: **No**

> `RewarderHub` assumes each `CampaignBank` has an allowance ≥ pulled amount and sufficient token balance.

**Caller side** — `RewarderHub.sol:163` / `:199` / `:220` — `currentToken.safeTransferFrom(bank, address(this), amount)` pulls from a caller-supplied `bank` with no pre-check of allowance or balance.

**Callee side** — `CampaignBank.sol:205` / `:215` (`revokeAllowance`/`revokeAllowances`, owner, any state) and `:186` (`withdraw`, when closed) can independently reduce allowance/balance.

**If violated** — `pushReward`/`batch` reverts; a single underfunded op reverts an entire batch (no per-op try/catch).

---

#### X-2

On-chain: **No**

> Bank `isOpen == false` does NOT stop the hub from pulling funds via a still-live allowance.

**Caller side** — `RewarderHub.sol:163` — pull path never reads bank `isOpen`.

**Callee side** — `CampaignBank.sol:108` — `setOpen(false)` writes only `isOpen`; it does not touch ERC20 approvals. Documented at `CampaignBank.sol:64-67`.

**If violated** — a merchant believing "closed" halts outflow is wrong; only `revokeAllowance` stops pulls. By-design but a confirmed footgun.

---

## 4. Economic Invariants

---

#### E-1

On-chain: **No**

> Every credited reward is fully claimable (protocol stays solvent per token).

**Follows from** — I-1 + I-2 (+ X-1).

**If violated** — with standard ERC20 the hub always holds ≥ liabilities (funds are pulled in at credit time), so all claims succeed. The chain breaks only through I-2's fee-on-transfer gap or an out-of-band balance reduction — both make late claimers insolvent.

---

#### E-2

On-chain: **Yes**

> Excess withdrawal can never reduce balance below liabilities for ERC20 tokens.

**Follows from** — I-1 + I-2.

**If violated** — `withdrawExcess` computes `excess = balance - pendingBalance` and only the positive remainder is sent (`RewarderHub.sol:308`), so tracked liabilities are preserved (subject to I-2's token-standard assumption).
