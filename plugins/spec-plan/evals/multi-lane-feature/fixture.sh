#!/usr/bin/env bash
# Builds the fixture repo this case plans against. Runs in the empty run workspace (needs --scaffold).
set -euo pipefail

mkdir -p "$(dirname 'CLAUDE.md')"
cat > 'CLAUDE.md' <<'EOF'
# users-app
Three lanes, each with its own checks:
- `web` (React, `web/`): `cd web && npm run lint && npm test`
- `api` (Node, `api/`): `cd api && npm run lint && npm test`
- `db` (SQL, `db/`): no local compile. Add numbered scripts `db/migrations/NNN_name.sql`; never edit an applied migration.
API responses use the error shape `{ "error": { "code": string, "message": string } }` (see `api/src/lib/errors.js`).
Paging uses `api/src/lib/pagination.js`. Downloads in the UI use `web/src/components/DownloadButton.jsx`.
EOF
mkdir -p "$(dirname 'web/src/pages/UsersPage.jsx')"
cat > 'web/src/pages/UsersPage.jsx' <<'EOF'
import { UserTable } from "../components/UserTable.jsx";
export function UsersPage({ users }) { return <UserTable users={users} />; }
EOF
mkdir -p "$(dirname 'web/src/components/UserTable.jsx')"
cat > 'web/src/components/UserTable.jsx' <<'EOF'
export function UserTable({ users }) {
  return <table>{users.map(u => <tr key={u.id}><td>{u.name}</td><td>{u.email}</td></tr>)}</table>;
}
EOF
mkdir -p "$(dirname 'web/src/components/DownloadButton.jsx')"
cat > 'web/src/components/DownloadButton.jsx' <<'EOF'
export function DownloadButton({ href, children }) { return <a className="btn" href={href} download>{children}</a>; }
EOF
mkdir -p "$(dirname 'web/test/UserTable.test.jsx')"
cat > 'web/test/UserTable.test.jsx' <<'EOF'
// renders rows for each user
EOF
mkdir -p "$(dirname 'api/src/routes/users.js')"
cat > 'api/src/routes/users.js' <<'EOF'
import { page } from "../lib/pagination.js";
import { fail } from "../lib/errors.js";
import { db } from "../db.js";
export function registerUserRoutes(app) {
  app.get("/api/users", (req, res) => res.json(page(db.query("select * from users"), req.query)));
}
EOF
mkdir -p "$(dirname 'api/src/lib/pagination.js')"
cat > 'api/src/lib/pagination.js' <<'EOF'
export function page(rows, { limit = 50, offset = 0 }) { return rows.slice(Number(offset), Number(offset) + Number(limit)); }
EOF
mkdir -p "$(dirname 'api/src/lib/errors.js')"
cat > 'api/src/lib/errors.js' <<'EOF'
export function fail(res, status, code, message) { res.status(status).json({ error: { code, message } }); }
EOF
mkdir -p "$(dirname 'api/src/db.js')"
cat > 'api/src/db.js' <<'EOF'
export const db = { query: () => [] };
EOF
mkdir -p "$(dirname 'api/test/users.test.js')"
cat > 'api/test/users.test.js' <<'EOF'
// lists users
EOF
mkdir -p "$(dirname 'db/migrations/001_users.sql')"
cat > 'db/migrations/001_users.sql' <<'EOF'
create table users (id int primary key, name text not null, email text not null, role text not null);
EOF

git init -q
git add -A
git -c user.email=eval@example.com -c user.name=eval commit -qm 'fixture'
