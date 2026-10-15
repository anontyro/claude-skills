#!/usr/bin/env bash
# Claude Code hook: append workflow outcomes and subagent completions as JSON
# lines, so the quality axis (confirmed/refuted, complete/blocked, scores) can
# be plotted next to the cost axis that OpenTelemetry already provides.
#
# Registered in .claude/settings.local.json (see ../settings.snippet.json) for:
#   PostToolUse  (matcher "Workflow") -> data/outcomes.jsonl
#   SubagentStop                      -> data/agents.jsonl
#
# Output directory: $CLAUDE_REPORTING_DIR, else <this folder>/../data.
# The otel-collector tails that directory into Loki (otel-collector-config.yaml).
#
# Uses python3 for JSON because node is nvm-managed here and not on the PATH
# hooks run with. Never blocks Claude: always exits 0.

set -u
input="$(cat)"

dir="${CLAUDE_REPORTING_DIR:-}"
if [ -z "$dir" ]; then
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  dir="$here/../data"
fi
mkdir -p "$dir" 2>/dev/null || exit 0

py=$(cat <<'PY'
import json, sys, datetime, re

out_dir = sys.argv[1]
try:
    hook = json.load(sys.stdin)
except Exception:
    sys.exit(0)

def parse_maybe_json(value):
    """tool_response may be a string containing JSON, possibly wrapped in prose."""
    if not isinstance(value, str):
        return value
    s = value.strip()
    if s.startswith('{') or s.startswith('['):
        try:
            return json.loads(s)
        except Exception:
            pass
    m = re.search(r'(\{.*\})', s, re.S)
    if m:
        try:
            return json.loads(m.group(1))
        except Exception:
            pass
    return value

event = hook.get('hook_event_name')
now = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds')
record = {
    'ts': now,
    'event': event,
    'session_id': hook.get('session_id'),
    'cwd': hook.get('cwd'),
}

if event == 'PostToolUse':
    if hook.get('tool_name') != 'Workflow':
        sys.exit(0)
    tool_input = hook.get('tool_input') or {}
    result = parse_maybe_json(hook.get('tool_response'))
    record.update({
        'tool_use_id': hook.get('tool_use_id'),
        'workflow': tool_input.get('name') or tool_input.get('workflow') or 'custom',
        'args': tool_input.get('args'),
        'result': result,
    })
    # Flatten the fields dashboards filter on, so LogQL needs no nesting.
    if isinstance(result, dict):
        for k in ('status', 'gate', 'specPath', 'reportPath'):
            if k in result:
                record[k] = result[k]
        counts = result.get('counts')
        if isinstance(counts, dict):
            for k, v in counts.items():
                record['count_' + k] = v
        quality = result.get('quality')
        if isinstance(quality, dict) and 'lastScore' in quality:
            record['quality_score'] = quality['lastScore']
    target = 'outcomes.jsonl'
elif event == 'SubagentStop':
    record.update({
        'agent_id': hook.get('agent_id'),
        'agent_type': hook.get('agent_type'),
        'duration_s': hook.get('duration'),
    })
    target = 'agents.jsonl'
else:
    sys.exit(0)

with open(f'{out_dir}/{target}', 'a', encoding='utf-8') as fh:
    fh.write(json.dumps(record, ensure_ascii=False) + '\n')
PY
)

printf '%s' "$input" | python3 -c "$py" "$dir" 2>/dev/null
exit 0
