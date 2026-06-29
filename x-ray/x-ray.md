# X-Ray Report

> Frak Paywall (Reward & Banking) | ~789 nSLOC | 823fa3b (`chore/fizz`) | Foundry | 29/06/26

> Analyzed branch: `chore/fizz` at `823fa3b`. nSLOC is an estimate (~789) — enumerate.sh's `grep -P` nSLOC step is unsupported on this BSD/macOS host.

---

## 1. Protocol Overview

**What it does:** A custodial reward-distribution system where merchants fund per-merchant escrow banks, a backend role pushes rewards into a central hub, and users claim ERC20 rewards — plus a set of ERC-4337 WebAuthn (passkey) signature validators for Kernel v2 smart wallets.

- **Users**: Merchants (fund banks), a Frak rewarder backend (pushes rewards), a compliance operator (freeze/recover), end users (claim rewards), and smart-wallet owners (manage passkeys).
- **Core flow**: Merchant deposits + approves → rewarder pulls from bank into hub and credits per-user claimable → user claims.
- **Key mechanism**: Internal claimable/pendingBalance accounting in `RewarderHub`; funds are pulled into the hub at credit time, so the hub self-collateralizes claims.
- **Token model**: Arbitrary standard ERC20 reward tokens; `mUSDToken` is an in-repo mock USD (MINTER_ROLE) explicitly marked test-only.
- **Admin model**: Solady `OwnableRoles` bitmask roles — `REWARDER_ROLE`, `COMPLIANCE_ROLE`, `UPGRADE_ROLE` on the hub; per-bank owner + `CAMPAIGN_BANK_MANAGER_ROLE`. No timelock; `RewarderHub` is UUPS-upgradeable.

For a visual overview of the protocol's architecture, see the [architecture diagram](architecture.svg).

### Contracts in Scope

| Subsystem | Key Contracts | nSLOC | Role |
|-----------|--------------|------:|------|
| Reward | RewarderHub | 193 | Central custodial accounting + claim/freeze/recover/withdraw |
| Banking | CampaignBank, CampaignBankFactory | 139 | Per-merchant escrow + clone factory |
| Tokens | mUSDToken | 19 | Mock USD ERC20 (test-only, MINTER_ROLE) |
| Kernel Auth | MultiWebAuthNValidator, MultiWebAuthNRecoveryAction, WebAuthnVerifier, P256VerifierWrapper | 230 | ERC-4337 passkey (secp256r1) signature validation |
| Kernel Types | MultiWebAuthNSignatureLib, WebAuthNSignatureLib, SingleWebAuthNSignatureLib | 62 | Calldata signature parsing libs |
| Utils | BetaDistribution, MPT | 139 | Math/proof libraries (not wired into value flow) |

### Backwards-Compatibility / Unused Code

- `src/utils/MPT.sol` — Merkle-Patricia proof verifier; no import anywhere in `src/`, 0% test coverage. Not part of the live reward/banking flow.
- `src/kernel/types/SingleWebAuthNSignatureLib.sol` — not imported by `MultiWebAuthNValidator` (which uses the *Multi* lib); 0% coverage. Appears to be a leftover single-passkey variant.
- `src/utils/BetaDistribution.sol` — exercised only by its own unit test; not referenced by any in-scope contract.
- Git note: commit `d1d818f` "Removed locked reward" stripped the locked-reward mechanism — `REWARDER_ROLE` is still documented as "push/lock rewards" (`Roles.sol:8`) though locking is gone.

### How It Fits Together

The core trick: the `RewarderHub` never holds float speculatively — it pulls a merchant's tokens out of their `CampaignBank` *at the moment* it credits a user's `claimable`, so per-token `pendingBalance` always equals what the hub already custodies.

### Reward push (pull-on-credit)

```
Rewarder backend
  └─ RewarderHub.pushReward(wallet, amount, token, bank)
       ├─ token.safeTransferFrom(bank → hub)          // funds pulled in first (RewarderHub.sol:163)
       ├─ claimable[wallet][token] += amount          // :167
       └─ pendingBalance[token]    += amount          // :168  (I-1 conservation)
```

