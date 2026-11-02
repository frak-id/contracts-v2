#!/usr/bin/env bun
/**
 * Solar vs solc benchmark for this Foundry project.
 *
 * For every compiler variant it measures, on the same forge binary and the same foundry.toml:
 *   - clean build time (wall clock, compiler-reported time, peak RSS), RUNS times
 *   - incremental rebuild time after editing one central contract (warm cache), RUNS times
 *   - the full test suite (status + gas of every test)
 *   - `forge test --gas-report` (deployment + per-function gas of every contract the tests touch)
 *   - runtime / init bytecode size of every `src/` contract
 *
 * Results land in bench/solar/results/<variant>/*.json, then report.ts renders results/REPORT.md.
 *
 * Env:
 *   FORGE        forge binary (default: `forge`). Needs Foundry >= 1.9, which ships `solar` next to `forge`.
 *   SOLAR        solar binary (default: `solar`, the one Foundry installs). Standalone releases:
 *                https://github.com/paradigmxyz/solar/releases
 *   RUNS         clean builds per variant (default: 5)
 *   VIA_IR       "1" to also bench solc with `--via-ir` (slow: ~90s per build on an M-series laptop)
 *   VIA_IR_RUNS  clean builds for the via-IR variant (default: 1)
 */
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { arch, cpus, platform, totalmem } from "node:os";
import { join, resolve } from "node:path";

const ROOT = resolve(import.meta.dir, "../..");
const BENCH_DIR = join(ROOT, "bench/solar");
const WORK_DIR = join(BENCH_DIR, ".work");
const RESULTS_DIR = join(BENCH_DIR, "results");

const FORGE = process.env.FORGE ?? "forge";
const SOLAR = process.env.SOLAR ?? "solar";
const RUNS = Number(process.env.RUNS ?? 5);
const VIA_IR = process.env.VIA_IR === "1";
const VIA_IR_RUNS = Number(process.env.VIA_IR_RUNS ?? 1);

const FORGE_ENV = {
    ...process.env,
    // Every variant starts from the default profile, a stray FOUNDRY_PROFILE=solar would turn the baseline into Solar
    FOUNDRY_PROFILE: "default",
    FOUNDRY_DISABLE_NIGHTLY_WARNING: "1",
    // Lint-on-build runs Solar's linter after every build, it would add the same noise to every variant
    FOUNDRY_LINT_ON_BUILD: "false",
    NO_COLOR: "1",
};

/// Edited (a trailing comment, so the content hash changes) to measure the edit -> rebuild loop
const INCREMENTAL_FILE = "src/reward/RewarderHub.sol";

type Variant = { id: string; label: string; args: string[]; runs: number };

const variants: Variant[] = [
    { id: "solc", label: "solc (project settings)", args: [], runs: RUNS },
    { id: "solar", label: "Solar", args: ["--use", SOLAR], runs: RUNS },
];
if (VIA_IR) variants.push({ id: "solc-via-ir", label: "solc --via-ir", args: ["--via-ir"], runs: VIA_IR_RUNS });

/* -------------------------------------------------------------------------- */
/*                                   Helpers                                  */
/* -------------------------------------------------------------------------- */

type RunResult = { stdout: string; stderr: string; exitCode: number; wallMs: number };

function run(cmd: string[], opts: { allowFailure?: boolean } = {}): RunResult {
    const start = performance.now();
    const proc = Bun.spawnSync(cmd, { cwd: ROOT, env: FORGE_ENV, stdout: "pipe", stderr: "pipe" });
    const wallMs = performance.now() - start;
    const res = {
        stdout: proc.stdout.toString(),
        stderr: proc.stderr.toString(),
        exitCode: proc.exitCode ?? -1,
        wallMs,
    };
    if (res.exitCode !== 0 && !opts.allowFailure) {
        console.error(res.stdout.slice(-4000));
        console.error(res.stderr.slice(-4000));
        throw new Error(`Command failed (${res.exitCode}): ${cmd.join(" ")}`);
    }
    return res;
}

/// Wrap a command with /usr/bin/time to grab the peak RSS of the process tree (forge + compiler)
function withRss(cmd: string[]): string[] {
    if (!existsSync("/usr/bin/time")) return cmd;
    return platform() === "darwin" ? ["/usr/bin/time", "-l", ...cmd] : ["/usr/bin/time", "-v", ...cmd];
}

