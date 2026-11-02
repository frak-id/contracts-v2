#!/usr/bin/env bun
/**
 * Render bench/solar/results/REPORT.md from the JSON written by run.ts.
 * Can be re-run on its own: `bun run bench/solar/report.ts`
 */
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";

const RESULTS_DIR = resolve(import.meta.dir, "results");
const BASELINE = "solc";

type Meta = {
    date: string;
    gitCommit: string;
    forge: string;
    solar: string;
    runs: number;
    machine: { os: string; cpu: string; cores: number; memGiB: number };
    variants: { id: string; label: string; args: string; runs: number }[];
};
type Build = { files: number | null; samples: { wallMs: number; compilerMs: number | null; rssBytes: number | null }[] };
type Incremental = { file: string; files: number | null; samples: { wallMs: number; compilerMs: number | null }[] };
type Sizes = Record<
    string,
    { source: string; kind?: string; runtime: number; init: number; compiler: string; evmVersion?: string }
>;
type Tests = {
    wallMs: number;
    exitCode: number;
    tests: Record<string, { status: string; reason: string | null; kind: string; gas: number | null }>;
};
type GasReport = {
    contract: string;
    deployment: { gas: number; size: number };
    functions: Record<string, { calls: number; min: number; mean: number; median: number; max: number }>;
}[];

const readJson = <T>(...p: string[]): T => JSON.parse(readFileSync(join(RESULTS_DIR, ...p), "utf8"));

const meta = readJson<Meta>("meta.json");
const variants = meta.variants.filter((v) => existsSync(join(RESULTS_DIR, v.id, "build.json")));
const others = variants.filter((v) => v.id !== BASELINE);
/// Internal-only libraries compile to a ~20-byte stub that only reverts: keep them out of the size stats
const deployableOnly = (sizes: Sizes): Sizes =>
    Object.fromEntries(Object.entries(sizes).filter(([, s]) => s.kind !== "library"));
const data = Object.fromEntries(
    variants.map((v) => [
        v.id,
        {
            build: readJson<Build>(v.id, "build.json"),
            incremental: existsSync(join(RESULTS_DIR, v.id, "incremental.json"))
                ? readJson<Incremental>(v.id, "incremental.json")
                : null,
            sizes: deployableOnly(readJson<Sizes>(v.id, "sizes.json")),
            tests: readJson<Tests>(v.id, "tests.json"),
            gas: readJson<GasReport>(v.id, "gas-report.json"),
        },
    ])
);
const base = data[BASELINE];
const label = (id: string) => variants.find((v) => v.id === id)?.label ?? id;

/* -------------------------------------------------------------------------- */
/*                                    Stats                                   */
/* -------------------------------------------------------------------------- */

const median = (xs: number[]) => {
    const s = [...xs].sort((a, b) => a - b);
    const m = Math.floor(s.length / 2);
    return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};
/// Geometric mean of new/old ratios, pairs with a zero on either side are skipped
const geomeanRatio = (pairs: [number, number][]) => {
    const valid = pairs.filter(([a, b]) => a > 0 && b > 0);
    if (!valid.length) return null;
    return Math.exp(valid.reduce((acc, [a, b]) => acc + Math.log(b / a), 0) / valid.length);
};
const fmtInt = (n: number | null | undefined) => (n == null ? "–" : Math.round(n).toLocaleString("en-US"));
const fmtMs = (ms: number | null | undefined) =>
    ms == null ? "–" : ms >= 1000 ? `${(ms / 1000).toFixed(2)} s` : `${ms.toFixed(0)} ms`;
const fmtPct = (ratio: number | null) => {
    if (ratio == null) return "–";
    const pct = (ratio - 1) * 100;
    if (Math.abs(pct) < 0.05) return "0.0%";
    return `${pct > 0 ? "+" : ""}${pct.toFixed(1)}%`;
};
const delta = (a: number | null | undefined, b: number | null | undefined) =>
    a == null || b == null || a === 0 ? "–" : fmtPct(b / a);
