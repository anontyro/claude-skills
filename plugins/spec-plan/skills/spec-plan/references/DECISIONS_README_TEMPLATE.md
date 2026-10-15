# <Feature> decisions

<!-- Save as Docs/<Feature>/Decisions/README.md. Delete these comments. -->

The rules <feature> is built on, one per file. Each file says what the code does and why. For how it does it, read
the code.

**Spec:** `Docs/<Feature>/Specs/<spec>.md` · **Manual testing:** `../Testing/MANUAL-TESTING-<ID>-<slug>.md` · **Work item:** <ID>

## How to use this folder

- **Change a decision in the same PR as the code.** The review then checks the diff against the rule written here.
- **Edit the file in place when a decision changes.** Git keeps the history, so don't add dated amendments or
  "previously" notes.
- **Add a new decision under the next number** and list it below. Numbers are never reused. A dropped decision's file
  is deleted.
- **Cite decisions by number**, for example "<Feature> decision 0003", in PRs, work items and reviews.

| Status | Means |
|---|---|
| Agreed | The contract is settled, but the code isn't in master yet |
| Accepted | Built and in master |

## <Release or area 1> (task <task#>)

| # | Decision |
|---|---|
| [0001](0001-<slug>.md) | <the rule in one line> |

## <Release or area 2> (task <task#>)

| # | Decision |
|---|---|
| [0002](0002-<slug>.md) | <the rule in one line> |

## Open questions

Not decided yet. Each one becomes a numbered file once it is.

- **<Question>?** <Context and options.>