function parseRssBytes(stderr: string): number | null {
    // macOS: "  123456789  maximum resident set size" (bytes)
    const mac = stderr.match(/(\d+)\s+maximum resident set size/);
    if (mac) return Number(mac[1]);
    // Linux: "Maximum resident set size (kbytes): 123456"
    const linux = stderr.match(/Maximum resident set size \(kbytes\):\s*(\d+)/);
    if (linux) return Number(linux[1]) * 1024;
    return null;
}

/// Parse forge's "Solc 0.8.23 finished in 9.78s" / "Solar 0.8.23 finished in 322.36ms" line
function parseCompilerMs(output: string): number | null {
    const m = output.match(/(?:Solc|Solar)[^\n]*finished in ([\d.]+)(ms|s)\b/);
    if (!m) return null;
    return m[2] === "s" ? Number(m[1]) * 1000 : Number(m[1]);
}

function writeJson(path: string, data: unknown) {
    writeFileSync(path, `${JSON.stringify(data, null, 2)}\n`);
}

/* -------------------------------------------------------------------------- */
/*                                  Collectors                                */
/* -------------------------------------------------------------------------- */

function benchBuild(v: Variant, out: string, cache: string) {
    const samples: { wallMs: number; compilerMs: number | null; rssBytes: number | null }[] = [];
    let files: number | null = null;
    for (let i = 0; i < v.runs; i++) {
        const res = run(withRss([FORGE, "build", "--force", ...v.args, "--out", out, "--cache-path", cache]));
        const compiled = res.stdout.match(/Compiling (\d+) files/);
        if (compiled) files = Number(compiled[1]);
        const sample = {
            wallMs: res.wallMs,
            compilerMs: parseCompilerMs(res.stdout + res.stderr),
            rssBytes: parseRssBytes(res.stderr),
        };
        samples.push(sample);
        console.log(
            `  build ${i + 1}/${v.runs}: wall ${sample.wallMs.toFixed(0)}ms, compiler ${sample.compilerMs?.toFixed(0)}ms, rss ${((sample.rssBytes ?? 0) / 2 ** 20).toFixed(0)}MiB`
        );
    }
    return { files, samples };
}

/// Edit one central contract and rebuild on a warm cache: recompiles the file + everything importing it
function benchIncremental(v: Variant, out: string, cache: string) {
    const path = join(ROOT, INCREMENTAL_FILE);
    const original = readFileSync(path, "utf8");
    const samples: { wallMs: number; compilerMs: number | null }[] = [];
    let files: number | null = null;
    try {
        run([FORGE, "build", ...v.args, "--out", out, "--cache-path", cache]);
        for (let i = 0; i < v.runs; i++) {
            // A different comment every run, so each build sees new content
            writeFileSync(path, `${original}\n// solar-bench incremental edit ${i}\n`);
            const res = run([FORGE, "build", ...v.args, "--out", out, "--cache-path", cache]);
            const compiled = res.stdout.match(/Compiling (\d+) files/);
            if (compiled) files = Number(compiled[1]);
            samples.push({ wallMs: res.wallMs, compilerMs: parseCompilerMs(res.stdout + res.stderr) });
        }
    } finally {
        writeFileSync(path, original);
    }
    // Leave the cache matching the original sources for the test runs
    run([FORGE, "build", ...v.args, "--out", out, "--cache-path", cache]);
    const wall = samples.map((s) => s.wallMs).sort((a, b) => a - b)[Math.floor(samples.length / 2)];
    console.log(`  incremental (${INCREMENTAL_FILE}, ${files} files): median wall ${wall.toFixed(0)}ms`);
    return { file: INCREMENTAL_FILE, files, samples };
}

/// Runtime / init size of every concrete `src/` contract, read from the build artifacts
function collectSizes(out: string) {
    const sizes: Record<
        string,
        {
            source: string;
            kind: "contract" | "library";
            runtime: number;
            init: number;
            compiler: string;
            evmVersion: string;
        }
    > = {};
    for (const dir of readdirSync(out)) {
        if (!dir.endsWith(".sol")) continue;
        for (const file of readdirSync(join(out, dir))) {
            if (!file.endsWith(".json")) continue;
            const artifact = JSON.parse(readFileSync(join(out, dir, file), "utf8"));
            const target = artifact.metadata?.settings?.compilationTarget ?? {};
            const [source, name] = Object.entries(target)[0] ?? [];
            if (typeof source !== "string" || !source.startsWith("src/")) continue;
            const runtime = ((artifact.deployedBytecode?.object ?? "0x").length - 2) / 2;
            const init = ((artifact.bytecode?.object ?? "0x").length - 2) / 2;
            if (runtime === 0) continue; // interfaces / abstract contracts
            // Artifacts carry no AST with Solar, so look at the source to flag libraries
            const isLibrary = new RegExp(`\\blibrary\\s+${name}\\b`).test(readFileSync(join(ROOT, source), "utf8"));
            sizes[`${source}:${name}`] = {
                source,
                kind: isLibrary ? "library" : "contract",
                runtime,
                init,
                compiler: artifact.metadata?.compiler?.version,
                evmVersion: artifact.metadata?.settings?.evmVersion,
            };
        }
    }
    return sizes;
}

