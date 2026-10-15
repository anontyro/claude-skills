// node --test skills/spec-plan/references/validate-spec.test.mjs
// Builds a minimal valid feature folder, then breaks one rule per test.
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import test from "node:test";
import assert from "node:assert/strict";
import { validateSpec } from "./validate-spec.mjs";

const SPEC = "Docs/Demo/Specs/2026-01-01-12345-demo.md";

const validSpec = () => `# Demo

PBI: 12345.
Status: **approved 2026-01-01**.
Manual testing: \`Docs/Demo/Testing/MANUAL-TESTING-12345-demo.md\`.

## Goal

Something.

## Decisions

### R1 · First

> **R1 · task 12346 · ~4 files: ~2 new, ~2 modified · packages P1, P2**

## Non-goals

- Nothing.

## Lanes

| Lane | Touched | Checks |
|---|---|---|

## Packages

| Wave | Packages | Release | Note |
|---|---|---|---|
| 1 | P1 | R1 (12346) | |
| 2 | P2 | R1 (12346) | |

### P1 · Static: one (R1 · 12346, wave 1)
- Lane: \`static\`
- ownedFiles:
  - \`src/a.ts\`
  - \`Docs/Demo/Decisions/0001-a-rule.md\` (new)
- Acceptance criteria:
  1. Works.

### P2 · Static: two (R1 · 12346, wave 2)
- Lane: \`static\`
- ownedFiles:
  - \`src/a.ts\`
- Acceptance criteria:
  1. Works.

## Open questions

None.
`;

function repoWith(specText, { readme = "| [0001](0001-a-rule.md) | A rule |\n", testingDoc = true } = {}) {
    const root = mkdtempSync(join(tmpdir(), "spec-validate-"));
    for (const dir of ["Specs", "Decisions", "Testing"]) mkdirSync(join(root, "Docs/Demo", dir), { recursive: true });
    writeFileSync(join(root, SPEC), specText);
    writeFileSync(join(root, "Docs/Demo/Decisions/README.md"), readme);
    if (testingDoc) writeFileSync(join(root, "Docs/Demo/Testing/MANUAL-TESTING-12345-demo.md"), "# t\n");
    return root;
}

const run = (text, options) => validateSpec(SPEC, repoWith(text, options));
const hasError = (result, fragment) => assert.ok(result.errors.some(e => e.includes(fragment)), `expected an error containing "${fragment}", got ${JSON.stringify(result.errors)}`);

test("a valid spec passes", () => {
    const result = run(validSpec());
    assert.deepEqual(result.errors, []);
    assert.deepEqual(result.warnings, []);
});

test("wrong location", () => {
    const root = repoWith(validSpec());
    writeFileSync(join(root, "Docs/plan.md"), validSpec());
    hasError(validateSpec("Docs/plan.md", root), "Location");
});

test("packages in one wave sharing a file", () => {
    hasError(run(validSpec().replace("(R1 · 12346, wave 2)", "(R1 · 12346, wave 1)").replace("| 2 | P2 |", "| 1 | P2 |")), "both own src/a.ts");
});

test("heading wave disagreeing with the waves table", () => {
    hasError(run(validSpec().replace("| 2 | P2 |", "| 3 | P2 |")), "waves table says 3");
});

test("missing release summary", () => {
    hasError(run(validSpec().replace(/^> \*\*R1 .*$/m, "")), "no release summary block");
});

test("oversized release is a warning, not an error", () => {
    const result = run(validSpec().replace("~4 files", "~42 files"));
    assert.deepEqual(result.errors, []);
    assert.ok(result.warnings.some(w => w.includes("over 30")));
});

test("heading without work item or wave", () => {
    const result = run(validSpec().replace("(R1 · 12346, wave 1)", "(R1)"));
    hasError(result, 'no "wave N"');
    hasError(result, "no work item");
});

test("package without acceptance criteria or files", () => {
    hasError(run(validSpec().replace("  1. Works.\n\n### P2", "\n### P2")), "P1: no numbered acceptance criteria");
    hasError(run(validSpec().replace("  - `src/a.ts`\n- Acceptance criteria:\n  1. Works.\n\n## Open", "- Acceptance criteria:\n  1. Works.\n\n## Open")), "P2: no ownedFiles");
});

test("planned decision nobody writes", () => {
    hasError(run(validSpec(), { readme: "| [0002](0002-orphan.md) | Orphan |\n" }), "Decision 0002");
});

test("missing manual testing doc or required section", () => {
    hasError(run(validSpec(), { testingDoc: false }), "does not exist");
    hasError(run(validSpec().replace("## Non-goals", "## Scope")), "Missing section: ## Non-goals");
});

test("approved spec with an open question", () => {
    hasError(run(validSpec().replace("None.\n", "- **Q1 · Thing?** Unclear.\n")), "still lists questions");
});

test("rejects paths outside the repo or not Markdown", () => {
    const root = repoWith(validSpec());
    hasError(validateSpec("../outside.md", root), "inside");
    hasError(validateSpec("/etc/passwd", root), "inside");
});
