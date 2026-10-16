---
type: llm
weight: 2
---

The agent wrote a spec file for adding `--json` to `list` in a small CLI repo.

PASS if all of these hold:
- The spec stays proportionate: one lane (`cli`), one release, and at most three packages. It does not invent a flag, config system, new dependency or extra command that the request did not ask for.
- Every existing file named in `ownedFiles` or the Background section exists in the fixture (for example `src/commands/list.js`, `src/format.js`, `test/list.test.js`). New files are marked as new.
- The spec says to reuse `src/format.js` / `print` rather than printing with console.log, as the repo's CLAUDE.md requires.
- The acceptance criteria are decidable by a test or command, such as "`npm test` passes" or "`items list --json` prints a JSON array", not "works correctly".
- It uses the check commands from CLAUDE.md (`npm test`, `npm run lint`).

FAIL if the spec is padded (several releases or lanes, speculative decisions), cites files that do not exist, or has vague criteria.