### Batch push (chunked by bank,token)

```
RewarderHub.batch(ops[])
  └─ for each op, accumulate per (bank,token) chunk
       ├─ on boundary: token.safeTransferFrom(bank → hub, chunkSum)   // :199
       ├─ claimable[wallet][token] += op.amount                       // :211
       └─ pendingBalance[token]    += chunkSum                        // :200 / :221
```

### Claim

```
User
  └─ RewarderHub.claim(token)            // nonReentrant
       ├─ require !frozen[msg.sender]    // :333
       ├─ claimable[msg.sender][token] = 0   // :338
       ├─ pendingBalance[token] -= claimed   // :339
       └─ token.safeTransfer(hub → user)     // :341
```

### Merchant funding & wind-down

```
CampaignBankFactory.deployBank(owner) ─ clone ─→ CampaignBank.init(owner, hub)   // one-shot bind (I-4)
CampaignBank.setOpen(true) → deposit(token) → updateAllowance(token, amt)        // arms the hub's pull
CampaignBank.setOpen(false) → withdraw(token, amt, to)                            // reclaim principal
CampaignBank.revokeAllowance(token)  ◄── the only true outflow kill switch (X-2)
```

### Compliance freeze / recover

```
COMPLIANCE_ROLE.freezeUser(wallet)   → frozen[wallet] = block.timestamp   // :236
 ...60 days...
COMPLIANCE_ROLE.recoverFrozenFunds(ops, recipient)
       ├─ require block.timestamp >= frozenAt + 60 days   // :270 (I-3)
       ├─ claimable=0 ; pendingBalance -= amount          // :274-275
       └─ token.safeTransfer(hub → recipient)             // :276
```

---

## 2. Threat & Trust Model

### Protocol Threat Profile

> Protocol classified as: **Custodial reward/escrow distributor** with **Account-Abstraction (passkey signature validation)** characteristics.

No standard DeFi primitive matches (no oracle, AMM, lending, or peg). The dominant value-flow risk is share-style accounting integrity + privileged-role custody, closest to the Yield/Vault adversary set (donation/accounting desync, compromised operator). The Kernel WebAuthn subsystem is a separate, signature-validation surface with its own (account-self-scoped) adversary model.

### Actors & Adversary Model

| Actor | Trust Level | Capabilities |
|-------|-------------|-------------|
| Owner (RewarderHub) | Trusted | Holds UPGRADE_ROLE → can UUPS-upgrade the hub instantly (no timelock); full storage/logic replacement. |
| REWARDER_ROLE | Bounded (backend) | `pushReward`/`batch` — pulls merchant funds via existing allowances and credits arbitrary `claimable`. Not pausable. |
| COMPLIANCE_ROLE | Bounded (compliance op) | `freezeUser`/`unfreezeUser`; after 60d `recoverFrozenFunds`; `withdrawExcess` sweeps balance−pending instantly. Not pausable. |
| Merchant (bank owner + MANAGER_ROLE) | Bounded (per-bank) | `deposit`/`setOpen`/`updateAllowance(s)`/`withdraw`(when closed); owner-only `revokeAllowance(s)` any state. Scoped to own bank. |
| User | Untrusted | `claim`/`claimBatch` own balances; permissionlessly `deployBank`. |
| Smart-account owner | Untrusted (self-scoped) | passkey `enable`/`add`/`remove`/`setPrimary` write only their own `signerStorage`. |
| MINTER_ROLE (mUSD) | Trusted (test token) | unlimited `mint`. Mock only. |

**Adversary Ranking:**

