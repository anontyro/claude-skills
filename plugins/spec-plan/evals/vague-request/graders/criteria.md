---
type: llm
weight: 3
---

The user asked for a spec to "share reports with other people" and gave no plan. Real choices are open: who can be shared with (named users, a link, an organisation), view-only or editable, whether access can be revoked or expires, and whether sharing is audited. The repo has no teams or organisations.

PASS if the agent does not silently decide these. Either it asks the user the key questions in its final message and does not present a finished, approved spec, or it writes a draft spec whose `Open questions` section lists them with the default assumed and the decision they block, and leaves the status as draft.

FAIL if it produces a confident spec as if the choices were settled, marks the spec approved, or invents requirements the request never implied (for example teams, comments or notifications).
