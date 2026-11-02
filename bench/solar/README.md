# Solar

[Solar](https://github.com/paradigmxyz/solar) is Paradigm's Solidity compiler written in Rust. v0.3 is the first
release that generates bytecode ([announcement](https://www.paradigm.xyz/writing/solar-100-faster-solidity)), and
Foundry v1.9.0 ships it next to `forge`.

This repo uses it for the dev loop only:

```bash
FOUNDRY_PROFILE=solar forge test    # or: bun run test:solar
FOUNDRY_PROFILE=solar forge build   # or: bun run build:solar
```

The `solar` profile in `foundry.toml` keeps every other setting from the default profile, and writes to `out-solar/`
and `cache-solar/`. Deployments, `forge script` and verification keep using the default profile (solc 0.8.23).
Latest numbers: [`results/REPORT.md`](results/REPORT.md).

## Install

Foundry >= 1.9.0. Check with `forge --version` and `solar --version`.

The old Bash `foundryup` (the one that prints `foundryup: installing foundry (version nightly, …)`) resolves
`nightly` through a git tag that stopped moving in April 2026, so it installs a forge without Solar. Pin a release
instead, or switch to the Rust `foundryup` from [foundry-rs/foundryup](https://github.com/foundry-rs/foundryup):

```bash
foundryup -v v1.9.0
```

## Benchmark

```bash
bun run bench:solar                          # solc vs Solar, 5 clean builds each
RUNS=5 VIA_IR=1 bun run bench:solar          # + solc --via-ir (~90 s per build on an M1 Pro)
FORGE=/path/to/forge SOLAR=/path/to/solar bun run bench:solar   # other binaries
```

`run.ts` writes `results/<variant>/*.json` and renders `results/REPORT.md`. `bun run bench/solar/report.ts`
re-renders the report without re-running anything. Scratch builds go to `bench/solar/.work/` (git-ignored).

Every variant uses the same forge binary, the default profile of `foundry.toml` (solc 0.8.23, legacy pipeline,
`optimizer_runs = 100_000`, EVM `shanghai`) and its own `out/` and `cache/` dirs:

| Metric | How |
|---|---|
| Clean build | `forge build --force`, wall clock + the compiler time forge prints + peak RSS (`/usr/bin/time`) |
| Rebuild after an edit | append a comment to `src/reward/RewarderHub.sol` (13 files depend on it), rebuild on a warm cache |
| Test parity | `forge test --json`, status of every test |
| Bytecode size | runtime / init size of every concrete `src/` contract, read from the artifacts |
| Deployment + function gas | `forge test --gas-report --json`, `src/` contracts only, median per function |
| Per-test gas | gas of each unit test (median for fuzz tests) |

Lint-on-build is turned off: it runs Solar's linter after every build, whatever the compiler.

## Findings (Foundry 1.9.0, Solar 0.3.0, M1 Pro)

**Build speed.** Clean build 10.1 s → 0.53 s (**19×**). The compiler alone goes from 9.9 s to 0.24 s, the rest is
forge's own overhead. A rebuild after editing `RewarderHub.sol` drops from 6.2 s to 0.38 s, and peak memory from
459 MiB to 132 MiB. Against solc `--via-ir` (87 s) it is **164×**. Running the tests on a warm build takes about the
same time with every compiler.

**Smaller, cheaper bytecode.** On `src/`: runtime size −41%, deployment gas −39%. Function gas (gas-report medians)
drops by 12.7% geomean, 39 of 40 functions are cheaper. The gain depends on how much of the call is storage:
−40 to −67% on functions that touch no storage (constant/immutable getters, `predictBankAddress`, `validCaller`),
−5 to −15% on storage reads (`getClaimable`, `getBalance`, `owner`), −0.4 to −3% on write paths (`pushReward`,
`claim`, `deposit`, `withdraw`, `init`), where SSTORE/SLOAD costs dominate. solc `--via-ir` at the same settings: runtime
size +1.5%, function gas +4%.

**One regression: `P256VerifierWrapper` +22% gas** (212k → 260k per verification, solc `--via-ir` is +42%). It
wraps FreshCryptoLib's P256 code, mostly hand-written inline assembly (`mulmod`/`addmod` loops). Solar does not beat
solc's legacy optimizer on assembly-heavy code yet. This contract is only the fallback for chains without the
RIP-7212 precompile at `0x100`. `MultiWebAuthNValidator` uses the precompile when it is present.

**Test parity: 217/217** with every compiler, after fixing two tests. With the original tests, Solar and
solc `--via-ir` both failed the same two in the same way:

- `RewarderHubFreezeTest::test_getFreezeInfo_canRecover` read `block.timestamp` into a local, then called
  `vm.warp`. In the EVM the timestamp cannot change within a transaction, so Solar (and via-IR) may read
  `TIMESTAMP` again instead of keeping the value on the stack, and the local ended up holding the warped time.
  `forge lint` flags this pattern (`environment-read-across-mutation`). The test now uses `vm.getBlockTimestamp()`.
- `BetaDistributionTest::test_wadBetaPoint_average_beta2` asserted that the average of 10k samples is above 0.49,
  but the expected mean for β = 2.1 is exactly 0.9 × 0.5 + 0.1 × 0.4 = 0.49. The PRNG seed comes from `gas()`, so
  any bytecode change moved the average to one side or the other of 0.49. The bounds are now 0.48–0.50. A probe
  test confirmed that Solar's samples were all distinct and averaged 0.4991 for β = 2 and 0.4023 for β = 3.

**Other checks.** Solar's bytecode was identical across two builds (119 artifacts), and building only `src/` gave
the same `src/` bytecode as a whole-project build. Solar rejected an invalid `view` function with solc's error code
(8961).

## Caveats

- Solar 0.3 is the first release with codegen and is marked experimental: "do not deploy contracts compiled by
  Solar to production yet". Its metadata reports `0.8.38+commit.….solar.0.3.0`, and block explorers cannot verify
  that bytecode today. Contract addresses computed from init code hashes (CREATE2) also change with the compiler.
- Gas measured under the `solar` profile does not describe the deployed bytecode. Gas snapshots and gas reports
  that matter should come from the default profile.
- Solar implements Solidity 0.8.38 and warns on every `pragma solidity 0.8.23` (warning 5333), but compiles the
  sources anyway. This benchmark therefore compares a 0.8.38-level compiler with solc 0.8.23. A newer solc could
  not be used without changing the pinned pragmas.
- The Solar bundled with Foundry 1.9.0 (`0.3.0-dev+commit.a2b44354`, one release-tooling commit before the v0.3.0
  tag) writes its full version string into the CBOR metadata: 23 bytes more per contract than the standalone v0.3.0
  binary. That is the whole size difference between the two (−41% vs −43% runtime size). Codegen is the same.
- Fuzz tests do not exercise identical inputs: forge seeds its fuzz dictionary with constants found in the
  bytecode. Gas-report rows marked ⚠️ have different call counts for that reason.
- Per-test gas includes the test contracts, which are compiled with the same compiler. For contract costs, use the
  gas report.
- Timings come from one machine (M1 Pro, 8 cores). Solar is multi-threaded and solc is not, so the gap grows with
  core count.
