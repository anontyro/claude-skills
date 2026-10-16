#!/usr/bin/env node
// Deterministic facts for a spec's Completion section: what changed since the
// spec was approved, per package, and which changes no package owned.
// Usage: node completion-facts.mjs <spec.md> [--base <sha>]   (run from the repo)
// Prints JSON. Base commit, first match wins: --base; the git sha recorded in
// specs.jsonl when the spec was first written as approved; the merge-base with
// the default branch.
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, realpathSync } from "node:fs";
import { homedir } from "node:os";
import { basename, join, relative, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { parsePackages } from "./validate-spec.mjs";

const git = (cwd, ...args) => execFileSync("git", args, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim();

export function globToRegExp(glob) {
    const escaped = glob.replace(/[.+^${}()|[\]\\]/g, "\\$&").replace(/\*\*/g, "\u0000").replace(/\*/g, "[^/]*").replace(/\u0000/g, ".*");
    return new RegExp(`^${escaped}$`);
}

function approvedSha(specRel, repoName, reportingDir) {
    const file = join(reportingDir, "specs.jsonl");
    if (!existsSync(file)) return null;
    for (const line of readFileSync(file, "utf8").split("\n")) {
        try {
            const row = JSON.parse(line);
            if (row.event === "SpecWritten" && row.approved && row.spec_path === specRel && row.repo === repoName && row.git_sha) return row.git_sha;
        } catch { /* skip bad lines */ }
    }
    return null;
}

function defaultBranchBase(repo) {
    for (const ref of ["origin/HEAD", "main", "master"]) {
        try {
            return git(repo, "merge-base", "HEAD", ref);
        } catch { /* try next */ }
    }
    return null;
}

export function collectFacts(specPath, { base, cwd = process.cwd(), reportingDir = process.env.CLAUDE_REPORTING_DIR || join(homedir(), ".claude", "reporting") } = {}) {
    const repo = git(cwd, "rev-parse", "--show-toplevel");
    const specRel = relative(realpathSync(repo), realpathSync(resolve(cwd, specPath))).split("\\").join("/");
    const text = readFileSync(resolve(repo, specRel), "utf8");

    let baseSource = "argument";
    if (!base) {
        base = approvedSha(specRel, basename(repo), reportingDir);
        baseSource = "approval";
    }
    if (!base) {
        base = defaultBranchBase(repo);
        baseSource = "merge-base";
    }
    if (!base) throw new Error("No base commit: pass --base <sha>");

    const changed = new Map();
    for (const line of git(repo, "diff", "--name-status", "--no-renames", base).split("\n").filter(Boolean)) {
        const [status, ...rest] = line.split("\t");
        changed.set(rest.join("\t"), status);
    }
    for (const path of git(repo, "ls-files", "-o", "--exclude-standard").split("\n").filter(Boolean)) changed.set(path, "A");
    changed.delete(specRel);

    const changedPaths = [...changed.keys()];
    const packages = parsePackages(text).map(p => {
        const patterns = p.files.map(f => ({ file: f, re: globToRegExp(f) }));
        return {
            id: p.id,
            ownedFiles: p.files,
            touched: changedPaths.filter(c => patterns.some(x => x.re.test(c))),
            untouched: patterns.filter(x => !changedPaths.some(c => x.re.test(c))).map(x => x.file),
            criteria: p.criteria,
        };
    });
    const owned = packages.flatMap(p => p.ownedFiles).map(globToRegExp);
    return {
        specPath: specRel,
        base,
        baseSource,
        head: git(repo, "rev-parse", "--short", "HEAD"),
        uncommitted: git(repo, "status", "--porcelain").length > 0,
        changed: changedPaths.map(p => ({ status: changed.get(p), path: p })),
        packages,
        outsideOwned: changedPaths.filter(c => !owned.some(re => re.test(c))),
    };
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
    const args = process.argv.slice(2);
    const spec = args.find((a, i) => !a.startsWith("--") && args[i - 1] !== "--base");
    if (!spec) {
        console.error("Usage: node completion-facts.mjs <spec.md> [--base <sha>]");
        process.exit(2);
    }
    const baseIdx = args.indexOf("--base");
    try {
        console.log(JSON.stringify(collectFacts(spec, { base: baseIdx >= 0 ? args[baseIdx + 1] : undefined }), null, 2));
    } catch (e) {
        console.error(e.message);
        process.exit(1);
    }
}
