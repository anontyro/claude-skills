# Manual testing: <Feature title> (<ID>)

<!--
Save as Docs/<Feature>/Testing/MANUAL-TESTING-<ID>-<slug>.md, next to the feature's Specs/ and Decisions/ (one
file per spec, or per release when a PR covers only one).
Written for a tester on the Test environment who has not read the spec. Every test case is traceable back to a
release, a work item and the spec's decisions. Delete these comments.
-->

**Spec:** `Docs/<Feature>/Specs/<yyyy-MM-dd>-<ID>-<slug>.md`
**Branch / PR:** `<branch>` (PR <number>, if raised)
**Work items:** <ID> · tasks <task#> (R1), <task#> (R2), ...
**Environment:** Test<, with any real external service it depends on>.
**Covers:** <all releases | R1 only | ...>. <What is deliberately not covered, e.g. already in master.>

## What changed

<!-- One bullet per user-visible change, grouped by release. Bold lead-in, then one or two sentences. -->

### R1 · <short name> (task <task#>)

- **<Change>.** <What the user sees now.>

### R2 · <short name> (task <task#>)

- **<Change>.** <...>

- **New toggle.** `<toggle key>` gates all of the above.

## Setup

- Feature flags, for the test user:
  - `<toggle key>` on.
  - <any other toggle and its state>
- Test data:
  - <workspace / process / step configuration needed, e.g. "a process with an Upload step whose OCR is required">
  - <files needed, e.g. "a PDF, a .msg, a .zip and a 0-byte file">
- Users:
  - <role A, e.g. a user with edit access to private attachments>
  - <role B, e.g. a counterparty user>

## Change checklist

<!--
One line per change in "What changed", linked to the test case(s) that prove it. Tick when verified on Test.
This is the traceability view: release → work item → decision → test.
-->

| ✓ | Release | Work item | Change | Spec ref | Test case |
|---|---|---|---|---|---|
| ☐ | R1 | <task#> | <change> | D<n> | 1, 2 |
| ☐ | R2 | <task#> | <change> | D<n> | 5 |

## Test cases

<!-- Group by release. Each case: a one-line action, then bullets with the expected results. -->

### R1 · <short name> (task <task#>)

### 1. <Area>
<What to do, in one or two sentences.>
- <expected result>
- <expected result>

### 2. <Area>
<...>
- <...>

### R2 · <short name> (task <task#>)

### 3. <Area>
<...>
- <...>

### N. Toggles
- **`<toggle>` off:** <the page looks and behaves exactly as on master; list what to check>.
- **`<toggle>` on, without <access/feature>:** <...>

## Watch for

- Browser console errors while <the new UI updates>.
- <counts or states that could disagree>

## Known and accepted

- **<Topic>:** <behaviour that looks odd but is intended or deferred (link the spec's follow-ups)>.

## Quick pass / fail summary

| # | Release | Area | Pass / Fail | Notes |
|---|---|---|---|---|
| 1 | R1 | <area> | | |
| 2 | R1 | <area> | | |
| 3 | R2 | <area> | | |
| N | all | Toggles | | |
