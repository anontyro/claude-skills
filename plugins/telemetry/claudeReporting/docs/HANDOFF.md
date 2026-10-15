# Multi-agent setup for Phoenix: handoff

Context for a Claude Code session picking this up cold. Read this before
touching anything in `.claude/workflows/`, and run `/workflow-authoring`
before editing a script.

## What this is

A three-stage loop on Claude Code dynamic workflows, tailored to this repo,
with a human between each stage and every run observable:

| Piece | Path | Job |
| --- | --- | --- |
| Plan | plan mode + `spec-plan` skill → `Docs/plans/<date>-<pbi>-<slug>.md` | Turn an accepted plan into a spec the builders can execute without guessing |
| `/build-spec` | `.claude/workflows/build-spec.js` | Build the spec in dependency waves; baseline-relative checks; bounded quality-refine loop |
| `/review-verify` | `.claude/workflows/review-verify.js` | Gate the change: lane-aware checks, per-file review, adversarial verification, one ranked report |
| Hook | `claudeReporting/hooks/log-workflow-result.sh` | Append each workflow result and subagent stop as JSON lines (the quality axis) |
| Stack | `claudeReporting/docker-compose.yml` | Collector → Prometheus / Loki / Tempo / Grafana, plus the JSONL tailed into Loki |
| Simulator | `.claude/workflow-tools/simulate.mjs` | Run either script offline with stubbed agents; asserts scheduling and gate logic |
| Research | `.claude/skills/codebase-research/SKILL.md` | Parallel Explore fan-out + adversarial cross-check → cited report in `reports/research/` (works without the workflow runtime) |
| Maintenance | `.claude/maintenance/` + `.claude/skills/monthly-maintenance/SKILL.md` | Monthly dependency/vulnerability sweep: scripts collect and classify (auto / care / flag), one agent per lane applies the auto set, verifier checks, report; never pushes. `README.md` in the folder |

The loop:

```
plan mode → accept → Docs/plans/2026-09-08-31234-my-feature.md   (spec-plan skill, _TEMPLATE.md)
/build-spec specPath=Docs/plans/2026-09-08-31234-my-feature.md dryRun=true    (~2 agents: waves + check commands)
/build-spec specPath=Docs/plans/2026-09-08-31234-my-feature.md                (build, refine, integrate, report)
/review-verify specPath=Docs/plans/2026-09-08-31234-my-feature.md             (gate: pass | fail)
open http://localhost:3000  → "Claude agents" dashboard
```

Reports land in `reports/<spec-slug>/build-spec.md` and
`reports/<spec-slug>/review-verify.md` (gitignored).

## Lanes: the repo-specific part

Phoenix has three toolchains plus SSDT. Both scripts carry an identical
`LANES` block that classifies every path and derives check commands from it.
The runtime cannot import a shared module, so if you change one, change both
(the simulator will not catch drift; grep for `laneForPath`).

| Lane | Root | Typecheck | Lint | Test |
|---|---|---|---|---|
| `static` | `Chinsay.ContractManager.Static` | `npm run compile` | `npx eslint --config .eslintrc.json <changed files>` | `npx jest <changed dirs> --no-coverage` |
| `icp` | `Chinsay.ContractManager.Static/icp-frontend` | `pnpm --filter <app> exec tsc --noEmit` | `pnpm exec eslint <changed files>` | `pnpm exec jest -c ./jest.config.js --selectProjects apps-<app>` |
| `backend` | repo root | `dotnet build <test csproj> -c Debug` | none | `dotnet test <test csproj> --no-build` |
| `db` | repo root | none | none | none: agents review `:r` registration, `UpdateScript` guard, temporal detach |

Source→test project mapping for `backend` is the `BACKEND_TEST_PROJECTS`
table (Api → `API.UnitTest`, ServiceHookEngine → its UnitTest, Functions →
FunctionsTest, DataPlatform → XUnitTest, everything else →
`Chinsay.ContractManager.UnitTest`).

Measured on this machine (2026-09-08, macOS, node 24, dotnet 8.0.415):

