# session-reporting

Install: `/plugin install session-reporting@alex-tools` (marketplace root README has the add command).

Two parts:

1. **Hooks (the plugin).** `PostToolUse(Workflow)` and `SubagentStop` append JSON lines to
   `~/.claude/reporting/outcomes.jsonl` and `agents.jsonl` (override with `CLAUDE_REPORTING_DIR`).
   Installed automatically with the plugin; they never block Claude.
2. **Local stack (optional, `stack/`).** Collector, Prometheus, Loki, Tempo and Grafana with 5 dashboards.
   It tails the JSONL above into Loki and receives Claude Code's OpenTelemetry export.

```
cd stack && docker compose up -d
./check.sh                          # smoke test
source ./claude-otel.env && claude  # enable telemetry export for one shell
open http://localhost:3000/d/claude-agents
```

To enable telemetry for every session instead, copy the `export` keys in `stack/claude-otel.env` into the `env`
block of `~/.claude/settings.json`. Set `OTEL_RESOURCE_ATTRIBUTES` (`harness=<repo>,variant=<version>`) per repo to
compare runs.

The "workflow outcome" panels expect results with the fields `status`, `gate`, `counts` and `quality.lastScore`; they stay empty unless a workflow in your repo returns them.

Gotchas: after adding a dashboard file, `docker compose restart grafana`. If the collector stops seeing new JSONL
lines (Docker Desktop bind-mount staleness), `docker compose restart otel-collector`; `check.sh` catches it.