1. **Compromised hub owner / UPGRADE_ROLE** — instant UUPS upgrade replaces all accounting logic and can redirect custodied funds.
2. **Compromised REWARDER_ROLE** — can drain every bank up to its standing allowance and mint arbitrary claimable entries.
3. **Compromised COMPLIANCE_ROLE** — can freeze any user and, after the fixed delay, seize their balances; can sweep "excess" continuously.
4. **Non-standard token integrator** — fee-on-transfer/rebasing reward tokens break the solvency invariant (I-2) silently.
5. **Malicious merchant** — controls bank lifecycle; griefs batches by revoking allowance / withdrawing mid-distribution.

See [entry-points.md](entry-points.md) for the full permissionless entry point map.

### Trust Boundaries

- **Hub upgradeability** — `_authorizeUpgrade` is `onlyRoles(UPGRADE_ROLE)` (`RewarderHub.sol:407`); no timelock/multisig in code → the seat is the single largest blast radius.
- **Bank → Hub allowance** — the hub spends merchant tokens through a standing ERC20 approval; `setOpen(false)` does NOT revoke it (X-2). Only `revokeAllowance` (owner) closes the boundary (`CampaignBank.sol:205`).
- **Compliance custody** — freeze (instant) + recover (60d, I-3) + `withdrawExcess` (instant) concentrate user-fund control in one role with no second signer in code.

### Key Attack Surfaces

- **Hub solvency vs. token standard** &nbsp;&#91;[I-2](invariants.md#i-2), [E-1](invariants.md#e-1)&#93; — `pushReward`/`batch` credit the full `_amount` but `safeTransferFrom` may deliver less for fee-on-transfer tokens (`RewarderHub.sol:163`↔`168`); only NatSpec forbids them. Worth confirming the deployment token allowlist is enforced off-chain.

- **`pendingBalance` accounting symmetry** &nbsp;&#91;[I-1](invariants.md#i-1), [I-11](invariants.md#i-11)&#93; — every credit/debit must touch `claimable` and `pendingBalance` together across `pushReward`, `batch`, `claim`, `claimBatch`, `recoverFrozenFunds`. Worth tracing the `batch` chunk-boundary math (`:199-221`) for an op whose `(bank,token)` ordering interleaves.

- **REWARDER_ROLE custody reach** &nbsp;&#91;[X-1](invariants.md#x-1), [X-2](invariants.md#x-2)&#93; — `_bank` is a caller-supplied parameter (`:154`); the role can pull from any bank holding a live allowance to the hub. Worth confirming banks only ever approve a hub they trust and that allowances are bounded, not `type(uint256).max`.

- **`withdrawExcess` native-ETH branch** &nbsp;&#91;[I-7](invariants.md#i-7)&#93; — `address(0)` path sends the entire contract ETH balance with no liability tracking (`:303-304`). Worth confirming no flow ever credits native claims.

- **Compliance freeze/recover timing** &nbsp;&#91;[I-3](invariants.md#i-3), [I-10](invariants.md#i-10)&#93; — `frozen` is togglable; re-freeze restarts the 60-day clock (`:236`/`:247`). Worth checking whether repeated freeze/unfreeze is an intended indefinite hold.

- **Bank `isOpen` is not a kill switch** &nbsp;&#91;[I-9](invariants.md#i-9), [X-2](invariants.md#x-2)&#93; — closing a bank blocks `updateAllowance` and enables `withdraw`, but leaves existing allowances live (`CampaignBank.sol:64-67`). Worth confirming operational runbooks use `revokeAllowance` to stop outflow.

- **WebAuthn challenge/dummy-sig path** — `_formatWebAuthNChallenge` returns the raw hash unverified when `challengeOffset == type(uint256).max` (`WebAuthnVerifier.sol:48-50`). Worth tracing that this dummy-sig branch is unreachable in real validation (it should only serve gas estimation).

### Upgrade Architecture Concerns

- **UUPS hub, no timelock** — `RewarderHub` (`UUPSUpgradeable` + `Initializable`) grants `UPGRADE_ROLE` to the owner at `init` (`:140`); an upgrade can rewrite the ERC-7201 storage struct and all fund logic instantly.
- **Implementation initializer locked** — both `RewarderHub` and `CampaignBank` call `_disableInitializers()` in their constructors; clone/proxy `init` is the only live initializer (good).

