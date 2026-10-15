# <Feature title>

<!--
Copy to Docs/<Feature>/Specs/<yyyy-MM-dd>-<ID>-<short-slug>.md and fill every section. Delete these comments.
The spec is the only channel from the human to the builders: every decision a builder could make differently is
recorded here, and every file a package may touch is listed in its ownedFiles.
-->

Work item: <ID>. Releases map to these tasks:

| Release | Task |
|---|---|
| R1 · <short name> | <task#> |
| R2 · <short name> | <task#> |

Branch: `feature/<ID>-<slug>`.
Toggle: `<flag-key>` (new or existing; D1), if releases ship behind a flag.
Design: `Docs/<Feature>/Design/<file>` (cite page numbers as pN), if there is one.
Status: **draft <yyyy-MM-dd>**. <Which questions are open, and which releases they block.>
Manual testing: `Docs/<Feature>/Testing/MANUAL-TESTING-<ID>-<slug>.md` (see `references/MANUAL_TESTING_TEMPLATE.md`).
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
may depend on each other more tightly than releases do, but each one should be mergeable on its own.
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

> **R1 · <ID> / task <task#> · ~N files: ~X new, ~Y modified · packages P0–Pn**
>
> <2–3 sentences: what changes for the user in this release, then what changes in the code.>

- **D1 · Feature flag.** <key, name, default state, where it is defined. Delete if the work is not flagged.>
- **D2 · <decision>.** <interface / DTO field names / error contract / where state lives / ...>

### R2 · <short name>

> **R2 · task <task#> · ~N files: ~X new, ~Y modified · packages Pn**
>
> <2–3 sentence summary.>

- **D<n> · <decision>.** <...>


## Non-goals

- <out of scope item, so the integration reviewer can flag scope creep>

## Lanes

<!-- Lanes are independent areas of the codebase with their own checks (e.g. frontend, backend, db). Replace the rows
with this repo's lanes; list each lane's check commands so builders and reviewers run exactly those. -->

| Lane | Touched | Checks |
|---|---|---|
| `<lane>` | yes/no | `<build / lint / test commands>` |

## Packages

Waves:

| Wave | Packages | Release | Note |
|---|---|---|---|
| 1 | P0, P1 | all (<ID>) · R1 (<task#>) | parallel |
| 2 | P2 | R1 (<task#>) | |

Packages that share a wave share no files.

Shared acceptance for every package:

- The lane checks pass for its files, measured against the baseline.
- Nothing new runs with the toggle off (if flagged).
- No test is deleted or skipped to pass a check.
- Shared resources (strings, config, schemas) only through the package that owns them. A package that finds one missing reports `blocked`.

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
