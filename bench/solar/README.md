# Solar benchmark

Compares [Solar](https://github.com/paradigmxyz/solar) v0.3 (Paradigm's Rust Solidity compiler, the first release
with codegen, see [the announcement](https://www.paradigm.xyz/writing/solar-100-faster-solidity)) with the solc
setup this repo ships with: solc 0.8.23, legacy pipeline, `optimizer_runs = 100_000`, EVM `shanghai`. solc with
`--via-ir` is measured too, since Paradigm's headline numbers compare against it.

Latest results: [`results/REPORT.md`](results/REPORT.md).

## Run it

```bash
# Needs a Foundry build where `--use` accepts a binary path (1.8.x nightly or later) and a Solar binary.
# Both can live outside PATH, the script never touches the global toolchain.
FORGE=/path/to/forge SOLAR=/path/to/solar bun run bench:solar

RUNS=5            # clean builds per variant (default 5)
VIA_IR=1          # also bench solc --via-ir (~90 s per build on an M1 Pro)
VIA_IR_RUNS=1     # builds for the via-IR variant (default 1)
```

Release binaries: Foundry nightly from [foundry-rs/foundry releases](https://github.com/foundry-rs/foundry/releases)
(the tarball ships its own, older, `solar`), Solar from
[paradigmxyz/solar releases](https://github.com/paradigmxyz/solar/releases). For daily use, `foundryup` then
`forge build --use solar` / `forge test --use solar` is enough.

The script writes `results/<variant>/*.json` and renders `results/REPORT.md`. `bun run bench/solar/report.ts`
re-renders the report without re-running anything. Scratch builds go to `bench/solar/.work/` (git-ignored).

## What it measures

Every variant uses the same forge binary, the same `foundry.toml` and its own `out/` and `cache/` dirs.

| Metric | How |
|---|---|
| Clean build | `forge build --force`, wall clock + the compiler time forge prints + peak RSS (`/usr/bin/time`) |
| Rebuild after an edit | append a comment to `src/reward/RewarderHub.sol` (13 files depend on it), rebuild on a warm cache |
| Test parity | `forge test --json`, status of every test |
| Bytecode size | runtime / init size of every concrete `src/` contract, read from the artifacts |
| Deployment + function gas | `forge test --gas-report --json`, `src/` contracts only, median per function |
| Per-test gas | gas of each unit test (median for fuzz tests) |

Lint-on-build is turned off: it runs Solar's linter after every build, whatever the compiler.

## Findings (Solar 0.3.0, M1 Pro)

**Build speed.** Clean build 10.2 s → 0.45 s (**23×**), and the compiler alone 10 s → 0.23 s. Rebuilding after an
edit to `RewarderHub.sol` drops from 6.3 s to 0.3 s. Peak memory 465 MiB → 124 MiB. Against solc `--via-ir` (90 s)
it is **200×**. The test suite itself runs at the same speed. Most of what remains is forge's own overhead.

**Smaller, cheaper bytecode.** On `src/`: runtime size −43%, deployment gas −39%. Function gas (gas-report medians)
drops by 12.7% geomean, 39 of 40 functions are cheaper. The gain depends on how much of the call is storage:
−40 to −67% on functions that touch no storage (constant/immutable getters, `predictBankAddress`, `validCaller`),
−5 to −15% on storage reads (`getClaimable`, `getBalance`, `owner`), −0.4 to −4.4% on write paths (`pushReward`,
`claim`, `deposit`, `withdraw`), where SSTORE/SLOAD costs dominate. solc `--via-ir` at the same settings: runtime
size +1.5%, function gas +3.4%.

**One regression: `P256VerifierWrapper` +22% gas** (212k → 260k per verification). It wraps FreshCryptoLib's
P256 code, which is mostly hand-written inline assembly (`mulmod`/`addmod` loops). Solar does not beat solc's legacy
optimizer on assembly-heavy code yet. This contract is only the fallback for chains without the RIP-7212 precompile
at `0x100`. `MultiWebAuthNValidator` uses the precompile when it is present.

**Test parity: 215/217.** The two failures are test issues, not miscompilations. solc `--via-ir` fails the same two
tests in the same way:

- `RewarderHubFreezeTest::test_getFreezeInfo_canRecover`: the test reads `block.timestamp` into a local, then
  calls `vm.warp`. In the EVM the timestamp cannot change within a transaction, so Solar (and via-IR) may read
  `TIMESTAMP` again instead of keeping the value on the stack, and the local ends up holding the warped time.
  `forge lint` already flags this line (`environment-read-across-mutation`). Fix: use `vm.getBlockTimestamp()`.
- `BetaDistributionTest::test_wadBetaPoint_average_beta2`: asserts that the average of 10k samples is above 0.49,
  but the expected mean for β = 2.1 is exactly 0.9 × 0.5 + 0.1 × 0.4 = 0.49. The PRNG seed comes from `gas()`,
  so any bytecode change moves the average to one side or the other of 0.49. With a probe test, Solar's samples were
  all distinct and averaged 0.4991 for β = 2 and 0.4023 for β = 3, which is correct.

**Other checks.** Solar's bytecode was identical across two builds (119 artifacts), and building only `src/` gave
the same `src/` bytecode as a whole-project build. Solar rejected an invalid `view` function with solc's error code
(8961).

## Caveats

- Solar 0.3 is the first release with codegen and is marked experimental: "do not deploy contracts compiled by
  Solar to production yet". Its metadata reports `0.8.38+commit.….solar.0.3.0`, and block explorers cannot verify
  that bytecode today. Deployment artifacts should keep coming from solc.
- Solar implements Solidity 0.8.38 and warns on every `pragma solidity 0.8.23` (warning 5333), but compiles the
  sources anyway. This benchmark therefore compares a 0.8.38-level compiler with solc 0.8.23. A newer solc could
  not be used without changing the pinned pragmas.
- Fuzz tests do not exercise identical inputs: forge seeds its fuzz dictionary with constants found in the
  bytecode. Gas-report rows marked ⚠️ have different call counts for that reason.
- Per-test gas includes the test contracts, which are compiled with the same compiler. For contract costs, use the
  gas report.
- Timings come from one machine (M1 Pro, 8 cores). Solar is multi-threaded and solc is not, so the gap grows with
  core count.

## Takeaways

- `forge build --use solar` / `forge test --use solar` is usable today as a fast inner loop for this repo: about 0.3 s
  rebuilds instead of 6 s, and the test suite passes once the two fragile tests are fixed.
- Keep solc for CI gas snapshots, deployment and verification until Solar is cleared for production. Gas numbers
  measured under Solar do not describe the deployed bytecode.
- Once Solar is production-ready, it would cut the deployment cost of these contracts by about 40% and their
  per-call gas by a few percent. The P256 fallback path would need a re-check.