### Protocol-Type Concerns

**As a custodial reward distributor:**
- Liabilities are tracked per token in `pendingBalance`; correctness hinges entirely on the I-1 credit/debit symmetry — there is no independent reconciliation against actual balances except in `withdrawExcess`.
- `batch` reverts atomically on any failed chunk transfer (`:199`); a single under-allowanced bank fails the whole batch (griefing/DoS vector worth sizing).

**As an account-abstraction validator:**
- `validateUserOp` returns success/failure only via `_checkSignature` (`MultiWebAuthNValidator.sol:222`); branch coverage here is 20% — the secp256r1/Base64 challenge formatting is the highest-value correctness target.

### Temporal Risk Profile

**Deployment & Initialization:**
- Clone-then-init front-running on `deployBank` is acknowledged in NatSpec (`CampaignBankFactory.sol:65-73`) — impact is DoS only (attacker cannot steal funds; redeploy with new salt). Mitigated by design.
- `RewarderHub.init` is unprotected beyond `initializer`; the deployment script must call it atomically to avoid an init-front-run on the proxy.

**Deprecation:**
- Removed locked-reward mechanism (`d1d818f`) leaves stale role semantics; `MPT`/`SingleWebAuthNSignatureLib` remain as dead code (Section 1).

### Composability & Dependency Risks

**Dependency Risk Map:**

> **CampaignBank (ERC20 allowance)** — via `RewarderHub.safeTransferFrom`
> - Assumes: bank holds balance and granted ≥ pulled amount; standard ERC20 semantics
> - Validates: relies on `safeTransferLib` revert; no pre-balance/allowance check
> - Mutability: bank owner can revoke allowance / withdraw (when closed) any time
> - On failure: reverts (whole tx / whole batch)

> **Reward ERC20 tokens** — via `safeTransferFrom` / `safeTransfer`
> - Assumes: exact-amount transfer, no rebasing, no transfer hooks beyond reentrancy guard
> - Validates: NONE on-chain (NatSpec-only restriction)
> - Mutability: arbitrary tokens; upgradeable tokens (e.g. USDC) can change behavior
> - On failure: revert; non-standard tokens silently break I-2

> **P256 verifier** — via `MultiWebAuthNValidator._checkSignature`
> - Assumes: precompile/FCL returns `1` for valid sig
> - Validates: checks `success && ret.length != 0 && ret == 1` (`WebAuthnVerifier.sol:127-133`)
> - Mutability: `P256_VERIFIER` immutable; on-chain precompile at `0x100` (RIP-7212)
> - On failure: returns false (sig invalid) — fail-closed

**Token Assumptions** *(unvalidated only)*:
- Fee-on-transfer: assumes received == requested — breaks I-2/E-1.
- Rebasing: assumes fixed balances — `pendingBalance` drifts from real balance.
- Blacklistable (USDC/USDT): a blacklisted recipient bricks `claim`/`recover` for that user/token.

---

## 3. Invariants

> ### 📋 Full invariant map: **[invariants.md](invariants.md)**
>
> A dedicated reference file contains the complete invariant analysis — do not look here for the catalog.
>
> - **17 Enforced Guards** (`G-1` … `G-17`) — per-call preconditions with `Check` / `Location` / `Purpose`
> - **11 Single-Contract Invariants** (`I-1` … `I-11`) — Conservation, Bound, StateMachine, Temporal
> - **2 Cross-Contract Invariants** (`X-1`, `X-2`) — hub↔bank allowance / fund-pull assumptions
> - **2 Economic Invariants** (`E-1`, `E-2`) — per-token solvency + excess-withdrawal safety
>
> Every inferred block cites a concrete Δ-pair, guard-lift + write-sites, state edge, temporal predicate, or NatSpec quote. The **On-chain=No** blocks (I-2, I-7, I-9, I-10, X-1, X-2, E-1) are the high-signal ones. Attack-surface bullets above cross-link into the relevant blocks.