const count = (pairs: [number, number][]) => ({
    better: pairs.filter(([a, b]) => b < a).length,
    worse: pairs.filter(([a, b]) => b > a).length,
    same: pairs.filter(([a, b]) => a === b).length,
});

/* -------------------------------------------------------------------------- */
/*                                  Sections                                  */
/* -------------------------------------------------------------------------- */

const lines: string[] = [];
const push = (...l: string[]) => lines.push(...l);

const srcGas = (id: string) => data[id].gas.filter((c) => c.contract.startsWith("src/"));
const gasByContract = (id: string) => Object.fromEntries(srcGas(id).map((c) => [c.contract, c]));

/// [baseline, other] pairs for a metric, over keys present on both sides
function pairs<T>(a: Record<string, T>, b: Record<string, T>, f: (x: T) => number | null): [number, number][] {
    return Object.keys(a)
        .filter((k) => k in b)
        .map((k) => [f(a[k]), f(b[k])] as [number | null, number | null])
        .filter((p): p is [number, number] => p[0] != null && p[1] != null);
}

function functionPairs(id: string): [number, number][] {
    const a = gasByContract(BASELINE);
    const b = gasByContract(id);
    const out: [number, number][] = [];
    for (const [contract, c] of Object.entries(a)) {
        const o = b[contract];
        if (!o) continue;
        for (const [fn, g] of Object.entries(c.functions)) {
            const og = o.functions[fn];
            if (og) out.push([g.median, og.median]);
        }
    }
    return out;
}

function testPairs(id: string): [number, number][] {
    const a = base.tests.tests;
    const b = data[id].tests.tests;
    return Object.keys(a)
        .filter((k) => b[k] && a[k].status === "Success" && b[k].status === "Success" && a[k].gas && b[k].gas)
        .map((k) => [a[k].gas as number, b[k].gas as number]);
}

const statusCounts = (t: Tests) =>
    Object.values(t.tests).reduce<Record<string, number>>((acc, x) => {
        acc[x.status] = (acc[x.status] ?? 0) + 1;
        return acc;
    }, {});

// Header
const anySize = Object.values(base.sizes)[0];
push(
    "# Solar vs solc benchmark",
    "",
    "Generated by `bench/solar/run.ts` (see `bench/solar/README.md` for the methodology and caveats).",
    "",
    "| | |",
    "|---|---|",
    `| Date | ${meta.date} |`,
    `| Commit | \`${meta.gitCommit.slice(0, 10)}\` |`,
    `| forge | \`${meta.forge}\` |`,
    `| Solar | \`${meta.solar}\` |`,
    `| solc | \`${anySize?.compiler ?? "?"}\` |`,
    `| Settings | foundry.toml defaults: optimizer on, \`optimizer_runs = 100_000\`, EVM \`${anySize?.evmVersion ?? "?"}\` |`,
    `| Machine | ${meta.machine.cpu}, ${meta.machine.cores} cores, ${meta.machine.memGiB} GiB, ${meta.machine.os} |`,
    ""
);

