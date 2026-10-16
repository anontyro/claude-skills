#!/usr/bin/env bash
# Claude Code hook: whenever a spec under Docs/<Feature>/Specs/*.md is written
# or edited, append one JSON line to specs.jsonl. The line ties the spec to the
# session (session_id joins the OpenTelemetry cost data), the skill version that
# produced it and the git state. Two kinds of row:
#   SpecWritten   - validator result, revision, and whether the spec is approved
#                   (the sha of the first approved row is the base for completion).
#   SpecCompleted - written instead when the spec has a "## Completion" section
#                   (see the spec-complete skill): rating, deviations, packages.
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

spec_text = ''
try:
    spec_text = open(file_path, encoding='utf-8').read()
except Exception:
    pass

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

completion = re.search(r'^## Completion\s*$([\s\S]*?)(?=^## |\Z)', spec_text, re.M)
if completion:
    body = completion.group(1)
    def field(name):
        m = re.search(r'^- ' + name + r':\s*(.+?)\s*$', body, re.M)
        return m.group(1) if m else None
    def ratio(name):
        m = re.match(r'(\d+)\s*/\s*(\d+)', field(name) or '')
        return (int(m.group(1)), int(m.group(2))) if m else (None, None)
    def count(name):
        m = re.match(r'(\d+)', field(name) or '')
        return int(m.group(1)) if m else None
    rating = ratio('Rating')[0]
    done, total = ratio('Packages')
    met, criteria = ratio('Acceptance criteria')
    summary = re.search(r'^### Summary\s*\n+(.+)', body, re.M)
    record.update({
        'event': 'SpecCompleted',
        'completed': field('Completed'),
        'rating': rating,
        'packages_done': done, 'packages_total': total,
        'criteria_met': met, 'criteria_total': criteria,
        'deviations': count('Deviations'),
        'files_outside_owned': count('Files outside ownedFiles'),
        'owned_untouched': count('Owned files untouched'),
        'summary': summary.group(1).strip()[:300] if summary else None,
    })
    row_key = {k: record[k] for k in ('completed', 'rating', 'packages_done', 'packages_total', 'criteria_met',
                                      'deviations', 'files_outside_owned', 'owned_untouched')}
    last = None
    try:
        with open(os.path.join(out_dir, 'specs.jsonl'), encoding='utf-8') as fh:
            for line in fh:
                try:
                    row = json.loads(line)
                except Exception:
                    continue
                if row.get('event') == 'SpecCompleted' and row.get('spec_path') == rel and row.get('repo') == record['repo']:
                    last = {k: row.get(k) for k in row_key}
    except FileNotFoundError:
        pass
    if last != row_key:  # skip re-saves that change nothing
        with open(os.path.join(out_dir, 'specs.jsonl'), 'a', encoding='utf-8') as fh:
            fh.write(json.dumps(record, ensure_ascii=False) + '\n')
    sys.exit(0)

record['approved'] = bool(re.search(r'^Status: \*\*approved', spec_text, re.M))

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
