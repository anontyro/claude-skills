        ---
        max_turns: 40
        timeout_seconds: 900
        allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
        ---

        We've agreed the plan: add a `--json` flag to the `list` command that prints the items as a JSON array instead of the table. Reuse the existing formatting code where it makes sense, add no new dependencies, and ship it in one release. The work item is 12345.

Please write the spec for it so it can be built.