// Summary
push("## Summary", "");
const baseBuild = median(base.build.samples.map((s) => s.wallMs));
const speedup = (ratio: number) => (ratio >= 1 ? `${ratio.toFixed(1)}× faster` : `${(1 / ratio).toFixed(1)}× slower`);
const incrementalWall = (id: string) => {
    const inc = data[id].incremental;
    return inc?.samples.length ? median(inc.samples.map((s) => s.wallMs)) : null;
};
for (const v of others) {
    const d = data[v.id];
    const wall = median(d.build.samples.map((s) => s.wallMs));
    const speed = `**${speedup(baseBuild / wall)}**`;
    const baseInc = incrementalWall(BASELINE);
    const inc = incrementalWall(v.id);
    const rt = geomeanRatio(pairs(base.sizes, d.sizes, (x) => x.runtime));
    const init = geomeanRatio(pairs(base.sizes, d.sizes, (x) => x.init));
    const deploy = geomeanRatio(pairs(gasByContract(BASELINE), gasByContract(v.id), (x) => x.deployment.gas));
    const fnPairs = functionPairs(v.id);
    const fn = geomeanRatio(fnPairs);
    const fnCount = count(fnPairs);
    const tp = testPairs(v.id);
    const sc = statusCounts(d.tests);
    const bc = statusCounts(base.tests);
    push(
        `### ${v.label} vs ${label(BASELINE)}`,
        "",
        `- Clean build (wall, median): ${fmtMs(baseBuild)} → ${fmtMs(wall)}, ${speed}`,
        ...(baseInc && inc
            ? [
                  `- Rebuild after editing \`${d.incremental?.file}\` (wall, median): ${fmtMs(baseInc)} → ${fmtMs(inc)}, ${speedup(baseInc / inc)}`,
              ]
            : []),
        ...others
            .filter((o) => o.id !== v.id && v.id === "solar")
            .map(
                (o) =>
                    `- Clean build vs ${o.label}: ${fmtMs(median(data[o.id].build.samples.map((s) => s.wallMs)))} → ${fmtMs(wall)}, ${speedup(median(data[o.id].build.samples.map((s) => s.wallMs)) / wall)}`
            ),
        `- Tests: ${bc.Success ?? 0} passed / ${bc.Failure ?? 0} failed → ${sc.Success ?? 0} passed / ${sc.Failure ?? 0} failed`,
        `- \`src/\` runtime bytecode size (geomean): ${fmtPct(rt)}, init code size: ${fmtPct(init)}`,
        `- \`src/\` deployment gas (geomean, gas report): ${fmtPct(deploy)}`,
        `- \`src/\` function gas (geomean of medians, ${fnPairs.length} functions): ${fmtPct(fn)} (${fnCount.better} cheaper, ${fnCount.worse} more expensive, ${fnCount.same} equal)`,
        `- Per-test gas (geomean, ${tp.length} tests passing on both, test code compiled by the same compiler): ${fmtPct(geomeanRatio(tp))}`,
        ""
    );
}

// Build time
push(
    "## Build time",
    "",
    "`forge build --force` on the whole project (src + test + script + deps), lint-on-build disabled.",
    "",
    "| Variant | Files | Runs | Compiler time (median) | Wall time (median) | Wall min–max | Peak RSS (median) | vs solc |",
    "|---|---:|---:|---:|---:|---:|---:|---:|"
);
for (const v of variants) {
    const b = data[v.id].build;
    const walls = b.samples.map((s) => s.wallMs);
    const comp = b.samples.map((s) => s.compilerMs).filter((x): x is number => x != null);
    const rss = b.samples.map((s) => s.rssBytes).filter((x): x is number => x != null);
    const wall = median(walls);
    const ratio = baseBuild / wall;
    push(
        `| ${v.label} | ${b.files ?? "–"} | ${b.samples.length} | ${fmtMs(comp.length ? median(comp) : null)} | ${fmtMs(wall)} | ${fmtMs(Math.min(...walls))} – ${fmtMs(Math.max(...walls))} | ${rss.length ? `${(median(rss) / 2 ** 20).toFixed(0)} MiB` : "–"} | ${v.id === BASELINE ? "1.0×" : speedup(ratio)} |`
    );
}
push("");

const incFile = variants.map((v) => data[v.id].incremental?.file).find(Boolean);
if (incFile) {
    push(
        `### Rebuild after an edit`,
        "",
        `Warm cache, a comment appended to \`${incFile}\`: forge recompiles it and every file importing it.`,
        "",
        "| Variant | Files recompiled | Runs | Compiler time (median) | Wall time (median) | vs solc |",
        "|---|---:|---:|---:|---:|---:|"
    );
    const baseInc = incrementalWall(BASELINE);
    for (const v of variants) {
        const inc = data[v.id].incremental;
        if (!inc?.samples.length) continue;
        const wall = median(inc.samples.map((s) => s.wallMs));
        const comp = inc.samples.map((s) => s.compilerMs).filter((x): x is number => x != null);
        push(
            `| ${v.label} | ${inc.files ?? "–"} | ${inc.samples.length} | ${fmtMs(comp.length ? median(comp) : null)} | ${fmtMs(wall)} | ${v.id === BASELINE || !baseInc ? "1.0×" : speedup(baseInc / wall)} |`
        );
    }
    push("");
}

