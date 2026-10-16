---
type: llm
weight: 2
---

The agent wrote a spec for a CSV user export spanning web, api and db lanes.

PASS if all of these hold:
- The Lanes section lists `web`, `api` and `db` as touched, with the check commands from CLAUDE.md for each (db: no local compile, migrations follow the numbered convention, e.g. `db/migrations/002_*.sql`).
- Shared contracts come first. The view/column set and the endpoint's request/response contract are settled in a decision or an early wave-1 package, so the api and web packages do not each guess them.
- The db migration package is in an earlier wave than the api package that reads the view, and the web package depends on the endpoint contract (same wave only if the contract is fully fixed in Decisions).
- Decisions cover what two builders could otherwise choose differently: the route and query parameters, CSV columns and header names, escaping, the error shape (`{ error: { code, message } }` from `api/src/lib/errors.js`), who is allowed to export, and the file name.
- It names existing code to reuse: `DownloadButton`, `pagination` where relevant, `errors.js`.
- `ownedFiles` are exhaustive for each package, in the right lane, and existing paths match the fixture.

FAIL if lanes or check commands are invented, the migration edits `001_users.sql`, two packages in one wave own the same file, key contracts are left to the builders, or existing helpers are ignored in favour of new ones.