| Check | Baseline | Time |
|---|---|---|
| Static `npm run compile` | green | ~2s |
| Static `npx tsc --noEmit` (root tsconfig) | **red**: TS 4.7 vs react-hook-form types | 34s |
| Static `npm run lint` (whole tree) | **red**: 2,021 errors | 2m17s |
| Static scoped eslint, one file | red-ish (pre-existing) | 12s |
| icp `pnpm lint` (whole tree) | **red**: 1,998 errors | 33s |
| icp `pnpm --filter icp-actions exec tsc --noEmit` | **red** (pre-existing) | 12s |
| icp per-app jest | green | ~24s |
| `dotnet build` UnitTest | green, 581 warnings | 1m44s |
| `dotnet test` UnitTest filtered, `--no-build` | green | 7s |

This is why the old shells' `npx tsc --noEmit && npm run lint && npm test`
could never gate anything here, and why every check is **baseline-relative**:
`/build-spec` records failure signatures (`check|file|message`, line numbers
excluded) before wave 1 and only failures not in that set count. Lint runs on
changed files only. `/review-verify` has no baseline (it can't check out the
base ref), so it reports check failures as facts, attributes the ones inside
changed files, and fails the gate only on failing `test` checks or confirmed
high/critical findings.

## Design decisions (don't silently reverse)

**Deterministic tools adjudicate, agents propose.** Typechecker, linter and
tests decide whether work is done. LLM critique is reserved for what tools
can't check: spec conformance, DRY/SRP/simplicity, repo conventions.

**Verifiers are adversarial.** "Refute this, assume it's wrong" produces
refutations; "assess this" produces agreement. Verifiers get fresh context and
never see the reviewer's reasoning.

**Scheduling belongs to the script.** `buildWaves()` is plain JS: topological
layering, lexically sorted ids, file-collision deferral, cycle breaking. The
simulator covers diamond deps, sibling file collision, cycle, dangling ref.

**File ownership makes parallelism safe.** Exhaustive `ownedFiles` per
package; builders return `blocked` rather than touch another file.

**Every loop has two guards.** Round cap plus strict no-progress check, for
both the repair loop and the refine loop. A red wave stops the run.

**Quality is a bounded loop, not a one-shot review.** After each green wave a
read-only reviewer grades the wave's files against `DESIGN_BRIEF` (reuse
first, single responsibility, simplicity, naming, dead code, test quality,
repo conventions) and returns falsifiable findings with a concrete change. A
refactorer applies the high/medium ones inside the wave's files, the gate
re-runs. Stops when nothing actionable remains, on no progress, or at
`maxRefineRounds` (2). `refine=false` skips it. The same brief is in every
builder's prompt so they are graded on what they were told.

**Baseline before build.** See above. Also makes the wave gate honest about
what this run broke versus what was already broken.

**Mechanical stages run on a cheaper model.** `CONFIG.mechanicalModel =
'sonnet'` for the check runner and the report writer. Set to `undefined` to
use the session model everywhere.

**Agents `cd` to the repo root themselves.** Every prompt starts with
`cd "$(git rev-parse --show-toplevel)"` because Claude Code is often launched
from `Chinsay.ContractManager.Static`. Commands carry their own `cd` into the
lane root. This needs `Bash(cd:*)` in the allow list.

## Runtime constraints (hard limits)

- `export const meta` first, pure object literal, or `/<name>` vanishes from
  autocomplete. `phases` titles must match `phase()` strings exactly. The
  simulator checks the second.
- No mid-run user input: `/build-spec` bails in Understand with
  `blockingQuestions` instead of asking. Plan mode and workflows alternate.
- `Date.now()`, `Math.random()`, no-arg `new Date()` throw. IDs are positional.
- No `import()`, no fs, no shell from the script. Agents do all I/O.
- Caps: 16 concurrent agents, 4,096 items per `pipeline()`, 1,000 agents/run.
- `agent()` returns `null` if stopped or on API error; `pipeline()` keeps the
  null. Both scripts treat null as "did not return".
