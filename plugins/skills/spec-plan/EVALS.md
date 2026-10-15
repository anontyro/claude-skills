# spec-plan evals: next steps

The goal is to know whether a change to the spec-plan skill makes specs better or worse, and how specs perform once
they are built. There are two kinds of eval:

- **offline**: fixed planning prompts, run before a skill change is merged;
- **online**: scores for real use, drawn from the telemetry we already collect.

## Done

| Piece | Where | Status |
|---|---|---|
| Spec validator (structure, waves, release sizes, decisions, open questions) | `references/validate-spec.mjs` (`--json` for machines) | Built. 32750 passes with 0 errors. |
| Validator tests (one per rule) | `references/validate-spec.test.mjs` (`node --test`) | 12 of 12 pass. |
| Skill step: validate before `approved` | `SKILL.md` step 6 | Done. |

The validator is the deterministic grader for both kinds of eval, and it also checks every real spec as it is
written.

## Next steps

### 1. Provenance hook (online)

A `PostToolUse` hook on Write/Edit of `Docs/*/Specs/*.md`. It records
`{session_id, spec path, git sha, SKILL.md hash, validator --json result}`.

- **Benefit:** this is the join key. Telemetry already carries `session.id`; this ties a session to the spec it
  produced, and every later outcome is keyed by spec path.
- **Required:** a small script (python3, because node isn't on the PATH for hooks), plus a hook entry added by hand
  (via `claudeReporting/settings.snippet.json`).
- **Missing:** the location of the `claudeReporting` stack (it isn't in this repo), and where the hook should write
  (the OTLP collector, a DB table or a JSONL file).

### 2. Skill-version tag (online)

Put the skill version in `OTEL_RESOURCE_ATTRIBUTES` (`variant=spec-plan-<short hash>`, next to the existing
`harness=phoenix`).

- **Benefit:** before/after comparisons of skill changes on real sessions.
- **Required:** a one-line settings change per skill version, or a hook that sets it.
- **Missing:** a decision on whether `variant` stays per experiment or becomes a dedicated `skill.version`
  attribute.

### 3. Outcome signals (online)

Join on spec path, then score each spec on:

- validator errors and warnings;
- spec edits after approval (git log);
- estimated vs actual files per release (summary block vs git diff);
- builder `blocked` reports and deviations;
- check results per package;
- the manual-test checklist pass rate.

**Benefit:** this measures what matters, whether the spec held up when built. 32750 already supplies examples: a
bug in the spec that didn't exist in the code, a missing string key, and a type error only the webpack build caught.

- **Required:** a small collector that reads git, `reports/<spec-slug>/` and the `Testing/` checklists.
- **Missing:** the build reports from `/build-spec`, which is disabled by org policy. Until it is enabled, package
  outcomes have to be logged by hand or from session transcripts.

### 4. Offline eval suite (`claude plugin eval`)

Put 3–4 cases in `evals/<case>/prompt.md` + `graders/`:

- a small single-lane PBI;
- a multi-release feature (should come back split into R1a/R1b);
- an existing feature folder (should be reused);
- an ambiguous requirement (should come back as an open question, not a guess).

Graders: `file_exists` (spec, Testing doc, Decisions README), the validator via `regex`/`tool_used`, and one `llm`
judge with a short rubric. The rubric asks whether the decisions cover the real ambiguities, the spec has no
implementation code, and every acceptance criterion can be decided by a test.

- **Benefit:** catches regressions before a skill change ships, and runs in CI (`--json`, `--trust-plugin`,
  `--allow-tools`, `--max-cost-usd`).
- **Required:** a fixture repo, or a `case.yaml` `scaffold_script` that makes a `git worktree` at a pinned commit.
- **Missing / to verify:**
  - whether a bare project skill works as a target (it may need `plugins: ["../.."]` in each case);
  - the result fields;
  - eval runs probably don't emit OTel, so they can't be joined by session id. Use the suite's own
    `aggregate-result.json` instead.

  There is no public docs page for `plugin eval` yet; the details above come from the built-in reference.

### 5. Batch LLM scoring (online)

Run the offline judge's rubric over stored specs and write the score keyed by `session_id`.

- **Benefit:** a quality score on real use without hand review.
- **Required:** step 1 (the join key), and an API budget.
- **Missing:** nothing beyond step 1.

## Suggested order

1 → 2 → 4 → 3 → 5.

Steps 1 and 2 are small and make every later session measurable. Step 4 protects skill edits. Step 3 depends on
build reports, so it gets easier once `/build-spec` is enabled.

## Open decisions

- Where the telemetry store and `claudeReporting` live, and the table or format for provenance rows.
- `variant` vs a dedicated `skill.version` attribute.
- Whether evals run in CI (cost ceiling, and which pipeline) or only locally before a skill change.