---

## 4. Documentation Quality

| Aspect | Status | Notes |
|--------|--------|-------|
| README | Present | `README.md` — addresses, folder structure, deploy notes |
| NatSpec | Thorough (~all functions) | Strong on value-flow contracts incl. explicit token-compat warnings (`RewarderHub.sol:34-43`) |
| Spec/Whitepaper | Missing | No design doc/whitepaper in repo |
| Inline Comments | Adequate | Good rationale comments (e.g. front-run analysis in factory; isOpen caveat in bank) |

---

## 5. Test Analysis

| Metric | Value | Source |
|--------|-------|--------|
| Test files | 13 (+1 mock) | File scan |
| Test functions | 201 | File scan |
| Line coverage | 74.48% (286/384) | `forge coverage` |
| Branch coverage | 53.23% (33/62) | `forge coverage` |

### Test Depth

| Category | Count | Contracts Covered |
|----------|-------|-------------------|
| Unit | ~190 | RewarderHub (admin/base/batch/claim/compliance/freeze/view), CampaignBank(Factory), MultiWebAuthnValidator, BetaDistribution |
| Integration | 1 file | RewarderHub.integration.t.sol |
| Stateful Fuzz (Foundry) | 1 file | RewarderHub.invariant.t.sol |
| Stateless Fuzz | present | Foundry `fuzz` config (128 runs) used across tests |
| Formal Verification (Certora/Halmos/HEVM) | 0 | none |
| Fork | 0 | none |

Per-file coverage highlights: RewarderHub 98% lines / 90% branches; CampaignBank 98%/100%; MultiWebAuthNValidator 53%/20%; MPT 0%; mUSDToken 0%; SingleWebAuthNSignatureLib 0%.

### Gaps

- **WebAuthn validator** is the weakest-covered live code (53% line / 20% branch) — the secp256r1 verification and challenge-formatting branches need targeted negative tests.
- **No formal verification** — for the central `pendingBalance`/`claimable` conservation (I-1) a Certora/Halmos proof would be high value; currently only one Foundry invariant suite guards it.
- **Dead code uncovered** — MPT (0%), SingleWebAuthNSignatureLib (0%); either wire in or remove from scope.
- No fork tests (acceptable — no external protocol integration beyond P256 precompile).

---

## 6. Developer & Git History

> Repo shape: normal_dev — 210 commits over 818 days (2024-04 → 2026-06), 150 touch source. Single-author dominated.

### Contributors

| Author | Commits | Source Lines (+/-) | % of Source Changes |
|--------|--------:|--------------------|--------------------:|
| KONFeature | 208 | +12,747 (net) | ~100% |
| L'atelier / Sandbox User | 1 each | minimal | <1% |

### Review & Process Signals

| Signal | Value | Assessment |
|--------|-------|------------|
| Unique contributors | 3 (1 effective) | Single-developer |
| Merge commits | 12 of 210 (~6%) | Some PR flow, limited peer review |
| Repo age | 2024-04-02 → 2026-06-29 | 818 days |
| Recent source activity (30d) | 0 late commits | Quiet before this snapshot |
| Test co-change rate | 68% | 68% of source-changing commits also touch tests (co-modification, not coverage) |

### File Hotspots

| File | Modifications | Note |
|------|-------------:|------|
| src/reward/RewarderHub.sol | 11 | Highest churn — central accounting; prioritize review |
| src/bank/CampaignBank.sol | 6 | Allowance/withdraw lifecycle |
| src/utils/MPT.sol | 6 | Churned but unused in scope |
| src/utils/BetaDistribution.sol | 5 | Math lib, isolated |
| src/bank/CampaignBankFactory.sol | 3 | Proxy/clone pattern |

### Security-Relevant Commits

