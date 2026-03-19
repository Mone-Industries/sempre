---
name: ${TEAM_NAME}-tools
description: Platform Services rules and usage guide for ${TEAM_NAME}
---

# Platform Services — Rules & Reference

> Your personal service endpoints are in `TOOLS.md` in your workspace.
> Rules in your `SOUL.md` take precedence — read them first.

---

## The Golden Rule

**Every task has exactly one correct service. Use it. No substitution.**

| If the task involves... | Use this service | Never use |
|-------------------------|-----------------|-----------|
| Any URL / webpage / website | **Crawl4AI** | `web_fetch` |
| Login / click / JS / form / SPA | **Browser-use** | native browser tool |
| Anything GitHub | **GitHub Proxy** | `web_fetch`, direct API call |
| Finding URLs / quick facts | **Brave Search** | — |
| Google Sheets / Docs / Gmail / Drive | **gws CLI** | browser-use, direct API |
| Recurring / scheduled / multi-service automation | **n8n** | cron in agent, manual loop |
| Long-term knowledge / research findings | **KM Vault** (`/root/.km/`) | — |

---

## 1. Brave Search

**Triggers:** "find", "search for", "what is", "latest", "who made"

```
brave_search(query="...")
```

Always follow up with Crawl4AI to get full content from the URLs found.

---

## 2. Crawl4AI

**Triggers:** any URL, "read this page", "scrape", "get content from", "what does X website say"

```bash
curl -s http://crawl4ai-{agent}:11235/crawl \
  -H "Content-Type: application/json" \
  -d '{"urls": ["https://example.com"]}'
```
Extract: `.results[0].markdown.raw_markdown`

**If result is empty** → page needs JS → escalate to Browser-use.

---

## 3. Browser-use

**Triggers:** login, click, fill form, navigate JS app, SPA, "open browser and...", page requires auth

```bash
curl -s -X POST http://browser-use-{agent}:8080/run \
  -H "Content-Type: application/json" \
  -d '{"task": "describe the full task in plain English", "max_steps": 20}'
```
Result: `{"ok": true, "result": "..."}`

**Pattern A — JS page, no login (single call):**
```bash
curl -s -X POST http://browser-use-{agent}:8080/run \
  -H "Content-Type: application/json" \
  -d '{"task": "Go to https://example.com, extract the main content and return as text", "max_steps": 20}'
```

**Pattern B — login + extract in one call (simplest, re-logins every time):**
```bash
curl -s -X POST http://browser-use-{agent}:8080/run \
  -H "Content-Type: application/json" \
  -d '{"task": "Login to https://app.example.com with email X and password Y, navigate to /dashboard, extract all data and return as text", "max_steps": 30}'
```

**Pattern C — login once, crawl many pages (cookie handoff to Crawl4AI):**
```bash
# Step 1: login and capture session cookies
RESP=$(curl -s -X POST http://browser-use-{agent}:8080/run \
  -H "Content-Type: application/json" \
  -d '{"task": "Login to https://app.example.com with email X and password Y. Just login, do not navigate further.", "return_cookies": true}')

# Step 2: extract Cookie header string
COOKIE=$(echo "$RESP" | jq -r '.cookies | map(.name + "=" + .value) | join("; ")')

# Step 3: crawl4ai reads multiple pages using the session
curl -s -X POST http://crawl4ai-{agent}:11235/crawl \
  -H "Content-Type: application/json" \
  -d "{\"urls\": [\"https://app.example.com/page1\", \"https://app.example.com/page2\"], \"crawler_config\": {\"headers\": {\"Cookie\": \"$COOKIE\"}}}"
```
Use Pattern C when scraping many pages after login — avoids re-login per page.

**If fails 3×** → report blocker, stop. Do not loop.

---

## 4. GitHub Proxy

**Triggers:** any GitHub task — repo, issue, PR, file, branch, code search, release, commit, workflow, org management, projects

```bash
GH=http://gh-proxy-{agent}:8080
```

No `Authorization` header needed — token is pre-injected server-side.

### Repos & Issues

```bash
curl -s "$GH/repos/OWNER/REPO/issues?state=open"
curl -s "$GH/repos/OWNER/REPO/contents/path/to/file"
curl -s "$GH/search/code?q=KEYWORD+repo:OWNER/REPO"
curl -s "$GH/repos/OWNER/REPO/pulls?state=open"
curl -s "$GH/repos/OWNER/REPO/releases"
curl -s "$GH/repos/OWNER/REPO/actions/workflows"
curl -s "$GH/repos/OWNER/REPO/actions/runs"
```

### Org Management

