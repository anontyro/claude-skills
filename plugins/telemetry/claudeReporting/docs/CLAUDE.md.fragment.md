# Multi-agent workflows (add to CLAUDE.md when `.claude/workflows/` is committed)

Until then the same text lives in `CLAUDE.local.md` (gitignored). Keep it
short: CLAUDE.md competes with actual work for context. Detail is in
`claudeReporting/docs/HANDOFF.md`.

---

## Multi-agent workflows

Three stages, a human between each. Run `/workflow-authoring` before editing a
script; run `/reload-skills` after.

1. **Plan** in plan mode, then write the spec with the `spec-plan` skill to
   `Docs/plans/<yyyy-MM-dd>-<PBI#>-<slug>.md` (template: `Docs/plans/_TEMPLATE.md`).
   Lanes, Decisions, Non-goals, Packages with exhaustive owned files.
2. **Build**: `/build-spec specPath=<spec> dryRun=true` to see waves and
   check commands (~2 agents), then `/build-spec specPath=<spec>`.
3. **Gate**: `/review-verify specPath=<spec>`. Result has `gate: pass|fail`.

Reports: `reports/<spec-slug>/`. Dashboard: `cd claudeReporting && docker
compose up -d`, http://localhost:3000/d/claude-agents.

Offline check after editing a script: `node .claude/workflow-tools/simulate.mjs`.

## Verification rules (all work, not just workflows)

- The typechecker, linter and tests decide whether something is done. Not
  your own assessment.
- Lanes and their checks (whole-tree lint is red at baseline; scope to your
  files and compare against baseline):
  - `static`: `npm run compile`; `npx eslint --config .eslintrc.json <files>`; `npx jest <dirs> --no-coverage`
  - `icp`: `pnpm --filter <app> exec tsc --noEmit`; `pnpm exec eslint <files>`; `pnpm exec jest -c ./jest.config.js --selectProjects apps-<app>`
  - `backend`: `dotnet build <test csproj> -c Debug`; `dotnet test <test csproj> --no-build`
  - `db`: no local compile; follow the DB conventions in this file exactly.
- Never make a check pass by weakening it: no deleted or skipped tests, no
  eslint-disable, `as any` or non-null assertions to silence errors.
- Reuse before writing; one responsibility per unit; plain code over
  abstraction used once. Report every deviation from a spec.
- Findings are falsifiable claims: something another reader could prove
  wrong by reading the code.
