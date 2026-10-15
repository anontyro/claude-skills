# Queries worth having

Most of these are on the provisioned "Claude agents" dashboard
(`grafana/dashboards/claude-agents.json`). Prometheus turns dots into
underscores and appends the unit, so `claude_code.cost.usage` lands as
`claude_code_cost_usage_USD_total`; confirm suffixes in Grafana's metric
browser the first time.

`variant` and `harness` come from `OTEL_RESOURCE_ATTRIBUTES` (promoted to
labels by the collector). Bump `variant` when you change a prompt.

## Cost and tokens

Spend per hour by agent role. Verifiers costing more than builders is a smell:

```promql
sum by (agent_name) (rate(claude_code_cost_usage_USD_total[5m])) * 3600
```

Main vs subagent. On a workflow run this should be overwhelmingly `subagent`:

```promql
sum by (query_source) (increase(claude_code_cost_usage_USD_total[24h]))
```

Cache hit ratio. Low means sibling agents differ in model, effort, tools,
schema or working directory and each pays for the prefix:

```promql
sum(increase(claude_code_token_usage_tokens_total{type="cacheRead"}[1h]))
/
sum(increase(claude_code_token_usage_tokens_total[1h]))
```

Cost of each workflow run in range:

```promql
sum by (workflow_run_id, workflow_name) (increase(claude_code_cost_usage_USD_total{workflow_run_id!=""}[24h]))
```

A/B two prompt variants:

```promql
sum by (variant) (increase(claude_code_cost_usage_USD_total{harness="phoenix"}[7d]))
```

## How Claude Code events land in Loki

Each event's fields (`tool_name`, `duration_ms`, `model`, `success`, …) arrive
as **structured metadata**, and the log body is just the event name
(`claude_code.api_request`). So filter and unwrap directly, without `| json`:

```logql
{service_name="claude-code"} | event_name="api_request" | model="claude-fable-5-1" | unwrap duration_ms
```

The hook's `outcomes.jsonl` / `agents.jsonl` lines are the opposite: JSON in
the body, which the collector's `json_parser` also copies to metadata, so
`| file="outcomes.jsonl" | workflow="…"` works with or without `| json`.

Event names seen so far: `api_request`, `assistant_response`, `user_prompt`,
`tool_result`, `tool_decision`, `subagent_completed`, `skill_activated`,
`hook_execution_start/complete`, `hook_registered`, `mcp_server_connection`,
`permission_mode_changed`, `plugin_loaded`, `at_mention`, `retention_sweep`.
`api_error` appears only when one happens.

## Dashboards

| Dashboard | UID | Question it answers |
|---|---|---|
| Claude agents | `claude-agents` | Cost per role, cache hits, tool failures, permission rejections, workflow outcomes |
| Claude sessions | `claude-sessions` | What did this week cost, per session and per model; Claude time vs my time; lines changed; cost per prompt |
| Claude API & latency | `claude-api` | Request rate and p50/p95 latency per model, cache read ratio, tokens per request, slow requests, errors |
| Claude tools & permissions | `claude-tools` | Which tools fail, how big their results are (context load), which permission prompts keep recurring, hook errors, MCP connections |
| Claude subagents, skills & maintenance | `claude-subagents` | Subagent duration/tokens/tool-use by type, cost by agent/skill/MCP tool, monthly maintenance outcomes |

## Agent health (Loki, Claude Code events)

Tool failure rate, the best single signal that a prompt is wrong:

```logql
sum by (tool_name) (
  count_over_time({service_name="claude-code"} | json | event_name="tool_result" | success="false" [1h])
)
```

Permission rejections (which allow rules are missing):

```promql
sum by (tool_name, decision) (increase(claude_code_code_edit_tool_decision_total[24h]))
```

Reconstruct one workflow run (`workflow.run_id` is in the Workflow tool
result; ask Claude for it):

```logql
{service_name="claude-code"} | json | workflow_run_id="wf_01ABC..."
```

## Outcomes (Loki, from `hooks/log-workflow-result.sh`)

The hook writes `data/outcomes.jsonl` (one line per workflow run) and
`data/agents.jsonl` (one per subagent). The collector tails both as
`service_name="claude-reporting"` with a `file` attribute.

Every run, newest first, one readable line each:

```logql
{service_name="claude-reporting"} | file="outcomes.jsonl"
  | line_format "{{.ts}} {{.workflow}} {{.status}}{{.gate}} spec={{.specPath}} report={{.reportPath}}"
```

review-verify gate results:

```logql
sum by (gate) (count_over_time({service_name="claude-reporting"} | file="outcomes.jsonl" | workflow="review-verify" [7d]))
```

Confirmed vs refuted findings. Refuted climbing faster than confirmed means
reviewers over-report; confirmed with no refuted means verifiers are too
generous:

```logql
sum(sum_over_time({service_name="claude-reporting"} | file="outcomes.jsonl" | workflow="review-verify" | unwrap count_confirmed [7d]))
sum(sum_over_time({service_name="claude-reporting"} | file="outcomes.jsonl" | workflow="review-verify" | unwrap count_refuted   [7d]))
```

build-spec quality score over time, and how many refine findings were applied:

```logql
{service_name="claude-reporting"} | file="outcomes.jsonl" | workflow="build-spec" | unwrap quality_score
{service_name="claude-reporting"} | file="outcomes.jsonl" | workflow="build-spec" | unwrap count_refineFindingsApplied
```

Packages blocked or failed per run (a decomposition problem when it recurs):

```logql
{service_name="claude-reporting"} | file="outcomes.jsonl" | workflow="build-spec" | count_blocked > 0 or count_failed > 0
```

Subagent p95 duration by type. A wide spread inside one wave means one
package is much harder than its siblings:

```logql
quantile_over_time(0.95, {service_name="claude-reporting"} | file="agents.jsonl" | unwrap duration_s [1h]) by (agent_type)
```

## Joining cost to outcomes

`session_id` is in every outcome line and on every Claude Code event and
metric. `tool_use_id` on the outcome line matches the `tool_use_id` of the
Workflow tool's `tool_result` event. There is no join in Grafana across Loki
and Prometheus; use the `variant` label on the cost side and the same
variant's runs on the outcome side, or pull both into a notebook.
