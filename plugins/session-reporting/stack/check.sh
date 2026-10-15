#!/usr/bin/env bash
# Smoke-test the local observability stack.
#
#   docker compose up -d && ./check.sh
#
# Verifies: every service answers, Grafana provisioned the datasources and the
# dashboard, and the collector is tailing the reporting dir into Loki (by writing a
# probe line and querying it back). Exit code is non-zero on any failure.

set -u
cd "$(dirname "$0")"

pass=0; fail=0
ok()   { echo "  ok   $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL $1"; fail=$((fail+1)); }
check_http() { # name url [grep-pattern]
  local body
  body="$(curl -fsS --max-time 5 "$2" 2>/dev/null)" || { bad "$1 ($2)"; return; }
  if [ -n "${3:-}" ] && ! grep -q -- "$3" <<<"$body"; then bad "$1: response missing '$3'"; return; fi
  ok "$1"
}

echo "Services"
check_http "otel-collector health"     "http://localhost:13133/"
check_http "collector metrics endpoint" "http://localhost:8889/metrics"
check_http "prometheus ready"          "http://localhost:9090/-/ready"
check_http "loki ready"                "http://localhost:3100/ready" "ready"
# Tempo's /ready waits ~15s after the ingester joins the ring; retry.
tempo_ok=""
for _ in 1 2 3 4 5 6; do
  curl -fsS --max-time 5 "http://localhost:3200/ready" >/dev/null 2>&1 && { tempo_ok=1; break; }
  sleep 5
done
if [ -n "$tempo_ok" ]; then ok "tempo ready"; else bad "tempo ready (http://localhost:3200/ready, waited 30s)"; fi
check_http "grafana health"            "http://localhost:3000/api/health" '"database": *"ok"'

echo "Grafana provisioning"
check_http "datasource Prometheus" "http://localhost:3000/api/datasources/uid/prometheus" '"uid":"prometheus"'
check_http "datasource Loki"       "http://localhost:3000/api/datasources/uid/loki"       '"uid":"loki"'
check_http "datasource Tempo"      "http://localhost:3000/api/datasources/uid/tempo"      '"uid":"tempo"'
check_http "dashboard Claude agents"    "http://localhost:3000/api/dashboards/uid/claude-agents"    '"title":"Claude agents"'
check_http "dashboard Claude sessions"  "http://localhost:3000/api/dashboards/uid/claude-sessions"  '"title":"Claude sessions"'
check_http "dashboard Claude API"       "http://localhost:3000/api/dashboards/uid/claude-api"       '"title":"Claude API'
check_http "dashboard Claude tools"     "http://localhost:3000/api/dashboards/uid/claude-tools"     '"title":"Claude tools'
check_http "dashboard Claude subagents" "http://localhost:3000/api/dashboards/uid/claude-subagents" '"title":"Claude subagents'

echo "Prometheus scraping the collector"
check_http "target otel-collector up" "http://localhost:9090/api/v1/query?query=up%7Bjob%3D%22otel-collector%22%7D" '"value":\[[0-9.]*,"1"\]'

echo "Outcome pipeline (hook -> filelog -> Loki)"
probe="probe-$(date +%s)"
data="${CLAUDE_REPORTING_DIR:-$HOME/.claude/reporting}"
mkdir -p "$data"
printf '{"hook_event_name":"PostToolUse","tool_name":"Workflow","session_id":"%s","tool_input":{"name":"check-sh"},"tool_response":"{\\"status\\":\\"probe\\"}"}' "$probe" \
  | CLAUDE_REPORTING_DIR="$data" ../hooks/log-workflow-result.sh
if tail -1 "$data/outcomes.jsonl" | grep -q "$probe"; then ok "hook wrote outcomes.jsonl"; else bad "hook did not write outcomes.jsonl"; fi

found=""
for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
  sleep 2
  now_ns=$(( $(date +%s) * 1000000000 ))
  start_ns=$(( now_ns - 600000000000 ))
  q='{service_name="claude-reporting"} |= "'"$probe"'"'
  res="$(curl -fsS --max-time 5 -G "http://localhost:3100/loki/api/v1/query_range" \
        --data-urlencode "query=$q" --data-urlencode "start=$start_ns" --data-urlencode "end=$now_ns" --data-urlencode "limit=5" 2>/dev/null)" || res=""
  if grep -q "$probe" <<<"$res"; then found=1; break; fi
done
if [ -n "$found" ]; then ok "probe line visible in Loki"; else bad "probe line not found in Loki after 24s (check: docker compose logs otel-collector loki)"; fi

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
