#!/usr/bin/env bash
# Builds the fixture repo this case plans against. Runs in the empty run workspace (needs --scaffold).
set -euo pipefail

mkdir -p "$(dirname 'CLAUDE.md')"
cat > 'CLAUDE.md' <<'EOF'
# reports-app
Single lane: `app`. Checks: `npm test`, `npm run lint`.
Reports live in `src/reports/`. Auth is handled by `src/auth/session.js` (one user per session, no teams or organisations).
EOF
mkdir -p "$(dirname 'src/reports/report.js')"
cat > 'src/reports/report.js' <<'EOF'
export function createReport(owner, title, rows) { return { id: crypto.randomUUID(), owner, title, rows }; }
EOF
mkdir -p "$(dirname 'src/reports/store.js')"
cat > 'src/reports/store.js' <<'EOF'
const reports = new Map();
export const save = r => reports.set(r.id, r);
export const find = id => reports.get(id);
EOF
mkdir -p "$(dirname 'src/auth/session.js')"
cat > 'src/auth/session.js' <<'EOF'
export function currentUser(req) { return req.session?.userId ?? null; }
EOF

git init -q
git add -A
git -c user.email=eval@example.com -c user.name=eval commit -qm 'fixture'
