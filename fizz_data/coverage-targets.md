# Coverage Targets & Assessment

**Fuzz profile:** `via_ir` is disabled in `foundry.toml` — Medusa coverage numbers are normally accurate (no IR deflation). No `[profile.fuzz]` needed.

## ⚠️ Medusa proxy line-coverage artifact (RewarderHub)

Medusa's **line-coverage report under-reports `RewarderHub.sol` (shows 1%)** even though the
contract is fully exercised. This was proven empirically during Step 8:

- `RewarderHubHandler.sol` shows **58 covered lines** — the handlers run.
- A temporary `property_claimableAlwaysZero()` was **violated within seconds by 8 workers**
  (5–15 call sequences), i.e. the fuzzer reaches `pushReward`/`batch` and mutates hub state.
- A guard-free direct `hub.pushReward(...)` call and `hub.hasAllRoles(admin, ...) == true`
  both execute successfully through the proxy.

Root cause: Medusa mis-attributes line coverage for `RewarderHub` delegatecalled through its
ERC1967 (UUPS) proxy. The deployment matches production (`LibClone.deployDeterministicERC1967`
+ `init`, see `script/Deploy.s.sol`). `CampaignBank` — also a delegatecall clone — reports
90% normally, so this is specific to the UUPS proxy, not a harness defect.

**Conclusion: RewarderHub is treated as well-covered for invariant generation. The displayed
1% is a Medusa reporting limitation, not a coverage gap.**

## Per-contract targets (no-ir column)

| Contract | Role | Target | Displayed | Real status |
|---|---|---|---|---|
| CampaignBank | Core banking | 80% | 90% | ✅ |
| RewarderHub | Core reward accounting | 80% | 1% (artifact) | ✅ exercised (see above) |
| mUSDToken | Peripheral mock token | 50% | 33% | ◻︎ mint/transfer/transferFrom/approve all reachable; uncovered = `name()`/`symbol()` pure + unselected `permit` |

## Out-of-scope (intentionally not fuzzed → 0%)

Documented skips, excluded during entry-point selection (Step 4):

- **CampaignBankFactory** — clone-deployment bootstrap; banks are deployed directly in `setup()`.
- **MultiWebAuthNValidator / MultiWebAuthNRecoveryAction / WebAuthnVerifier / P256VerifierWrapper /
  *SignatureLib** — ERC-4337 secp256r1 passkey signature validation. Requires valid P256
  signatures and is disconnected from the reward/banking value invariants. Not fuzzable with
  random inputs.
- **BetaDistribution / MPT** — standalone math/proof libraries, not wired into the value flow
  (flagged as unused by x-ray).
- **Roles / Errors** — constant/error definitions, no executable logic.

## Cycle History

### Cycle 1 (ERC1967 proxy, ~30s, ~360k calls)

| Contract | Role | Target | Hit (displayed) | Status |
|---|---|---|---|---|
| CampaignBank | Core | 80% | 90% | ✅ |
| RewarderHub | Core | 80% | 1% (artifact; real = high) | ✅ |
| mUSDToken | Peripheral | 50% | 33% | ◻︎ acceptable |

Proceeding to invariant generation: the harness exercises all selected value-flow entry points.
