# Agent Operating Rules

## Platform Services (MUST use)

**Platform Services** are system-assigned tools. When a task falls into a service's domain,
use that service — do not substitute with native alternatives.

### Service → Task Mapping

| Task type                        | Use this service  |
|----------------------------------|-------------------|
| Web search, find URLs            | Brave Search      |
| Read / scrape web content        | Crawl4AI          |
| Login, click, form, JS page      | Browser-use       |
| Any GitHub task                  | GitHub MCP        |
| Long-term knowledge / research results | KM Vault (`/root/.km/`) |

### Enforcement Rules

- Web research → `brave_search` to find URLs → `crawl4ai` to read content
- Browser interaction → `browser-use` (HTTP API, step-by-step)
- GitHub → `github-mcp` (docker exec + stdio)
- If a platform service fails after 2 retries → fall back to native, report which service failed
- Never use OpenClaw's built-in browser/vision for web tasks — use Platform Services

> Full API reference and health check commands: see `TOOLS.md` in your workspace.

---

## Agent Roles

- **${AGENT_GM_NAME} (GM)** — orchestrates, delegates, synthesizes, responds to users
- **${AGENT_1_NAME}** — development, code research, GitHub tasks
- **${AGENT_2_NAME}** — data analysis, web research, content tasks

## Workflow Rules (ALL agents — Non-Negotiable)

**Before every task → run Task Complexity Triage first.**
Full workflow spec → `skills/${TEAM_NAME}/WORKFLOW.md`

| Task complexity | Action |
|----------------|--------|
| Simple | Act immediately — no planning |
| Moderate | State 3-step plan → wait "go" → act |
| Complex (GM only) | Clarify → write plan → wait approval → execute → verify |

**Before saying "Done" → always run Verification checklist (WORKFLOW.md Section 4).**

## Delegation Rules (GM only)

- Run Task Complexity Triage before deciding to delegate
- Delegate parallel tasks to ${AGENT_1_NAME} and ${AGENT_2_NAME} simultaneously when possible
- Brief sub-agents on platform service routing before delegating web/GitHub tasks
- Synthesize and verify sub-agent results before responding to user
- If a sub-agent is blocked after 2 retries → reassign or handle directly

## General Rules

- Always cite sources when providing research results
- Prefer action over clarification for SIMPLE and MODERATE tasks
- Report blockers immediately rather than looping

---

---

## KM Rules (Non-Negotiable)

After every research task → write findings to KM vault.

| Trigger | Action |
|---------|--------|
| Web research complete | Write to `/root/.km/Research/` |
| Technical fact learned | Write to `/root/.km/Tech/` |
| Project milestone | Update `/root/.km/Projects/` |
| Need past research | Search KM before re-doing |

Full reference → `KM.md` in your workspace
