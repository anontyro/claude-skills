# spec-plan evals

Offline checks for the `spec-plan` skill. Each case builds a small fixture repo, gives the agent a planning
request, and grades the spec it writes.

| Case | Tests |
|---|---|
| `small-single-lane` | A small request gets a small, accurate spec; existing files are cited correctly |
| `multi-lane-feature` | Waves, shared contracts first, lane checks taken from `CLAUDE.md`, reuse of existing code |
| `vague-request` | Open questions are raised instead of guessed; the spec is not marked approved |

## Run

From the repo root:

```
claude plugin eval plugins/spec-plan --scaffold --allow-tools Bash
```

- `--scaffold` runs each case's `fixture.sh` to build its fixture repo. Run it only on cases you wrote.
- `--allow-tools Bash` lets the skill run `validate-spec.mjs` (needs `node` on the PATH).
- Useful flags: `--case multi-lane-feature`, `--runs 1` for a quick pass, `--max-cost-usd 5`, `--report out.html`.
- Results land in `evals/results/` (gitignored). Compare scores across skill versions, and keep the
  `spec-plan-<version>-<hash>` variant from the run next to the score.

By default each case runs with and without the plugin, so the report shows the skill's effect (Δ). The
"skill fired" graders are excluded from the score in that mode and shown as an indicator.

## Graders

Deterministic: skill fired, spec file created under `Docs/*/Specs/`, the validator was run, and its output
contains `0 error(s)`. Model-graded: one rubric per case (`graders/criteria.md`), weighted higher.

The grader types cannot run code, so the validator is checked through the transcript rather than run by the
grader. If a case scores low only on `validator-clean`, read the transcript: the cause is often `node` not on
the sandbox PATH rather than a bad spec.
