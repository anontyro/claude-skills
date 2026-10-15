#!/usr/bin/env node
// Checks a spec-plan spec for the structure the builders and reviewers rely on.
// Usage: node validate-spec.mjs <spec.md> [--json]   (run from the repo root)
// Exit 0 = no errors (warnings allowed), 1 = errors, 2 = bad usage.
import { existsSync, readFileSync } from "node:fs";
import { basename, dirname, isAbsolute, join, relative, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const MAX_RELEASE_FILES = 30;
const REQUIRED_SECTIONS = ["Goal", "Decisions", "Non-goals", "Lanes", "Packages"];

// Package headings look like: ### P4a · Frontend: what (R1b · 12345, wave 3)
const PACKAGE_HEADING = /^### (P\d+[a-z]?) · (.*)$/;
const WORK_ITEM = /\b\d{3,}\b|\b[A-Z][A-Z0-9]*-\d+\b/; // 12345 or PROJ-123

export function parsePackages(text) {
    const lines = text.split(/\r?\n/);
    const packages = [];
    let current = null;
    let mode = null;
    for (const line of lines) {
        const heading = line.match(PACKAGE_HEADING);
        if (heading) {
            const tail = heading[2].match(/\(([^()]*)\)\s*$/);
            const meta = tail ? tail[1] : "";
            const wave = meta.match(/\bwave (\d+)/);
            current = {
                id: heading[1],
                meta,
                wave: wave ? Number(wave[1]) : null,
                releases: [...meta.matchAll(/\b(R\d+[a-z]?)\b/g)].map(m => m[1]),
                hasWorkItem: WORK_ITEM.test(meta),
                files: [],
                criteria: 0,
                hasOwnedFiles: false,
            };
            packages.push(current);
            mode = null;
            continue;
        }
        if (!current) continue;
        if (/^#{1,3} /.test(line)) {
            current = null;
            continue;
        }
        if (/^- ownedFiles/.test(line)) {
            current.hasOwnedFiles = true;
            mode = "files";
            continue;
        }
        if (/^- Acceptance criteria/.test(line)) {
            mode = "criteria";
            continue;
        }
        if (mode === "files" && /^\s+- /.test(line)) {
            for (const m of line.matchAll(/`([^`]+\.[A-Za-z*]+)`/g)) current.files.push(m[1]);
        } else if (mode === "criteria" && /^\s+\d+\. /.test(line)) {
            current.criteria++;
        }
    }
    return packages;
}

// Release summary blocks: > **R1b · task 12345 · ~19 files: ...
export function parseReleaseSummaries(text) {
    const summaries = new Map();
    for (const m of text.matchAll(/^> \*\*(R\d+[a-z]?) · ([^\n]*)/gm)) {
        const files = m[2].match(/~(\d+) files/);
        summaries.set(m[1], { files: files ? Number(files[1]) : null, hasWorkItem: WORK_ITEM.test(m[2]) });
    }
    return summaries;
}

// Waves table rows: | 3 | P4a, P5 | R1b (12345) | ... |
export function parseWavesTable(text) {
    const waves = new Map();
    for (const m of text.matchAll(/^\| (\d+) \| ((?:P\d+[a-z]?(?:, )?)+) \|/gm)) {
        for (const id of m[2].split(/,\s*/)) waves.set(id.trim(), Number(m[1]));
    }
    return waves;
}

function section(text, name) {
    const m = text.match(new RegExp(`^## ${name}\\s*$([\\s\\S]*?)(?=^## |(?![\\s\\S]))`, "m"));
    return m ? m[1] : null;
}

export function validateSpec(specPath, repoRoot = process.cwd()) {
    const errors = [];
    const warnings = [];
    const absolute = resolve(repoRoot, specPath);
    const fromRoot = relative(repoRoot, absolute);
    // Only Markdown files inside the repo: the path comes from the command line.
    if (fromRoot.startsWith("..") || isAbsolute(fromRoot) || !absolute.endsWith(".md")) {
        return { errors: [`Spec must be a .md file inside ${repoRoot}: ${specPath}`], warnings };
    }
    if (!existsSync(absolute)) return { errors: [`Spec not found: ${specPath}`], warnings };
    const text = readFileSync(absolute, "utf8");
    const rel = fromRoot.split("\\").join("/");

    // Location: Docs/<Feature>/Specs/<yyyy-MM-dd>-<PBI#>-<slug>.md
    const location = rel.match(/^Docs\/([A-Z][A-Za-z0-9]*)\/Specs\/(\d{4}-\d{2}-\d{2}-[A-Za-z0-9]+(?:-\d+)?-[a-z0-9-]+)\.md$/);
    if (!location) errors.push(`Location: expected Docs/<Feature>/Specs/<yyyy-MM-dd>-<PBI#>-<slug>.md, got ${rel}`);
    const featureDir = dirname(dirname(absolute));

    for (const name of REQUIRED_SECTIONS) {
        if (section(text, name) === null) errors.push(`Missing section: ## ${name}`);
    }

    // Manual testing and decisions live next to the spec.
    const testing = text.match(/^Manual testing: `([^`]+)`/m);
    if (!testing) errors.push("Header: no `Manual testing:` line");
    else {
        if (!/\/Testing\/MANUAL-TESTING-[A-Za-z0-9]+(?:-\d+)?-[^/]+\.md$/.test(testing[1])) errors.push(`Manual testing doc should be in Docs/<Feature>/Testing/: ${testing[1]}`);
        if (!existsSync(resolve(repoRoot, testing[1]))) errors.push(`Manual testing doc does not exist: ${testing[1]}`);
    }
    const decisionsReadme = join(featureDir, "Decisions", "README.md");
    if (!existsSync(decisionsReadme)) errors.push(`Missing ${relative(repoRoot, decisionsReadme)}`);

    const packages = parsePackages(text);
    if (packages.length === 0) errors.push("Packages: no `### P<n> · ...` headings found");
    const waves = parseWavesTable(text);
    for (const p of packages) {
        if (p.wave === null) errors.push(`${p.id}: heading has no "wave N" in its trailing (...)`);
        if (!p.hasWorkItem) errors.push(`${p.id}: heading has no work item number`);
        if (!p.hasOwnedFiles || p.files.length === 0) errors.push(`${p.id}: no ownedFiles`);
        if (p.criteria === 0) errors.push(`${p.id}: no numbered acceptance criteria`);
        if (waves.size && p.wave !== null && waves.get(p.id) !== p.wave) {
            errors.push(`${p.id}: heading says wave ${p.wave}, waves table says ${waves.get(p.id) ?? "nothing"}`);
        }
    }

    // Packages sharing a wave must not share a file.
    for (let i = 0; i < packages.length; i++) {
        for (let j = i + 1; j < packages.length; j++) {
            const [a, b] = [packages[i], packages[j]];
            if (a.wave === null || a.wave !== b.wave) continue;
            const shared = a.files.filter(f => b.files.includes(f));
            if (shared.length) errors.push(`Wave ${a.wave}: ${a.id} and ${b.id} both own ${shared.join(", ")}`);
        }
    }

    // Every release a package names has a summary block, sized within the limit.
    const summaries = parseReleaseSummaries(text);
    const releases = new Set(packages.flatMap(p => p.releases));
    for (const r of releases) {
        const s = summaries.get(r);
        if (!s) {
            errors.push(`${r}: no release summary block (> **${r} · ...)`);
            continue;
        }
        if (s.files === null) errors.push(`${r}: summary has no "~N files" estimate`);
        else if (s.files > MAX_RELEASE_FILES) warnings.push(`${r}: ~${s.files} files is over ${MAX_RELEASE_FILES}; consider splitting into ${r}a/${r}b`);
        if (!s.hasWorkItem) errors.push(`${r}: summary names no work item`);
    }

    // Every planned decision record is either written or owned by a package.
    if (existsSync(decisionsReadme)) {
        const owned = new Set(packages.flatMap(p => p.files.map(f => basename(f))));
        for (const m of readFileSync(decisionsReadme, "utf8").matchAll(/\[(\d{4})\]\(([^)]+\.md)\)/g)) {
            const file = basename(m[2]);
            if (!existsSync(join(featureDir, "Decisions", file)) && !owned.has(file)) {
                errors.push(`Decision ${m[1]} (${file}) is neither written nor in any package's ownedFiles`);
            }
        }
    }

    // An approved spec has no open questions.
    if (/^Status: \*\*approved/m.test(text)) {
        const open = section(text, "Open questions");
        if (open && /^- \*\*Q/m.test(open)) errors.push("Status is approved but ## Open questions still lists questions");
    }

    return { errors, warnings, packages: packages.length, releases: [...releases] };
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
    const args = process.argv.slice(2);
    const spec = args.find(a => !a.startsWith("--"));
    if (!spec) {
        console.error("Usage: node validate-spec.mjs <spec.md> [--json]");
        process.exit(2);
    }
    const result = validateSpec(spec);
    if (args.includes("--json")) console.log(JSON.stringify(result, null, 2));
    else {
        for (const e of result.errors) console.log(`ERROR   ${e}`);
        for (const w of result.warnings) console.log(`WARNING ${w}`);
        console.log(`${result.errors.length} error(s), ${result.warnings.length} warning(s); ${result.packages ?? 0} packages, releases ${(result.releases ?? []).join(", ")}`);
    }
    process.exit(result.errors.length ? 1 : 0);
}