| SHA | Date | Subject | Score | Key Signal |
|-----|------|---------|------:|------------|
| 85e1074 | 2026-01-09 | Fix reentrancy on batch distrib + 0 owner on campaign bank | 14 | bug fix, tightens access control, 3 security domains |
| d1d818f | 2026-01-13 | Removed locked reward | 13 | loosens access control, removes accounting code |
| 02e4180 | 2026-01-13 | Gas optimisation | 12 | rewrites access control, accounting |
| 598aefd | 2026-01-13 | Track pending balance per token + withdraw excess | 12 | adds pendingBalance accounting (I-1/I-2) |
| 377bfe4 | 2026-01-13 | Add compliance features (freeze user funds) | 12 | new COMPLIANCE_ROLE custody powers |
| ac62fd9 | 2026-01-09 | Batch methods | 12 | adds batch transfer logic |
| 5dee700 | 2026-02-18 | Fix some minor issue | 11 | spans access/fund/signatures/state |

### Dangerous Area Evolution

| Security Area | Commits | Key Files |
|--------------|--------:|-----------|
| access_control / fund_flows / state_machines | 14 | RewarderHub.sol, CampaignBank.sol, mUSDToken.sol |

### Forked Dependencies

| Library | Path | Upstream | Status | Notes |
|---------|------|----------|--------|-------|
| FreshCryptoLib | lib/FreshCryptoLib | FCL (rdubois-crypto) | Submodule | P256/WebAuthn crypto; many mixed pragmas |
| kernel-v2 | lib/kernel-v2 | ZeroDev Kernel v2 | Submodule | ERC-4337 base for validators |
| murky / solidity-rlp / solady | lib/* | standard | Submodule | RLP used by MPT; solady core dep |

### Security Observations

- **Single-developer concentration** — KONFeature ~100% of source; bus-factor + review-ergonomics risk.
- **Limited peer review** — only ~6% merge commits; most work landed directly.
- **RewarderHub is the churn + attack-surface hotspot** — 11 modifications and all top fix commits route through it.
- **Reentrancy already fixed once** — `85e1074` added the batch reentrancy guard; confirm `nonReentrant` covers every fund-moving path (it does on pushReward/batch/claim/claimBatch/recover/withdrawExcess).
- **Compliance custody added late** — `377bfe4` introduced freeze/recover; newest high-power surface.
- **No technical-debt markers** — 0 TODO/FIXME/HACK in source.
- **Dead code retained** — MPT and SingleWebAuthNSignatureLib unused/uncovered.

### Cross-Reference Synthesis

- **RewarderHub.sol is #1 in churn AND attack priority** — `598aefd`+`02e4180` reworked the very `pendingBalance` accounting that I-1/I-2/E-1 depend on → highest-leverage review target: `pushReward`, `batch`, `withdrawExcess`.
- **Compliance role is new and unbounded** (`377bfe4`) → maps to the I-3/I-10 freeze-timing and `withdrawExcess` surfaces; no second-signer in code.
- **WebAuthn coverage gap (20% branch) + forked FCL** → the least-tested live code sits atop a multi-pragma crypto submodule; concentrate formal/negative tests there.

---

## X-Ray Verdict

**FRAGILE** — Well-tested core accounting with clear roles, but unilateral instant-upgrade + concentrated single-key custody and no timelock cap the access-control posture; weak WebAuthn branch coverage and dead code add residual risk.

**Structural facts:**
1. ~789 nSLOC across 6 subsystems; 15 source files, all Solidity 0.8.23.
2. One UUPS-upgradeable contract (RewarderHub) with instant `UPGRADE_ROLE` upgrade; no timelock or multisig in code.
3. 201 test functions across 13 files; 74.48% line / 53.23% branch coverage; 1 Foundry invariant suite, 0 formal verification.
4. Single developer authored ~100% of source over 818 days; ~6% merge commits.
5. Central solvency depends on per-token `pendingBalance == Σ claimable` (I-1) and standard-ERC20 behavior (I-2, unenforced on-chain).