```bash
# List org repos, members, teams
curl -s "$GH/orgs/ORG/repos?type=all&per_page=100"
curl -s "$GH/orgs/ORG/members"
curl -s "$GH/orgs/ORG/teams"
curl -s "$GH/orgs/ORG/teams/TEAM_SLUG/members"
curl -s "$GH/orgs/ORG/teams/TEAM_SLUG/repos"

# Invite member to org
curl -s -X POST "$GH/orgs/ORG/invitations" \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "role": "direct_member"}'

# Add team member
curl -s -X PUT "$GH/orgs/ORG/teams/TEAM_SLUG/memberships/USERNAME" \
  -H "Content-Type: application/json" \
  -d '{"role": "member"}'

# Add repo to team
curl -s -X PUT "$GH/orgs/ORG/teams/TEAM_SLUG/repos/OWNER/REPO" \
  -H "Content-Type: application/json" \
  -d '{"permission": "push"}'
```

### GitHub Projects v2 (GraphQL — recommended)

```bash
# List org projects
curl -s -X POST "$GH/graphql" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query($org: String!) { organization(login: $org) { projectsV2(first: 20) { nodes { id number title url } } } }",
    "variables": {"org": "ORG"}
  }'

# Get project items
curl -s -X POST "$GH/graphql" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query($id: ID!) { node(id: $id) { ... on ProjectV2 { items(first: 50) { nodes { id content { ... on Issue { title number url } ... on PullRequest { title number url } } } } } } }",
    "variables": {"id": "PROJECT_GLOBAL_ID"}
  }'

# Add issue to project
curl -s -X POST "$GH/graphql" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation($project: ID!, $content: ID!) { addProjectV2ItemById(input: {projectId: $project, contentId: $content}) { item { id } } }",
    "variables": {"project": "PROJECT_GLOBAL_ID", "content": "ISSUE_GLOBAL_ID"}
  }'

# Update project item field
curl -s -X POST "$GH/graphql" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation($project: ID!, $item: ID!, $field: ID!, $value: ProjectV2FieldValue!) { updateProjectV2ItemFieldValue(input: {projectId: $project, itemId: $item, fieldId: $field, value: $value}) { projectV2Item { id } } }",
    "variables": {"project": "PID", "item": "ITEM_ID", "field": "FIELD_ID", "value": {"singleSelectOptionId": "OPTION_ID"}}
  }'

# Create project (org)
curl -s -X POST "$GH/graphql" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation($org: ID!, $title: String!) { createProjectV2(input: {ownerId: $org, title: $title}) { projectV2 { id number url } } }",
    "variables": {"org": "ORG_GLOBAL_ID", "title": "My Project"}
  }'
```

### GitHub Projects Classic (REST — requires preview header)

```bash
# IMPORTANT: Classic Projects need a special Accept header
CLASSIC='-H "Accept: application/vnd.github.inertia-preview+json"'

# List org projects
curl -s $CLASSIC "$GH/orgs/ORG/projects"

# List repo projects
curl -s $CLASSIC "$GH/repos/OWNER/REPO/projects"

# Get project columns
curl -s $CLASSIC "$GH/projects/PROJECT_ID/columns"

# Get column cards
curl -s $CLASSIC "$GH/projects/columns/COLUMN_ID/cards"

# Create a card (issue)
curl -s -X POST $CLASSIC "$GH/projects/columns/COLUMN_ID/cards" \
  -H "Content-Type: application/json" \
  -d '{"content_id": 123, "content_type": "Issue"}'

# Move card
curl -s -X POST $CLASSIC "$GH/projects/columns/cards/CARD_ID/moves" \
  -H "Content-Type: application/json" \
  -d '{"position": "top", "column_id": COLUMN_ID}'
```

### Write — Repos, Issues, PRs

```bash
# Create issue
curl -s -X POST "$GH/repos/OWNER/REPO/issues" \
  -H "Content-Type: application/json" \
  -d '{"title": "...", "body": "...", "labels": ["bug"]}'

# Create PR
curl -s -X POST "$GH/repos/OWNER/REPO/pulls" \
  -H "Content-Type: application/json" \
  -d '{"title": "...", "body": "...", "head": "branch", "base": "main"}'

# Trigger workflow
curl -s -X POST "$GH/repos/OWNER/REPO/actions/workflows/WORKFLOW_ID/dispatches" \
  -H "Content-Type: application/json" \
  -d '{"ref": "main", "inputs": {}}'

# Create/update file
curl -s -X PUT "$GH/repos/OWNER/REPO/contents/path/to/file.txt" \
  -H "Content-Type: application/json" \
  -d '{"message": "commit msg", "content": "BASE64_CONTENT", "sha": "EXISTING_SHA_IF_UPDATE"}'
```

