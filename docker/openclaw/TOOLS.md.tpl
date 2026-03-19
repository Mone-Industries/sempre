# My Platform Services — ${AGENT_ID}

## Rule: Always use these services. Never bypass them.

---

## Crawl4AI — Read any webpage

**Trigger:** any URL, webpage, article, docs, public site

```bash
curl -s http://crawl4ai-${AGENT_ID}:11235/crawl \
  -H "Content-Type: application/json" \
  -d '{"urls": ["URL_HERE"]}'
```
Result: `.results[0].markdown.raw_markdown`
**FORBIDDEN alternative:** `web_fetch` ← never use this for webpages

---

## Browser-use — Interact with browser (login, click, JS)

**Trigger:** login, form, click, JS-heavy page, SPA

```bash
curl -s -X POST http://browser-use-${AGENT_ID}:8080/run \
  -H "Content-Type: application/json" \
  -d '{"task": "describe the task in plain English", "max_steps": 20}'
```
Result: `{"ok": true, "result": "..."}`
**FORBIDDEN alternative:** native browser tool ← never use this

---

## GitHub Proxy — All GitHub operations

**Trigger:** repo, issue, PR, file, code search, release, commit — anything GitHub

```bash
GH=http://gh-proxy-${AGENT_ID}:8080

curl -s "$GH/repos/OWNER/REPO/issues?state=open"
curl -s "$GH/repos/OWNER/REPO/contents/PATH"
curl -s "$GH/search/code?q=KEYWORD+repo:OWNER/REPO"
curl -s -X POST "$GH/repos/OWNER/REPO/issues" \
  -H "Content-Type: application/json" \
  -d '{"title": "...", "body": "..."}'
```
No auth header needed — token is pre-injected.
**FORBIDDEN alternative:** `web_fetch` to github.com, direct curl to `api.github.com`

---

## Brave Search — Find URLs / quick facts

**Trigger:** "find", "search", "what is", "latest news"

Use native `brave_search` tool. Then follow up with Crawl4AI for full content.

---

## Google Workspace — Sheets, Docs, Gmail, Drive, Calendar

**Trigger:** Google Sheets, Docs, Gmail, Drive — any Google Workspace task

```bash
# Sheets — read range
gws sheets spreadsheets.values.get \
  --spreadsheetId SHEET_ID --range "Sheet1!A1:Z100"

# Sheets — append row
gws sheets spreadsheets.values.append \
  --spreadsheetId SHEET_ID --range "Sheet1" \
  --valueInputOption USER_ENTERED \
  --body '{"values": [["val1", "val2", "val3"]]}'

# Sheets — update cell
gws sheets spreadsheets.values.update \
  --spreadsheetId SHEET_ID --range "Sheet1!A2" \
  --valueInputOption USER_ENTERED \
  --body '{"values": [["new value"]]}'

# Drive — list files
gws drive files.list --q "name contains 'report'"
```
Auth: auto via `GOOGLE_APPLICATION_CREDENTIALS` — no browser needed.

---

## n8n — Create & Trigger Automations

**Trigger:** recurring task, schedule, multi-service automation, "set up a cron"

```bash
N8N=http://n8n:5678
KEY=${N8N_API_KEY}

# List existing workflows
curl -s "$N8N/api/v1/workflows" -H "X-N8N-API-KEY: $KEY" | jq '.[].name'

# Activate a workflow
curl -s -X PATCH "$N8N/api/v1/workflows/{id}/activate" -H "X-N8N-API-KEY: $KEY"

# Trigger a workflow manually
curl -s -X POST "$N8N/api/v1/workflows/{id}/execute" -H "X-N8N-API-KEY: $KEY"

# Call a webhook (trigger running workflow)
curl -s -X POST "$N8N/webhook/WEBHOOK_PATH" \
  -H "Content-Type: application/json" \
  -H "X-N8N-Webhook-Secret: ${N8N_WEBHOOK_SECRET}" \
  -d '{"task": "...", "data": {}}'
```
Full workflow creation patterns → `skills/${TEAM_NAME}/SKILL.md`

---

Full patterns & examples → `skills/${TEAM_NAME}/SKILL.md`
