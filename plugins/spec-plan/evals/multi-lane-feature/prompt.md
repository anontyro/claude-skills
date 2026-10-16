        ---
        max_turns: 40
        timeout_seconds: 900
        allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
        ---

        We've agreed the plan: admins can export the user list as a CSV file. There is a button on the Users page, a `GET /api/users/export` endpoint, and a database view `users_export` so the query stays out of the route code. One release, no feature flag. The work item is 23456.

Please write the spec so parallel builders can build it.
