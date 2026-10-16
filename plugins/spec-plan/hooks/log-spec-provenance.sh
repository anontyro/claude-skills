#!/usr/bin/env bash
# Claude Code hook: whenever a spec under Docs/<Feature>/Specs/*.md is written
# or edited, validate it and append one JSON line to specs.jsonl. The line ties
# the spec to the session (session_id joins the OpenTelemetry cost data), the
# skill version that produced it, the git state and the validator result.
#
# Registered by this plugin's hooks/hooks.json for PostToolUse (Write|Edit).
# Output: $CLAUDE_REPORTING_DIR, else ~/.claude/reporting/specs.jsonl. If the
# session-reporting stack is running it tails that directory into Loki.
#
# Never blocks Claude: always exits 0.

set -u
input="$(cat)"

dir="${CLAUDE_REPORTING_DIR:-$HOME/.claude/reporting}"
mkdir -p "$dir" 2>/dev/null || exit 0

plugin_root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# node may not be on the PATH hooks run with (nvm, homebrew).
node_bin="$(command -v node 2>/dev/null || true)"
if [ -z "$node_bin" ]; then
  for c in "$HOME"/.nvm/versions/node/*/bin/node /opt/homebrew/bin/node /usr/local/bin/node; do
    [ -x "$c" ] && node_bin="$c"
  done
fi

py=$(cat <<'PY'
import json, sys, os, re, hashlib, subprocess, datetime

out_dir, plugin_root, node_bin = sys.argv[1:4]
try:
    hook = json.load(sys.stdin)
except Exception:
    sys.exit(0)

if hook.get('tool_name') not in ('Write', 'Edit', 'MultiEdit'):
    sys.exit(0)
file_path = (hook.get('tool_input') or {}).get('file_path') or ''
if not re.search(r'(^|/)Docs/[^/]+/Specs/[^/]+\.md$', file_path):
    sys.exit(0)

def run(cmd, cwd):
    try:
        return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=15)
    except Exception:
        return None

spec_dir = os.path.dirname(file_path)
r = run(['git', 'rev-parse', '--show-toplevel'], spec_dir)
repo = r.stdout.strip() if r and r.returncode == 0 else (hook.get('cwd') or spec_dir)
rel = os.path.relpath(file_path, repo)

def git(*args):
    r = run(['git', *args], repo)
    return r.stdout.strip() if r and r.returncode == 0 else None

skill_dir = os.path.join(plugin_root, 'skills', 'spec-plan')
try:
    skill_hash = hashlib.sha256(open(os.path.join(skill_dir, 'SKILL.md'), 'rb').read()).hexdigest()[:8]
except Exception:
    skill_hash = None
try:
    version = json.load(open(os.path.join(plugin_root, '.claude-plugin', 'plugin.json'))).get('version')
except Exception:
    version = None

record = {
    'ts': datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds'),
    'event': 'SpecWritten',
    'session_id': hook.get('session_id'),
    'tool_use_id': hook.get('tool_use_id'),
    'repo': os.path.basename(repo),
    'spec_path': rel,
    'git_sha': git('rev-parse', '--short', 'HEAD'),
    'git_branch': git('rev-parse', '--abbrev-ref', 'HEAD'),
    'skill_version': version,
    'skill_hash': skill_hash,
    'variant': f'spec-plan-{version}-{skill_hash}',
}

# Revision = how many times this session has already written this spec.
target = os.path.join(out_dir, 'specs.jsonl')
revision = 1
try:
    with open(target, encoding='utf-8') as fh:
        for line in fh:
            try:
                row = json.loads(line)
            except Exception:
                continue
            if row.get('session_id') == record['session_id'] and row.get('spec_path') == rel:
                revision += 1
except FileNotFoundError:
    pass
record['revision'] = revision

# Validator result, flattened so LogQL needs no nesting.
validator = os.path.join(skill_dir, 'references', 'validate-spec.mjs')
if node_bin and os.path.exists(validator) and os.path.exists(file_path):
    r = run([node_bin, validator, rel, '--json'], repo)
    try:
        result = json.loads(r.stdout)
        record['errors'] = result.get('errors', [])
        record['warnings'] = result.get('warnings', [])
        record['error_count'] = len(record['errors'])
        record['warning_count'] = len(record['warnings'])
        record['valid'] = record['error_count'] == 0
    except Exception:
        record['validator'] = 'failed'
else:
    record['validator'] = 'unavailable'

with open(target, 'a', encoding='utf-8') as fh:
    fh.write(json.dumps(record, ensure_ascii=False) + '\n')
PY
)

printf '%s' "$input" | python3 -c "$py" "$dir" "$plugin_root" "$node_bin" 2>/dev/null
exit 0
