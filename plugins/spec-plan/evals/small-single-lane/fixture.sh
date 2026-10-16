#!/usr/bin/env bash
# Builds the fixture repo this case plans against. Runs in the empty run workspace (needs --scaffold).
set -euo pipefail

mkdir -p "$(dirname 'CLAUDE.md')"
cat > 'CLAUDE.md' <<'EOF'
# items-cli
Single lane: `cli`. Check commands: `npm test` (node:test) and `npm run lint`.
Source in `src/`, commands in `src/commands/`, tests in `test/*.test.js`.
Output goes through the helpers in `src/format.js`; do not print with console.log directly in commands.
EOF
mkdir -p "$(dirname 'package.json')"
cat > 'package.json' <<'EOF'
{"name":"items-cli","version":"1.0.0","type":"module","scripts":{"test":"node --test","lint":"eslint src test"}}
EOF
mkdir -p "$(dirname 'src/index.js')"
cat > 'src/index.js' <<'EOF'
import { list } from "./commands/list.js";
const [command, ...args] = process.argv.slice(2);
if (command === "list") list(args);
else console.error("usage: items list");
EOF
mkdir -p "$(dirname 'src/commands/list.js')"
cat > 'src/commands/list.js' <<'EOF'
import { loadItems } from "../store.js";
import { formatTable, print } from "../format.js";
export function list() {
  print(formatTable(loadItems(), ["id", "name", "status"]));
}
EOF
mkdir -p "$(dirname 'src/format.js')"
cat > 'src/format.js' <<'EOF'
export function formatTable(rows, columns) {
  return [columns.join("\t"), ...rows.map(r => columns.map(c => r[c]).join("\t"))].join("\n");
}
export function print(text) { process.stdout.write(text + "\n"); }
EOF
mkdir -p "$(dirname 'src/store.js')"
cat > 'src/store.js' <<'EOF'
export function loadItems() {
  return [{ id: 1, name: "alpha", status: "open" }, { id: 2, name: "beta", status: "done" }];
}
EOF
mkdir -p "$(dirname 'test/list.test.js')"
cat > 'test/list.test.js' <<'EOF'
import test from "node:test";
import assert from "node:assert/strict";
import { formatTable } from "../src/format.js";
test("formatTable joins columns", () => {
  assert.equal(formatTable([{ a: 1, b: 2 }], ["a", "b"]), "a\tb\n1\t2");
});
EOF

git init -q
git add -A
git -c user.email=eval@example.com -c user.name=eval commit -qm 'fixture'