// Tests
push(
    "## Test suite",
    "",
    "| Variant | Passed | Failed | Skipped | `forge test` wall time (cached build) |",
    "|---|---:|---:|---:|---:|"
);
for (const v of variants) {
    const t = data[v.id].tests;
    const c = statusCounts(t);
    push(`| ${v.label} | ${c.Success ?? 0} | ${c.Failure ?? 0} | ${c.Skipped ?? 0} | ${fmtMs(t.wallMs)} |`);
}
push("");
for (const v of others) {
    const a = base.tests.tests;
    const b = data[v.id].tests.tests;
    const diff = [...new Set([...Object.keys(a), ...Object.keys(b)])].filter((k) => a[k]?.status !== b[k]?.status);
    if (!diff.length) {
        push(`No test changes status between ${label(BASELINE)} and ${v.label}.`, "");
        continue;
    }
    push(
        `Tests whose status differs between ${label(BASELINE)} and ${v.label}:`,
        "",
        `| Test | ${label(BASELINE)} | ${v.label} | Reason |`,
        "|---|---|---|---|"
    );
    for (const k of diff) {
        const reason = (b[k]?.reason ?? a[k]?.reason ?? "").replace(/\|/g, "\\|").replace(/\n/g, " ");
        push(`| \`${k}\` | ${a[k]?.status ?? "–"} | ${b[k]?.status ?? "–"} | ${reason} |`);
    }
    push("");
}

// Generic per-contract table: baseline column + (value, delta) per other variant
function variantHeader(metric: string) {
    const cols = [`${label(BASELINE)} ${metric}`, ...others.flatMap((v) => [`${v.label} ${metric}`, "Δ"])];
    return [`| Contract | ${cols.join(" | ")} |`, `|---|${cols.map(() => "---:").join("|")}|`];
}

// Sizes
for (const [metric, f] of [
    ["runtime", (x: Sizes[string]) => x.runtime],
    ["init", (x: Sizes[string]) => x.init],
] as const) {
    push(
        `## Bytecode size: ${metric} (bytes, \`src/\` contracts)`,
        "",
        "Libraries are left out: with internal functions only, they compile to a stub that is never deployed.",
        "",
        ...variantHeader(metric)
    );
    for (const key of Object.keys(base.sizes).sort()) {
        const a = f(base.sizes[key]);
        const cells = others.flatMap((v) => {
            const s = data[v.id].sizes[key];
            const b = s ? f(s) : null;
            return [fmtInt(b), delta(a, b)];
        });
        push(`| ${key.split(":")[1]} | ${fmtInt(a)} | ${cells.join(" | ")} |`);
    }
    const geo = others.flatMap((v) => ["", fmtPct(geomeanRatio(pairs(base.sizes, data[v.id].sizes, f)))]);
    push(`| **geomean** | | ${geo.join(" | ")} |`, "");
}

// Deployment gas
push(
    "## Deployment gas (`forge test --gas-report`, `src/` contracts deployed by the tests)",
    "",
    ...variantHeader("gas")
);
const baseGas = gasByContract(BASELINE);
for (const key of Object.keys(baseGas).sort()) {
    const a = baseGas[key].deployment.gas;
    const cells = others.flatMap((v) => {
        const b = gasByContract(v.id)[key]?.deployment.gas;
        return [fmtInt(b), delta(a, b)];
    });
    push(`| ${key.split(":")[1]} | ${fmtInt(a)} | ${cells.join(" | ")} |`);
}
const deployGeo = others.flatMap((v) => [
    "",
    fmtPct(geomeanRatio(pairs(baseGas, gasByContract(v.id), (x) => x.deployment.gas))),
]);
push(`| **geomean** | | ${deployGeo.join(" | ")} |`, "");