type TestEntry = { status: string; reason: string | null; kind: string; gas: number | null };

/// Full test suite: status + gas of every test (raw JSON is >1MB of traces, keep only what we compare)
function collectTests(v: Variant, out: string, cache: string) {
    const res = run([FORGE, "test", ...v.args, "--out", out, "--cache-path", cache, "--json"], {
        allowFailure: true,
    });
    const raw = JSON.parse(res.stdout);
    const tests: Record<string, TestEntry> = {};
    for (const [suite, suiteResult] of Object.entries<any>(raw)) {
        for (const [name, t] of Object.entries<any>(suiteResult.test_results)) {
            const kind = Object.keys(t.kind)[0];
            const k = t.kind[kind];
            const gas = kind === "Unit" ? k.gas : kind === "Fuzz" ? k.median_gas : null;
            tests[`${suite}::${name}`] = { status: t.status, reason: t.reason ?? null, kind, gas };
        }
    }
    return { wallMs: res.wallMs, exitCode: res.exitCode, tests };
}

function collectGasReport(v: Variant, out: string, cache: string) {
    const res = run([FORGE, "test", ...v.args, "--out", out, "--cache-path", cache, "--gas-report", "--json"], {
        allowFailure: true,
    });
    return JSON.parse(res.stdout);
}

/* -------------------------------------------------------------------------- */
/*                                     Main                                   */
/* -------------------------------------------------------------------------- */

function machine() {
    const cpu =
        platform() === "darwin"
            ? run(["sysctl", "-n", "machdep.cpu.brand_string"], { allowFailure: true }).stdout.trim()
            : (cpus()[0]?.model ?? "unknown");
    return { os: `${platform()} ${arch()}`, cpu, cores: cpus().length, memGiB: Math.round(totalmem() / 2 ** 30) };
}

mkdirSync(RESULTS_DIR, { recursive: true });

const meta = {
    date: new Date().toISOString(),
    gitCommit:
        run(["git", "rev-parse", "HEAD"]).stdout.trim() +
        (run(["git", "status", "--porcelain", "--", "src", "test", "foundry.toml"]).stdout.trim() ? "-dirty" : ""),
    forge: run([FORGE, "--version"]).stdout.trim().split("\n")[0],
    solar: run([SOLAR, "--version"]).stdout.trim().split("\n")[0],
    runs: RUNS,
    machine: machine(),
    variants: variants.map(({ id, label, args, runs }) => ({ id, label, args: args.join(" "), runs })),
};
writeJson(join(RESULTS_DIR, "meta.json"), meta);
console.log(`forge: ${meta.forge}\nsolar: ${meta.solar}\n`);

for (const v of variants) {
    console.log(`=== ${v.label}`);
    const work = join(WORK_DIR, v.id);
    rmSync(work, { recursive: true, force: true });
    const out = join(work, "out");
    const cache = join(work, "cache");
    const dest = join(RESULTS_DIR, v.id);
    mkdirSync(dest, { recursive: true });

    const build = benchBuild(v, out, cache);
    writeJson(join(dest, "build.json"), build);
    writeJson(join(dest, "incremental.json"), benchIncremental(v, out, cache));

    const sizes = collectSizes(out);
    writeJson(join(dest, "sizes.json"), sizes);
    console.log(`  sizes: ${Object.keys(sizes).length} src contracts`);

    const tests = collectTests(v, out, cache);
    writeJson(join(dest, "tests.json"), tests);
    const counts = Object.values(tests.tests).reduce<Record<string, number>>((acc, t) => {
        acc[t.status] = (acc[t.status] ?? 0) + 1;
        return acc;
    }, {});
    console.log(`  tests: ${JSON.stringify(counts)} in ${tests.wallMs.toFixed(0)}ms`);

    writeJson(join(dest, "gas-report.json"), collectGasReport(v, out, cache));
    console.log("  gas report: done\n");
}

await import("./report.ts");
