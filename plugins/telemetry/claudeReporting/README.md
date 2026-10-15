# claudeReporting

Local observability for Claude Code multi-agent runs in this repo, plus the
hook that records each workflow's outcome. Self-contained so it can move out
of the repo later (see `docs/HANDOFF.md`, "Moving claudeReporting out").

```
docker compose up -d      # collector :4317, Prometheus :9090, Loki :3100, Tempo :3200, Grafana :3000
./check.sh                # smoke test: services, provisioning, scrape, hook -> Loki
open http://localhost:3000/d/claude-agents
```

| File | Purpose |
|---|---|
| `docker-compose.yml` | The five services, pinned image versions |
| `otel-collector-config.yaml` | OTLP in; Prometheus / Loki / Tempo out; `filelog` tailing `data/*.jsonl` into Loki |
| `prometheus.yml`, `tempo.yaml` | Store configs |
| `grafana/provisioning/` | Datasources and dashboard provider |
| `grafana/dashboards/claude-agents.json` | Cost per role, cache hits, tool failures, permission rejections, workflow outcomes |
| `grafana/dashboards/claude-sessions.json` | Per-session and per-model cost, Claude time vs your time, lines changed, cost per prompt |
| `grafana/dashboards/claude-api.json` | Request rate, p50/p95 latency, cache read ratio, tokens per request, slow requests |
| `grafana/dashboards/claude-tools.json` | Tool failure rates, result sizes (context load), recurring permission prompts, hook errors, MCP connections |
| `grafana/dashboards/claude-subagents.json` | Subagent duration/tokens/tool-use by type, cost by agent/skill/MCP tool, monthly maintenance outcomes |
| `hooks/log-workflow-result.sh` | PostToolUse(Workflow) + SubagentStop hook → `data/outcomes.jsonl`, `data/agents.jsonl` |
| `settings.snippet.json` | Hooks, permissions and OTel env to merge into `.claude/settings.local.json` by hand |
| `claude-otel.env` | Same OTel env for `source ./claude-otel.env && claude` |
| `check.sh` | Smoke test |
| `QUERIES.md` | PromQL / LogQL worth keeping |
| `docs/HANDOFF.md` | Design, lanes, constraints, gaps: read first |
| `docs/CLAUDE.md.fragment.md` | Section to add to CLAUDE.md if/when the workflows are committed |

Gotchas: after adding a new dashboard file, `docker compose restart grafana`;
Docker Desktop's bind mount does not always show new files to a running
container. The same staleness can stop the collector seeing new lines in
`data/*.jsonl`; `./check.sh` catches it (probe line not found) and
`docker compose restart otel-collector` fixes it. The hook command in settings must be an absolute path: Claude Code
sets `CLAUDE_PROJECT_DIR` to the directory it was launched from, so a session
started in `Chinsay.ContractManager.Static` cannot find the hook by a
project-relative path (visible as `num_non_blocking_error` on the
"Hook executions" panel).

Telemetry export is configured in `.claude/settings.local.json` (`env`), so
any Claude Code session started in this repo reports to the local collector
when it is running. When it isn't, Claude Code drops the export silently.