### Pagination

GitHub paginates with `?page=N&per_page=100`. Check `Link` header in response for next page:
```bash
curl -sI "$GH/orgs/ORG/repos?per_page=100" | grep -i link
```

Full API reference: https://docs.github.com/en/rest

---

## 5. Google Workspace (gws CLI)

**Triggers:** Google Sheets, Docs, Gmail, Calendar, Drive, Chat — any Google Workspace task

```bash
# Sheets — read range
gws sheets spreadsheets.values.get \
  --spreadsheetId SHEET_ID --range "Sheet1!A1:Z100"

# Sheets — append row
gws sheets spreadsheets.values.append \
  --spreadsheetId SHEET_ID --range "Sheet1" \
  --valueInputOption USER_ENTERED \
  --body '{"values": [["col1", "col2", "col3"]]}'

# Sheets — update cell
gws sheets spreadsheets.values.update \
  --spreadsheetId SHEET_ID --range "Sheet1!A2" \
  --valueInputOption USER_ENTERED \
  --body '{"values": [["new value"]]}'

# Sheets — create new spreadsheet
gws sheets spreadsheets.create \
  --body '{"properties": {"title": "My Sheet"}}'

# Drive — list files (filter by name)
gws drive files.list --q "name contains 'report'" \
  --fields "files(id,name,webViewLink)"

# Gmail — list recent messages
gws gmail users.messages.list --userId me --maxResults 10
```

Auth: auto via `GOOGLE_APPLICATION_CREDENTIALS` env var (Service Account JSON).
Output: always JSON — pipe to `jq` to extract fields.

**If auth error** → Service Account JSON missing or `GOOGLE_APPLICATION_CREDENTIALS` not set. Check `ls /root/.gws/`.

---

## 6. n8n — Workflow Automation

**Triggers:** "schedule this", "run every day/hour", "automate", "set up a cron", "whenever X do Y", "connect Sheets to Discord"

### Decision: n8n vs direct agent

| Task type | Use |
|-----------|-----|
| One-time task, needs intelligence | Agent directly |
| Repeating on a schedule | **n8n** (Schedule trigger) |
| Chain multiple services (Sheets + Discord + HTTP) | **n8n** (workflow) |
| Respond to external webhook events | **n8n** (Webhook trigger) |
| Needs AI reasoning mid-flow | Agent + n8n hybrid |

**Why n8n?** Agents are a bottleneck — one at a time. n8n runs unlimited parallel workflows independently. Offload repetitive work to n8n, keep agents free for decisions.

### Workflow management API

```bash
N8N=http://n8n:5678
KEY=${N8N_API_KEY}

# List workflows
curl -s "$N8N/api/v1/workflows" -H "X-N8N-API-KEY: $KEY" | jq '.data[] | {id, name, active}'

# Create workflow (POST full JSON definition)
curl -s -X POST "$N8N/api/v1/workflows" \
  -H "X-N8N-API-KEY: $KEY" -H "Content-Type: application/json" \
  -d '{"name": "my-workflow", "nodes": [...], "connections": {}, "settings": {}}'

# Activate / deactivate
curl -s -X PATCH "$N8N/api/v1/workflows/{id}/activate"   -H "X-N8N-API-KEY: $KEY"
curl -s -X PATCH "$N8N/api/v1/workflows/{id}/deactivate" -H "X-N8N-API-KEY: $KEY"

# Trigger manually
curl -s -X POST "$N8N/api/v1/workflows/{id}/execute" -H "X-N8N-API-KEY: $KEY"

# Delete
curl -s -X DELETE "$N8N/api/v1/workflows/{id}" -H "X-N8N-API-KEY: $KEY"
```

### Trigger a running workflow via webhook

```bash
curl -s -X POST http://n8n:5678/webhook/WEBHOOK_PATH \
  -H "Content-Type: application/json" \
  -H "X-N8N-Webhook-Secret: ${N8N_WEBHOOK_SECRET}" \
  -d '{"task": "...", "agent_id": "spike", "data": {}}'
```

### n8n calls agent back (HTTP Request node config)

```
URL:    http://openclaw:18789/api/v1/message
Method: POST
Header: Authorization: Bearer {OPENCLAW_GATEWAY_TOKEN}
Body:   {"agentId": "spike", "content": "workflow result: ..."}
```

### Minimal node templates (for workflow JSON)

