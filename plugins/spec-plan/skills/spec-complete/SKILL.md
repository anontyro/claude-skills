---
name: spec-complete
description: Used when the work for a spec written with spec-plan is finished — appends a "## Completion" section to the spec with a summary, per-package results, deviations from the plan and a rating, and logs it for evals. Trigger on "wrap up the spec", "we're done", "complete the spec", "summarise what we built", or when the last acceptance criterion passes.
---

# Closing out a spec

The spec is the plan; this adds what actually happened. The result sits at the
end of the same file, so the plan, the outcome and the deviations stay
together, and the session's telemetry gets a rating and counts to evaluate the
spec-plan skill with.

Paths are relative to the skills folder of this plugin (`${CLAUDE_SKILL_DIR}/..`).

## Steps

1. **Find the spec.** Use the path the user names; otherwise the spec this
   session approved or built from. If there are several candidates, ask.
   Don't run this on a spec with open questions or one that was never approved.
2. **Gather the facts** from the repo root:

   ```
   node ${CLAUDE_SKILL_DIR}/../spec-plan/references/completion-facts.mjs Docs/<Feature>/Specs/<file>.md
   ```

   It prints JSON: the base commit (the sha recorded when the spec was first
   approved, else the merge-base), every file changed since (committed or not),
   per package which `ownedFiles` were touched and which weren't, and
   `outsideOwned`, the changed files no package owned. If `baseSource` is
   `merge-base` and the branch holds earlier work, ask the user for the right
   base and rerun with `--base <sha>`.
3. **Re-run the lane checks** from the spec's Lanes table, scoped to the files
   changed. Report results as they are. Don't mark a criterion verified unless
   a command, test or direct observation this session showed it.
4. **Work out each package's status**:
   - `done`: its acceptance criteria are verified.
   - `partial`: some are, or some owned files weren't touched; say which.
   - `skipped`: nothing was built; say why.
5. **List deviations.** Compare the diff to the spec rather than your memory:
   - a decision (D<n>) that the code does differently;
   - a package changed more, less or differently than written;
   - each `outsideOwned` file, with why it was needed;
   - each untouched owned file that should have been touched;
   - non-goals that crept in; work that moved to a follow-up.

   Each is one bullet: what the spec said, what was built, why. A decision
   record that now disagrees with the code follows the code (see spec-plan
   step 4); fix it.
6. **Ask the user for a rating** with AskUserQuestion: how well did the spec
   serve the build, 1 (had to re-plan) to 5 (built exactly as written), plus an
   optional one-line reason. Don't pick the rating yourself. It is the one
   human signal in the evals.
7. **Write the section.** Copy
   [`../spec-plan/references/COMPLETION_TEMPLATE.md`](../spec-plan/references/COMPLETION_TEMPLATE.md)
   to the end of the spec and fill it. Keep the first block's `Field: value`
   lines and `n/m` shapes exactly: the logging hook parses them. Counts must
   match the lists below them (`Deviations: 2` means two bullets).
   Then change the header to `Status: **completed <yyyy-MM-dd>**`.
8. **Check it.** Run `validate-spec.mjs` on the spec; the new section must not
   add errors. The edit also triggers the logging hook, which writes a
   `SpecCompleted` row to `specs.jsonl` for the Spec quality dashboard.
9. Tell the user the headline: rating, packages done, deviations, and anything
   left in Follow-ups. Don't commit unless asked.

## What not to do

- Don't rate or verify generously. A deviation list that is empty on a large
  diff is almost always wrong; look again.
- Don't rewrite the plan sections of the spec to match what was built. The
  plan stays as approved; the Completion section records the difference.
- Don't invent follow-ups. Only list work that came up.
