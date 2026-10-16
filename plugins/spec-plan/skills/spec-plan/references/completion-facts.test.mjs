// node --test skills/spec-plan/references/completion-facts.test.mjs
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { collectFacts, globToRegExp } from "./completion-facts.mjs";

const git = (cwd, ...a) => execFileSync("git", ["-c", "user.email=t@t", "-c", "user.name=t", ...a], { cwd, encoding: "utf8" }).trim();
const put = (root, path, text = "x\n") => {
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), text);
};

const SPEC = `# Feature

## Packages

### P0 · Backend: api (R1 · 12345, wave 1)
- Lane: \`backend\`
- ownedFiles:
  - \`src/api.ts\`
  - \`src/never-touched.ts\`
- Acceptance criteria:
  1. It works.

### P1 · Frontend: ui (R1 · 12345, wave 1)
- Lane: \`frontend\`
- ownedFiles:
  - \`web/**/*.tsx\`
- Acceptance criteria:
  1. It renders.
`;

test("globToRegExp handles * and **", () => {
    assert.ok(globToRegExp("web/**/*.tsx").test("web/a/b/c.tsx"));
    assert.ok(!globToRegExp("web/*.tsx").test("web/a/c.tsx"));
});

test("reports touched, untouched and out-of-scope files since base", () => {
    const root = mkdtempSync(join(tmpdir(), "facts-"));
    git(root, "init", "-q");
    put(root, "Docs/F/Specs/spec.md", SPEC);
    put(root, "src/api.ts");
    git(root, "add", "-A");
    git(root, "commit", "-qm", "base");
    const base = git(root, "rev-parse", "HEAD");

    put(root, "src/api.ts", "changed\n"); // owned, committed below
    put(root, "web/x/Button.tsx"); // owned by glob, untracked
    put(root, "src/extra.ts"); // not owned by anyone
    put(root, "Docs/F/Specs/spec.md", SPEC + "\n## Completion\n"); // spec itself is ignored
    git(root, "add", "src/api.ts");
    git(root, "commit", "-qm", "work");

    const facts = collectFacts("Docs/F/Specs/spec.md", { base, cwd: root, reportingDir: root });
    const [p0, p1] = facts.packages;
    assert.deepEqual(p0.touched, ["src/api.ts"]);
    assert.deepEqual(p0.untouched, ["src/never-touched.ts"]);
    assert.deepEqual(p1.touched, ["web/x/Button.tsx"]);
    assert.deepEqual(facts.outsideOwned, ["src/extra.ts"]);
    assert.equal(facts.baseSource, "argument");
    assert.equal(facts.uncommitted, true);
});

test("uses the sha recorded when the spec was approved", () => {
    const root = mkdtempSync(join(tmpdir(), "facts-"));
    git(root, "init", "-q");
    put(root, "Docs/F/Specs/spec.md", SPEC);
    git(root, "add", "-A");
    git(root, "commit", "-qm", "base");
    const sha = git(root, "rev-parse", "--short", "HEAD");
    const repo = root.split("/").pop();
    writeFileSync(join(root, "specs.jsonl"), [
        JSON.stringify({ event: "SpecWritten", repo, spec_path: "Docs/F/Specs/spec.md", approved: false, git_sha: "0000000" }),
        JSON.stringify({ event: "SpecWritten", repo, spec_path: "Docs/F/Specs/spec.md", approved: true, git_sha: sha }),
    ].join("\n"));
    const facts = collectFacts("Docs/F/Specs/spec.md", { cwd: root, reportingDir: root });
    assert.equal(facts.base, sha);
    assert.equal(facts.baseSource, "approval");
});