```json
// Schedule trigger — every day at 08:00 Bangkok
{ "type": "n8n-nodes-base.scheduleTrigger",
  "parameters": { "rule": { "interval": [{ "field": "cronExpression", "expression": "0 8 * * *" }] } } }

// Webhook trigger with secret header auth
{ "type": "n8n-nodes-base.webhook",
  "parameters": { "path": "ai-task", "authentication": "headerAuth",
    "headerName": "X-N8N-Webhook-Secret", "headerValue": "={{ $env.N8N_WEBHOOK_SECRET }}" } }

// Google Sheets — append row
{ "type": "n8n-nodes-base.googleSheets",
  "parameters": { "operation": "appendOrUpdate", "documentId": "SHEET_ID",
    "sheetName": "Sheet1", "columns": { "mappingMode": "autoMapInputData" } } }

// Discord — send message
{ "type": "n8n-nodes-base.discord",
  "parameters": { "channelId": "CHANNEL_ID", "content": "={{ $json.message }}" } }
```

**UI:** `http://localhost:${N8N_PORT}` (or via Tailscale)
**If `N8N_API_KEY` is empty** → go to n8n UI → Settings → API Keys → generate one → add to `.env`.
**If fails 3×** → report blocker, stop. Do not loop.

---

## 7. Knowledge Management (KM Vault)

**Triggers:** "remember this", "save this", "take note", "research complete", "write to KM", "recall", "what do we know about", "find in memory"

**This is MANDATORY after every research task.**

### Write a note
```bash
cat > /root/.km/{folder}/{kebab-case-title}.md << 'EOF'
---
title: Note Title
tags: [tag1, tag2]
created: $(date +%Y-%m-%d)
agent: ${AGENT_NAME}
---

# Note Title

## Key Points
- Point 1
- Point 2

## Related
- [[MOC/relevant-moc]]
EOF
```

### Search notes (semantic — via OpenClaw memory)
Use built-in memory search tool.

### Search notes (text)
```bash
grep -r "keyword" /root/.km/ --include="*.md" -l
```

### List vault
```bash
find /root/.km -name "*.md" | sort
```

Full vault spec → `skills/${TEAM_NAME}/KM.md`

---

## Health Check

```bash
curl -sf --max-time 5 http://crawl4ai-{agent}:11235/health  && echo "✓ crawl4ai"  || echo "✗ crawl4ai"
curl -sf --max-time 5 http://browser-use-{agent}:8080/health && echo "✓ browser-use" || echo "✗ browser-use"
curl -sf --max-time 5 http://gh-proxy-{agent}:8080/health    && echo "✓ gh-proxy"   || echo "✗ gh-proxy"
curl -sf --max-time 5 http://n8n:5678/healthz                && echo "✓ n8n"        || echo "✗ n8n"
gws auth status 2>/dev/null                                  && echo "✓ gws auth"   || echo "✗ gws auth (check /root/.gws/)"
```

---

## Troubleshooting

| Problem | Action |
|---------|--------|
| Crawl4AI empty content | Page needs JS → retry with Browser-use |
| Browser-use error | Check health, wait 30s (depends on Ollama startup) |
| GitHub 401 | `GITHUB_TOKEN_*` missing in `.env` |
| gws auth error | `/root/.gws/service-account.json` missing or `GOOGLE_APPLICATION_CREDENTIALS` not set |
| n8n unreachable | Run health check; if `N8N_API_KEY` empty → get from n8n UI Settings → API Keys |
| Any service unreachable | Run health check above, report which is down |
| CAPTCHA detected | Stop immediately, report to user |

---

## OpenClaw Self-Configuration

**openclaw.json is the system init config. Breaking it = system won't start.**

Before editing `~/.openclaw/openclaw.json`:
1. Fetch the latest schema from live docs first
2. Validate with `openclaw doctor` before restarting
3. Never add undocumented keys — openclaw rejects unknown fields

| Topic | URL |
|-------|-----|
| Config overview | `https://docs.openclaw.ai/config` |
| agents | `https://docs.openclaw.ai/config/agents` |
| models | `https://docs.openclaw.ai/config/models` |
| tools | `https://docs.openclaw.ai/config/tools` |
| channels/Discord | `https://docs.openclaw.ai/config/channels/discord` |
| gateway | `https://docs.openclaw.ai/config/gateway` |
| MCP servers | `https://docs.openclaw.ai/config/mcp` |

---

## Adding a New Platform Service

1. Add to Service Map in this file
2. Add trigger words and usage example
3. Add health check command
4. Update `TOOLS.md.tpl` with ready-to-use commands
5. Add routing rule to `SOUL.md.tpl`
