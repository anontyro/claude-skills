---
name: spec-plan
description: Used when planning a feature or work item that will be built by parallel builders — turns a plan-mode plan into a spec under Docs/<Feature>/Specs/ with lanes, packages, owned files and acceptance criteria that can be executed without guessing. Trigger on "write the spec", "plan this for build", "create a build plan", or when a plan is approved and the next step is building it.
---

# Writing a spec for a multi-agent build

The loop is: plan mode → spec file → build → review. The spec is the only
channel from the human to the builders, because an automated build cannot ask
questions mid-run. A spec that leaves a design decision open makes the build
stop and hand the question back; a spec that hides one makes two builders
choose differently.

Paths below are relative to this skill's folder (`${CLAUDE_SKILL_DIR}`) unless
they start with `Docs/`, which is in the target repo.

## Steps

1. Do the planning in plan mode as usual: explore the code, settle on an
   approach, get it accepted.
2. Copy [`references/SPEC_TEMPLATE.md`](references/SPEC_TEMPLATE.md) (next to
   this skill) to `Docs/<Feature>/Specs/<yyyy-MM-dd>-<ID>-<short-slug>.md`
   and fill every section. **Specs live with their feature**, not in a shared
   plans folder, so a feature's specs, design and decisions are recorded
   together:

   ```
   Docs/<Feature>/            PascalCase, e.g. Docs/UserExport/
     Specs/                   one spec per work item or phase: <yyyy-MM-dd>-<ID>-<slug>.md
     Design/                  mockups and design exports the spec cites (pN)
     Decisions/               README.md + NNNN-<rule>.md (step 4)
     Testing/                 MANUAL-TESTING-<ID>-<slug>.md (step 3)
   ```

   Create the folders that don't exist yet. Use the existing feature folder
   when the work extends a feature that already has one. 
   - **Lanes**: the independent areas of the codebase the work touches (e.g.
     frontend, backend, db), each with its own check commands. Take them from
     the repo's `CLAUDE.md` or build files, and write the commands into the
     spec's Lanes table.
   - **Decisions**: every choice two competent builders might make
     differently. Interfaces, DTO field names, error contracts, feature flag
     (prefer an existing one), where state lives, shared strings or config keys.
   - **Releases / phases**: when the work ships in more than one release
     (or phase), each release's section opens with a short summary block
     before any decisions:
     - 2–3 sentences on what changes for the user and in the code;
     - a rough file-change estimate (`~N files: ~X new, ~Y modified`),
       counted from the owned files of that release's packages;
     - its packages, and the related work items (ticket numbers, e.g. `12345` or `PROJ-123`).

     Put the work item number next to each package heading too
     (`### P6 · … (R2 · 12345, wave 4)`), so a package, a release and its
     ticket can be traced in both directions.
   - **Release size**: aim for **≤ 30 changed files per release**, counted
     from that release's packages' `ownedFiles`. A release well above that
     is split into sub-releases (`R1a`, `R1b`, …), each with its own
     summary block and file estimate.
     - Sub-releases may depend on each other more tightly than releases do.
       For example, R1b can need R1a's binding or slice.
     - If the repo uses feature flags, ship every release and sub-release
       behind one so a merged but unfinished slice is invisible. Use one flag
       for the feature unless the user wants per-release flags.
     - Order the waves so that a sub-release's packages finish together and
       it can merge on its own.
   - **Non-goals**: so the integration reviewer can flag scope creep.
   - **Packages**: one lane each where possible, exhaustive repo-relative
     `ownedFiles`, acceptance criteria a compiler or test can decide.
     Shared types / DTOs / schema scripts / state slices / extracted helpers go
     first; anything that would otherwise be duplicated by two packages gets
     its own early "extract" package.
3. **Write the manual testing document** alongside the spec. Copy
   [`references/MANUAL_TESTING_TEMPLATE.md`](references/MANUAL_TESTING_TEMPLATE.md)
   to `Docs/<Feature>/Testing/MANUAL-TESTING-<ID>-<slug>.md`, and link it from
   the spec's header.
   - It tests the **full feature, end to end, on the Test environment**, not
     unit-level behaviour. Write it for a tester who has not read the spec.
   - Sections:
     - **What changed**, grouped by release, each with its work item number.
     - **Setup:** toggles, test data and users.
     - A **change checklist** table. One row per change: release → work item
       → spec decision → test case number, with a tick box. That makes every
       change traceable and easy to sign off.
     - **Numbered test cases** grouped by release, each an action followed by
       bullets of expected results. Include a toggles-off case.
     - **Watch for** and **Known and accepted**.
     - A **pass / fail summary** table.
   - Follow the tone and shape of the existing manual testing documents
     (if the repo has existing manual testing documents).
   - Update it when the spec changes, so it always matches what will ship.
4. **Plan the decision records.** Every feature keeps its rules in
   `Docs/<Feature>/Decisions/`, one per file, in the shape
   of the templates below.
   - Create the folder and its `README.md` from
     [`references/DECISIONS_README_TEMPLATE.md`](references/DECISIONS_README_TEMPLATE.md)
     while writing the spec.
   - List every planned decision in the README up front: a number, a one-line
     rule, its release and the package that writes it. The README is then not
     edited by packages, so parallel waves don't conflict on it.
   - **After each release (section),** its last package writes that release's
     records from
     [`references/DECISION_TEMPLATE.md`](references/DECISION_TEMPLATE.md)
     (`Status: Agreed`; Accepted once in master). Each record is in that
     package's `ownedFiles` and has an acceptance criterion.
   - A record states what the built code does and why. If the code ended up
     differing from the spec, the record follows the code and the package
     says so.
   - If the repo's `CLAUDE.md` keeps a list of feature decisions folders, add
     the new feature to it.
5. Name existing code to reuse. Search before proposing a new helper, hook,
   component or service; the quality reviewer grades
   duplication as a defect.
6. **Validate the spec** before marking it approved, and again after any
   restructure:

   ```
   node ${CLAUDE_SKILL_DIR}/references/validate-spec.mjs Docs/<Feature>/Specs/<file>.md
   ```

   (Run it from the repo root; needs Node 18+.) Add `--json` for machine-readable output (evals,
   telemetry).
   - **Exit 1 means errors**, and the spec is not ready. The checks:
     - the location;
     - the required sections;
     - the Testing and Decisions files;
     - every package heading has a release, a work item and a wave, matching the waves table;
     - ownedFiles and numbered acceptance criteria;
     - **no two packages in one wave share a file**;
     - every release has a summary block with a file estimate and a work item;
     - every planned decision is owned by a package;
     - no open questions once approved.
   - **Warnings** (e.g. a release over ~30 files) are judgement calls. Split the release, or say why not.
   - The rules are pinned by `references/validate-spec.test.mjs` (`node --test`). Update both together.
7. Set `Status: approved <date>` once the human has accepted it and the
   validator passes.
8. Tell the user the spec path and that it is ready to hand to the builders
   (whatever workflow or agents the repo uses to execute it).

## Conventions the spec must respect

Follow the target repo's `CLAUDE.md` for build, test, database and style
conventions, and cite the relevant rule in the spec's decisions where a
builder could otherwise get it wrong. Don't restate conventions the builders
already load from `CLAUDE.md`.

## What not to put in a spec

- Implementation code. Builders write it; the spec says what must be true
  afterwards.
- Vague criteria ("works correctly", "is clean"). If a test can't decide it,
  rewrite it.
- Files outside the packages' `ownedFiles`. If a builder needs another file,
  it returns `blocked`; the fix is to add the file to the right package.