- `pipeline()` is used for every fan-out, awaited, so it acts as a barrier.
  `parallel()` is not used (its signature isn't documented publicly).
- After editing a script: `/reload-skills`, then `/<name>` again.

## Iterating

- **Offline first.** `node .claude/workflow-tools/simulate.mjs` (nvm node ≥22)
  runs both scripts with stubbed agents in about a second and asserts wave
  layout, baseline diffing, repair/refine termination, and gate results. Add a
  scenario in `.claude/workflow-tools/fixtures/` when you change control flow.
  `--trace` prints every agent label and log line.
- **Dry-run every new spec.** `dryRun=true` runs Understand + Decompose and
  prints waves and the exact check commands. Two agents.
- **Replay.** Each run's script is written under the session's directory in
  `~/.claude/projects/`; ask Claude for the path. Relaunching an edited script
  reruns from the first agent whose prompt changed, so editing only the
  verifier prompt re-verifies against cached reviews.
- **Prompt A/B.** Set `OTEL_RESOURCE_ATTRIBUTES="harness=phoenix,variant=<name>"`
  before a run; `variant` becomes a Prometheus label and a dashboard variable.
  The quality side (confirmed/refuted, score) comes from the hook's JSONL.

## Observability

```
cd claudeReporting && docker compose up -d && ./check.sh
```

`check.sh` verifies every service, Grafana provisioning (three datasources,
the "Claude agents" dashboard), Prometheus scraping the collector, and the
hook → filelog → Loki path by writing a probe line and querying it back.

Grafana http://localhost:3000 (anonymous admin). Prometheus :9090, Loki :3100,
Tempo :3200, collector OTLP gRPC :4317.

Telemetry env is in `.claude/settings.local.json` (`env` block) so every
session in this project exports to the local collector; the same keys are in
`claude-otel.env` for shell use. `QUERIES.md` has the queries, including the
outcome ones.

Gotchas: Prometheus needs
`OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative`; metric names
lose their dots (`claude_code_cost_usage_USD_total`); `workflow.name` reads as
`custom` unless `OTEL_LOG_TOOL_DETAILS=1`; hooks don't inherit `OTEL_*`
exporter vars (irrelevant here, the hook writes a file).

## Hook (quality axis)

`claudeReporting/hooks/log-workflow-result.sh`, registered for `PostToolUse`
(matcher `Workflow`) and `SubagentStop`. Writes to `claudeReporting/data/`
(override with `CLAUDE_REPORTING_DIR`): `outcomes.jsonl` gets the workflow's
return value with `status`/`gate`/`count_*`/`quality_score` flattened for
LogQL; `agents.jsonl` gets one line per subagent with type and duration. The
collector tails both into Loki as `{service_name="claude-reporting"}`.

Claude Code's classifier blocks Claude from editing permission settings, so
the hook and permission rules are applied by hand from
`claudeReporting/settings.snippet.json`.

## Moving `claudeReporting/` out of the repo

Everything in the folder is path-independent except two references:
`.claude/settings.local.json` (`hooks[*].command`), and `.gitignore`
(`/claudeReporting/data/*.jsonl`). After moving, point the hook command at the
new location and optionally set `CLAUDE_REPORTING_DIR`. `docs/` in the folder
is repo-specific and should stay with the repo (or be split).

## Known gaps / next steps

1. **Permissions are hand-applied.** See `settings.snippet.json`. If runs
   stall, the Permission decisions panel shows which rule is missing.
2. **`db` lane has no deterministic check** on macOS (SSDT is Windows-only).
   The Integrate agent and `/review-verify` checklist cover the conventions,
   but nothing compiles the `.sql`. A Windows runner or a T-SQL parser step
   would close this.
3. **Whole-lane test runs at the wave gate are scoped to changed dirs/apps.**
   A change that breaks a test elsewhere in the lane is caught by
   `/review-verify` only if that test's directory changed. Widen `checkPlan`'s
   test scope if this bites.
4. **No per-package isolation.** Builders write to the live tree; waves +
   ownership prevent collisions. If waves prove too coarse, add `cwd` with a
   worktree per builder (undocumented option; test first).
5. **No Stop-hook gate for ordinary sessions.** A `Stop` hook that exits 2 on
   failing scoped checks would extend the discipline outside workflows.
6. **Simulator can't catch LANES drift** between the two scripts. Check by
   hand from `.claude/workflows/`:
   ```
   strip() { sed -n '/^const REPO_ROOT_CD/,/^function specSlug/p' "$1" | grep -v '^\s*//'; }
   diff <(strip build-spec.js) <(strip review-verify.js) && echo identical
   ```
