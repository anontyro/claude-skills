# alex-tools: shared Claude Code plugins

| Plugin | What it gives you |
|---|---|
| `spec-plan` | Skill + validator for writing build-ready specs (lanes, packages, owned files, acceptance criteria), and a hook that validates and logs every spec written |
| `session-reporting` | Hooks logging workflow/subagent outcomes, plus an optional local OTel + Grafana stack |

## Use from another repo

```
/plugin marketplace add <github-user>/<repo>   # or a local path to this repo
/plugin install spec-plan@alex-tools
/plugin install session-reporting@alex-tools
```

To commit it for a team, add to the repo's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": { "alex-tools": { "source": { "source": "github", "repo": "<user>/<repo>" } } },
  "enabledPlugins": { "spec-plan@alex-tools": true }
}
```

Develop locally without installing: `claude --plugin-dir ./plugins/spec-plan`.

## Layout

```
.claude-plugin/marketplace.json
plugins/<name>/.claude-plugin/plugin.json
plugins/<name>/skills/<skill>/SKILL.md     skills
plugins/<name>/hooks/hooks.json            hooks (use ${CLAUDE_PLUGIN_ROOT})
```

Per-repo conventions (lanes, check commands, `Docs/` layout) come from each repo's `CLAUDE.md`, not from the plugin.