// Function gas
push(
    "## Function gas (`forge test --gas-report` median, `src/` contracts)",
    "",
    "Unit tests drive the same calls on every variant. Call counts flagged with ⚠️ differ because forge seeds its " +
        "fuzz dictionary with constants found in the bytecode: different bytecode, different fuzz inputs.",
    ""
);
for (const key of Object.keys(baseGas).sort()) {
    const fns = baseGas[key].functions;
    if (!Object.keys(fns).length) continue;
    const contractPairs = others.map((v) => {
        const o = gasByContract(v.id)[key];
        return Object.entries(fns)
            .filter(([fn]) => o?.functions[fn])
            .map(([fn, g]) => [g.median, o.functions[fn].median] as [number, number]);
    });
    const summary = others.map((v, i) => `${v.label} ${fmtPct(geomeanRatio(contractPairs[i]))}`).join(", ");
    push(
        "<details>",
        `<summary><b>${key.split(":")[1]}</b>: ${Object.keys(fns).length} functions, geomean ${summary}</summary>`,
        "",
        `| Function | Calls | ${label(BASELINE)} | ${others.flatMap((v) => [v.label, "Δ"]).join(" | ")} |`,
        `|---|---:|---:|${others.map(() => "---:|---:").join("|")}|`
    );
    for (const [fn, g] of Object.entries(fns).sort(([x], [y]) => x.localeCompare(y))) {
        const cells = others.flatMap((v) => {
            const og = gasByContract(v.id)[key]?.functions[fn];
            const warn = og && og.calls !== g.calls ? ` ⚠️ ${og.calls} calls` : "";
            return [`${fmtInt(og?.median)}${warn}`, delta(g.median, og?.median)];
        });
        push(`| \`${fn}\` | ${g.calls} | ${fmtInt(g.median)} | ${cells.join(" | ")} |`);
    }
    push("", "</details>", "");
}

// Per-test gas extremes
for (const v of others) {
    const a = base.tests.tests;
    const b = data[v.id].tests.tests;
    const rows = Object.keys(a)
        .filter((k) => b[k] && a[k].status === "Success" && b[k].status === "Success" && a[k].gas && b[k].gas)
        .map((k) => ({ k, a: a[k].gas as number, b: b[k].gas as number, r: (b[k].gas as number) / (a[k].gas as number) }))
        .sort((x, y) => x.r - y.r);
    const table = (title: string, xs: typeof rows) => {
        push(
            `#### ${title}`,
            "",
            `| Test | ${label(BASELINE)} | ${v.label} | Δ |`,
            "|---|---:|---:|---:|",
            ...xs.map(
                (x) => `| \`${x.k.split(":").slice(1).join(":")}\` | ${fmtInt(x.a)} | ${fmtInt(x.b)} | ${fmtPct(x.r)} |`
            ),
            ""
        );
    };
    const c = count(rows.map((x) => [x.a, x.b]));
    push(
        `## Per-test gas: ${v.label} vs ${label(BASELINE)}`,
        "",
        `${rows.length} tests passing on both sides: ${c.better} cheaper, ${c.worse} more expensive, ${c.same} equal. ` +
            "Test contracts are compiled by the same compiler as `src/`, so this mixes harness and contract gas. Fuzz tests use the median gas.",
        ""
    );
    table("Largest savings", rows.slice(0, 10));
    table("Largest regressions", rows.slice(-10).reverse().filter((x) => x.r > 1));
}

writeFileSync(join(RESULTS_DIR, "REPORT.md"), `${lines.join("\n")}\n`);
console.log(`Wrote ${join(RESULTS_DIR, "REPORT.md")}`);
