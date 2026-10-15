# <Feature title>

<!--
Copy to Docs/<Feature>/Specs/<yyyy-MM-dd>-<PBI#>-<short-slug>.md and fill every section. Delete these comments.
The spec is the only channel from the human to /build-spec: every decision a builder could make differently is
recorded here, and every file a package may touch is listed in its ownedFiles.
-->

PBI: <PBI#>. Releases map to these tasks:

| Release | Task |
|---|---|
| R1 · <short name> | <task#> |
| R2 · <short name> | <task#> |

Branch: `feature/<PBI#>-<slug>`.
Toggle: `<PBI#>-<kebab-description>` (new or existing; D1). Every release ships behind it.
Design: `Docs/<Feature>/Design/<file>` (cite page numbers as pN), if there is one.
Status: **draft <yyyy-MM-dd>**. <Which questions are open, and which releases they block.>
Manual testing: `Docs/<Feature>/Testing/MANUAL-TESTING-<PBI#>-<slug>.md` (see `references/MANUAL_TESTING_TEMPLATE.md`).
Decisions: `Docs/<Feature>/Decisions/` (README lists every planned record and the package that writes it; see
`references/DECISIONS_README_TEMPLATE.md` and `references/DECISION_TEMPLATE.md`).

## Goal

<One or two sentences: what the user can do afterwards that they could not before.>

| Release | What ships | Design pages |
|---|---|---|
| **R1** | <user-visible outcome> | <pN> |
| **R2** | <user-visible outcome> | <pN> |

<!--
Releases target <= 30 changed files. A release well above that is split into sub-releases (R1a, R1b, ...). Sub-releases
may depend on each other more tightly than releases do, but every one of them is behind the toggle.
-->

## Background (read <yyyy-MM-dd>)

<!--
What exists today, with path:line citations, so builders do not re-research it. Name the code to REUSE (helpers,
hooks, components, services, endpoints). Call out bugs found on the way that the feature will hit.
-->

### <Area 1>

- <fact> (`path/to/file.ts:123`)

### <Area 2>

- <fact>

## Decisions

### R1 · <short name>, plus decisions shared by every release

> **R1 · PBI <PBI#> / task <task#> · ~N files: ~X new, ~Y modified · packages P0–Pn**
>
> <2–3 sentences: what changes for the user in this release, then what changes in the code.>

- **D1 · Feature flag.** <key, name, client-side availability, LaunchDarkly state; constant names in C# and TS. See
  the `launchdarkly-toggle` skill.>
- **D2 · <decision>.** <interface / DTO field names / error contract / where state lives / ...>

### R2 · <short name>

> **R2 · task <task#> · ~N files: ~X new, ~Y modified · packages Pn**
>
> <2–3 sentence summary.>

- **D<n> · <decision>.** <...>

<!-- Strings: list every new translation key with its English text, and say which package adds them (one early
package adds them all). -->

## Non-goals

- <out of scope item, so the integration reviewer can flag scope creep>

## Lanes

| Lane | Touched | Checks |
|---|---|---|
| `static` | yes/no | `npm run compile`; `npx eslint --config .eslintrc.json <files>`; `npx jest <dirs> --no-coverage` |
| `icp` | yes/no | `pnpm --filter <app> exec tsc --noEmit`; `pnpm exec eslint <files>`; `pnpm exec jest -c ./jest.config.js --selectProjects apps-<app>` |
| `backend` | yes/no | `dotnet build <test csproj> -c Debug`; `dotnet test <test csproj> --no-build --filter "<filter>"` |
| `db` | yes/no | no local compile; follow the DB conventions in CLAUDE.md exactly |

## Packages

Waves:

| Wave | Packages | Release | Note |
|---|---|---|---|
| 1 | P0, P1 | all (<PBI#>) · R1 (<task#>) | parallel; P0 adds every string up front |
| 2 | P2 | R1 (<task#>) | |

Packages that share a wave share no files.

Shared acceptance for every package:

- The lane checks pass for its files, measured against the baseline.
- Nothing new runs with the toggle off.
- No test is deleted or skipped to pass a check.
- Strings only through the early strings package. A package that finds a missing string reports `blocked`.

### P0 · <Lane>: <what> (<release> · <task#>, wave 1)
- Lane: `<lane>`
- ownedFiles:
  - `<repo-relative path>` (new | moved | deleted, when not a plain edit)
- Acceptance criteria:
  1. <something a compiler or test can decide>

### P1 · <Lane>: <what> (<release> · <task#>, wave 1)
- Lane: `<lane>`
- ownedFiles:
  - `<repo-relative path>`
- Acceptance criteria:
  1. <...>

## Follow-ups

- <known issue or deferred work, logged here instead of built>

## Resolved questions

- **Q1 → D<n>.** <answer>

## Open questions

- **Q<n> · <topic>.** <question, the default the spec assumes, and which release it blocks>
