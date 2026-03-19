#!/usr/bin/env bash
set -e

TEAM_JSON="/opt/sempre/config.json"

# ---- Decode Google Service Account from base64 env var (if provided) ----
# Store your service-account.json as base64 in .env: GOOGLE_SERVICE_ACCOUNT_B64=$(base64 -i service-account.json)
if [ -n "${GOOGLE_SERVICE_ACCOUNT_B64:-}" ]; then
    mkdir -p /root/.gws
    echo "${GOOGLE_SERVICE_ACCOUNT_B64}" | base64 -d > /root/.gws/service-account.json
    chmod 600 /root/.gws/service-account.json
    echo "[entrypoint] Google Service Account decoded → /root/.gws/service-account.json"
fi

# ---- Set root password for SSH (from env, fallback to "openclaw") ----
ROOT_PASSWORD="${OPENCLAW_ROOT_PASSWORD:-openclaw}"
echo "root:${ROOT_PASSWORD}" | chpasswd

# ---- Start SSH daemon ----
echo "[entrypoint] Starting SSH server on port 22 ..."
/usr/sbin/sshd

# ---- Build GATEWAY_ORIGINS_EXTRA_JSON from comma-separated env ----
# e.g. "http://a:18789,http://b:18789" → ',"http://a:18789","http://b:18789"'
GATEWAY_ORIGINS_EXTRA_JSON=""
if [ -n "${GATEWAY_ORIGIN_EXTRA:-}" ]; then
    IFS=',' read -ra ORIGINS <<< "${GATEWAY_ORIGIN_EXTRA}"
    for origin in "${ORIGINS[@]}"; do
        origin="$(echo "$origin" | xargs)"  # trim whitespace
        [ -n "$origin" ] && GATEWAY_ORIGINS_EXTRA_JSON="${GATEWAY_ORIGINS_EXTRA_JSON},\"${origin}\""
    done
fi
export GATEWAY_ORIGINS_EXTRA_JSON

# ---- Read team config ----
if [ ! -f "$TEAM_JSON" ]; then
    echo "[entrypoint] WARNING: config.json not found at ${TEAM_JSON} — falling back to env vars"
    TEAM_NAME="${TEAM_NAME:-sempre}"
else
    TEAM_NAME=$(jq -r '.team' "$TEAM_JSON")
    echo "[entrypoint] Team: ${TEAM_NAME} ($(jq '.agents | length' "$TEAM_JSON") agents)"
fi

# ---- Initialize OpenClaw Config (First Run Only) ----
# openclaw.json is an init file — once on disk openclaw manages it, we never overwrite
if [ ! -f "/root/.openclaw/openclaw.json" ]; then
    echo "[entrypoint] First run – generating openclaw.json from template ..."
    envsubst < /opt/openclaw-default/openclaw.json.tpl > /root/.openclaw/openclaw.json
    echo "[entrypoint] openclaw.json created."
fi

# ---- Patch gateway.controlUi.allowedOrigins (always — picks up env changes on restart) ----
ORIGINS_JSON="[\"http://localhost:${OPENCLAW_PORT:-18789}\", \"${GATEWAY_ORIGIN}\""
if [ -n "${GATEWAY_ORIGIN_EXTRA:-}" ]; then
    IFS=',' read -ra EXTRA_ORIGINS <<< "${GATEWAY_ORIGIN_EXTRA}"
    for origin in "${EXTRA_ORIGINS[@]}"; do
        origin="$(echo "$origin" | xargs)"
        [ -n "$origin" ] && ORIGINS_JSON="${ORIGINS_JSON}, \"${origin}\""
    done
fi
ORIGINS_JSON="${ORIGINS_JSON}]"

jq --argjson origins "${ORIGINS_JSON}" '
    .gateway.controlUi.allowInsecureAuth = true |
    .gateway.controlUi.allowedOrigins = $origins
' /root/.openclaw/openclaw.json > /tmp/openclaw.json.tmp \
    && mv /tmp/openclaw.json.tmp /root/.openclaw/openclaw.json
echo "[entrypoint] gateway.controlUi patched — allowInsecureAuth=true (HTTP allowed, device auth active), origins=${ORIGINS_JSON}"

# ---- Patch openclaw.json agents from team.json (always — picks up team changes on restart) ----
if [ -f "$TEAM_JSON" ]; then
    # Build agents.list
    AGENTS_JSON=$(jq \
        --arg model "${OLLAMA_MODEL:-minimax-m2.5:cloud}" \
        '([.agents[].id]) as $all_ids |
        .agents | to_entries | map({
            "id":        .value.id,
            "name":      .value.name,
            "workspace": ("/root/.openclaw/agents/" + .value.id + "/workspace"),
            "model":     ("ollama/" + $model),
            "default":   (.key == 0),
            "subagents": { "allowAgents": $all_ids }
        })' "$TEAM_JSON")

    # Build bindings
    BINDINGS_JSON=$(jq '[.agents[] | {
        "agentId": .id,
        "match": { "channel": "discord", "accountId": (.id + "-ai") }
    }]' "$TEAM_JSON")

    # Build Discord accounts (read tokens from env by agent ID)
    ACCOUNTS_JSON="{\"default\":{\"groupPolicy\":\"allowlist\",\"streaming\":\"off\"}}"
    while IFS= read -r agent; do
        agent_id=$(echo "$agent" | jq -r '.id')
        token_var="DISCORD_BOT_TOKEN_${agent_id}"
        token="${!token_var:-}"
        account_id="${agent_id}-ai"
        ACCOUNTS_JSON=$(echo "$ACCOUNTS_JSON" | jq \
            --arg key "$account_id" \
            --arg token "$token" \
            '.[$key] = { "enabled": true, "token": $token, "allowBots": true, "groupPolicy": "allowlist", "streaming": "off" }')
    done < <(jq -c '.agents[]' "$TEAM_JSON")

    # Build agentToAgent allow list
    ALL_IDS=$(jq '[.agents[].id]' "$TEAM_JSON")

    jq \
        --argjson agents  "$AGENTS_JSON" \
        --argjson bindings "$BINDINGS_JSON" \
        --argjson accounts "$ACCOUNTS_JSON" \
        --argjson all_ids  "$ALL_IDS" \
        '.agents.list                        = $agents  |
         .bindings                           = $bindings |
         .channels.discord.accounts          = $accounts |
         .tools.agentToAgent.allow           = $all_ids' \
        /root/.openclaw/openclaw.json > /tmp/openclaw.json.tmp \
        && mv /tmp/openclaw.json.tmp /root/.openclaw/openclaw.json
    echo "[entrypoint] openclaw.json agents patched — $(jq '.agents | length' "$TEAM_JSON") agents from team.json"
fi

# ---- Install Team Skills (always overwrite — picks up updates on restart) ----
SKILL_DIR="/root/.openclaw/skills/${TEAM_NAME}"
mkdir -p "${SKILL_DIR}"
TEAM_NAME="${TEAM_NAME}" envsubst '${TEAM_NAME}' \
    < /opt/openclaw-default/SKILL.md.tpl \
    > "${SKILL_DIR}/SKILL.md"
TEAM_NAME="${TEAM_NAME}" KM_MAX_HOPS="${KM_MAX_HOPS:-2}" envsubst '${KM_MAX_HOPS} ${TEAM_NAME}' \
    < /opt/openclaw-default/KM.md.tpl \
    > "${SKILL_DIR}/KM.md"
TEAM_NAME="${TEAM_NAME}" envsubst '${TEAM_NAME}' \
    < /opt/openclaw-default/WORKFLOW.md.tpl \
    > "${SKILL_DIR}/WORKFLOW.md"
TEAM_NAME="${TEAM_NAME}" envsubst '${TEAM_NAME}' \
    < /opt/openclaw-default/COMMUNICATION.md.tpl \
    > "${SKILL_DIR}/COMMUNICATION.md"
echo "[entrypoint] ${TEAM_NAME} skills installed → .openclaw/skills/${TEAM_NAME}/ (SKILL, KM, WORKFLOW, COMMUNICATION)"

# ---- Install UI UX Pro Max Skill (always overwrite — latest on every restart) ----
echo "[entrypoint] Installing ui-ux-pro-max skill from GitHub ..."
if git clone --depth 1 --quiet https://github.com/nextlevelbuilder/ui-ux-pro-max-skill /tmp/ui-ux-pro-max-skill 2>/dev/null; then
    cp -r /tmp/ui-ux-pro-max-skill/.claude/skills/* /root/.openclaw/skills/
    rm -rf /tmp/ui-ux-pro-max-skill
    echo "[entrypoint] ui-ux-pro-max skill installed → .openclaw/skills/"
else
    echo "[entrypoint] WARNING: Failed to clone ui-ux-pro-max skill (no internet?), skipping."
fi

# ---- Generate AGENTS.md dynamically from team.json ----
generate_agents_md() {
    local workspace="$1"
    local current_id="$2"

    if [ ! -f "$TEAM_JSON" ]; then return; fi

    local gm_name
    gm_name=$(jq -r '.agents[] | select(.role == "gm") | .name' "$TEAM_JSON" | head -1)

    # Build roster lines
    local roster_lines
    roster_lines=$(jq -r '.agents[] |
        "- **" + .name + (if .role == "gm" then " (GM)**" else "**" end) +
        " — " + (if .role == "gm"
            then "orchestrates, delegates, synthesizes, responds to users"
            else "parallel worker for research, code, data, and web tasks" end)
        ' "$TEAM_JSON")

    # Build worker names list (for delegation rules)
    local worker_list
    worker_list=$(jq -r '[.agents[] | select(.role != "gm") | .name] | join(" and ")' "$TEAM_JSON")

    # Write AGENTS.md
    {
        echo "# Agent Operating Rules"
        echo ""
        echo "## Platform Services (MUST use)"
        echo ""
        echo "**Platform Services** are system-assigned tools. When a task falls into a service's domain,"
        echo "use that service — do not substitute with native alternatives."
        echo ""
        echo "### Service → Task Mapping"
        echo ""
        echo "| Task type                              | Use this service                  |"
        echo "|----------------------------------------|-----------------------------------|"
        echo "| Web search, find URLs                  | Brave Search                      |"
        echo "| Read / scrape web content              | Crawl4AI                          |"
        echo "| Login, click, form, JS page            | Browser-use                       |"
        echo "| Any GitHub task                        | gh-proxy (HTTP, token pre-injected) |"
        echo "| Long-term knowledge / research results | KM Vault (\`/root/.km/\`)          |"
        echo ""
        echo "### Enforcement Rules"
        echo ""
        echo "- Web research → \`brave_search\` to find URLs → \`crawl4ai\` to read content"
        echo "- Browser interaction → \`browser-use\` (HTTP API, step-by-step)"
        echo "- GitHub → \`http://gh-proxy-{your-id}:8080/{github-api-path}\` (plain HTTP, token pre-injected)"
        echo "- If a platform service fails after 2 retries → fall back to native, report which service failed"
        echo "- Never use OpenClaw's built-in browser/vision for web tasks — use Platform Services"
        echo ""
        echo "> Full API reference and health check commands: see \`TOOLS.md\` in your workspace."
        echo ""
        echo "---"
        echo ""
        echo "## Agent Roles"
        echo ""
        echo "$roster_lines"
        echo ""
        echo "## Workflow Rules (ALL agents — Non-Negotiable)"
        echo ""
        echo "**Before every task → run Task Complexity Triage first.**"
        echo "Full workflow spec → \`skills/${TEAM_NAME}/WORKFLOW.md\`"
        echo ""
        echo "| Task complexity | Action |"
        echo "|----------------|--------|"
        echo "| Simple | Act immediately — no planning |"
        echo "| Moderate | State 3-step plan → wait \"go\" → act |"
        echo "| Complex (GM only) | Clarify → write plan → wait approval → execute → verify |"
        echo ""
        echo "**Before saying \"Done\" → always run Verification checklist (WORKFLOW.md Section 4).**"
        echo ""
        echo "## Delegation Rules (${gm_name} only)"
        echo ""
        echo "- Run Task Complexity Triage before deciding to delegate"
        echo "- Delegate parallel tasks to ${worker_list} simultaneously when possible"
        echo "- Brief sub-agents on platform service routing before delegating web/GitHub tasks"
        echo "- Synthesize and verify sub-agent results before responding to user"
        echo "- If a sub-agent is blocked after 2 retries → reassign or handle directly"
        echo ""
        echo "## General Rules"
        echo ""
        echo "- Always cite sources when providing research results"
        echo "- Prefer action over clarification for SIMPLE and MODERATE tasks"
        echo "- Report blockers immediately rather than looping"
        echo ""
        echo "---"
        echo ""
        echo "---"
        echo ""
        echo "## KM Rules (Non-Negotiable)"
        echo ""
        echo "After every research task → write findings to KM vault."
        echo ""
        echo "| Trigger | Action |"
        echo "|---------|--------|"
        echo "| Web research complete | Write to \`/root/.km/Research/\` |"
        echo "| Technical fact learned | Write to \`/root/.km/Tech/\` |"
        echo "| Project milestone | Update \`/root/.km/Projects/\` |"
        echo "| Need past research | Search KM before re-doing |"
        echo ""
        echo "Full reference → \`KM.md\` in your workspace"
    } > "${workspace}/AGENTS.md"
}

# ---- Seed Workspace Files (dynamic — loops all agents from team.json) ----
seed_workspace() {
    local workspace="$1"
    local agent_id="$2"
    local agent_name="$3"
    local agent_persona="$4"
    local first_run=false

    mkdir -p "${workspace}"

    # First-run only files (user may customise these)
    if [ ! -f "${workspace}/IDENTITY.md" ]; then
        first_run=true
        echo "[entrypoint] First run — seeding workspace for ${agent_name} (${agent_id}) ..."
        cp /opt/openclaw-default/USER.md      "${workspace}/USER.md"
        cp /opt/openclaw-default/HEARTBEAT.md "${workspace}/HEARTBEAT.md"
        AGENT_ID="${agent_id}" AGENT_NAME="${agent_name}" envsubst \
            < /opt/openclaw-default/IDENTITY.md.tpl \
            > "${workspace}/IDENTITY.md"
    fi

    # Always-overwrite: TOOLS.md and SOUL.md (from templates)
    AGENT_ID="${agent_id}" TEAM_NAME="${TEAM_NAME}" envsubst '${AGENT_ID} ${TEAM_NAME}' \
        < /opt/openclaw-default/TOOLS.md.tpl \
        > "${workspace}/TOOLS.md"
    AGENT_ID="${agent_id}" AGENT_NAME="${agent_name}" TEAM_NAME="${TEAM_NAME}" AGENT_PERSONA="${agent_persona}" \
        envsubst '${AGENT_ID} ${AGENT_NAME} ${TEAM_NAME} ${AGENT_PERSONA}' \
        < /opt/openclaw-default/SOUL.md.tpl \
        > "${workspace}/SOUL.md"

    # Always-overwrite: AGENTS.md (generated dynamically from team.json)
    generate_agents_md "${workspace}" "${agent_id}"

    if [ "$first_run" = true ]; then
        echo "[entrypoint] Workspace seeded for ${agent_name}."
    else
        echo "[entrypoint] Rules updated for ${agent_name} (TOOLS, SOUL, AGENTS)."
    fi
}

# Loop all agents from team.json
if [ -f "$TEAM_JSON" ]; then
    agent_count=$(jq '.agents | length' "$TEAM_JSON")
    for i in $(seq 0 $((agent_count - 1))); do
        agent_id=$(jq -r ".agents[$i].id" "$TEAM_JSON")
        agent_name=$(jq -r ".agents[$i].name" "$TEAM_JSON")
        agent_persona=$(jq -r ".agents[$i].persona // \"\"" "$TEAM_JSON")
        seed_workspace "/root/.openclaw/agents/${agent_id}/workspace" "${agent_id}" "${agent_name}" "${agent_persona}"
    done
else
    # Fallback: legacy env var mode (backward compat, 3 agents)
    echo "[entrypoint] WARNING: No team.json — using legacy AGENT_* env vars"
    seed_workspace "/root/.openclaw/agents/${AGENT_GM_ID:-mone}/workspace"  "${AGENT_GM_ID:-mone}"  "${AGENT_GM_NAME:-GM}"
    seed_workspace "/root/.openclaw/agents/${AGENT_1_ID:-agent1}/workspace" "${AGENT_1_ID:-agent1}" "${AGENT_1_NAME:-Agent1}"
    seed_workspace "/root/.openclaw/agents/${AGENT_2_ID:-agent2}/workspace" "${AGENT_2_ID:-agent2}" "${AGENT_2_NAME:-Agent2}"
fi

# ---- Verify tool container DNS + connectivity (background, non-blocking) ----
(
    echo "[entrypoint] Waiting 15s before connectivity check ..."
    sleep 15
    echo "[entrypoint] ============ Tool Connectivity Check ============"
    all_ok=true

    if [ -f "$TEAM_JSON" ]; then
        agent_ids=$(jq -r '.agents[].id' "$TEAM_JSON")
    else
        agent_ids="${AGENT_GM_ID:-mone} ${AGENT_1_ID:-agent1} ${AGENT_2_ID:-agent2}"
    fi

    for id in $agent_ids; do
        # crawl4ai — HTTP health
        if curl -sf --max-time 5 "http://crawl4ai-${id}:11235/health" > /dev/null 2>&1; then
            echo "[entrypoint] ✓ crawl4ai-${id}:11235"
        else
            echo "[entrypoint] ✗ crawl4ai-${id}:11235  (unreachable)"
            all_ok=false
        fi
        # browser-use — HTTP health
        if curl -sf --max-time 5 "http://browser-use-${id}:8080/health" > /dev/null 2>&1; then
            echo "[entrypoint] ✓ browser-use-${id}:8080"
        else
            echo "[entrypoint] ✗ browser-use-${id}:8080  (unreachable)"
            all_ok=false
        fi
        # gh-proxy — HTTP health
        if curl -sf --max-time 5 "http://gh-proxy-${id}:8080/health" > /dev/null 2>&1; then
            echo "[entrypoint] ✓ gh-proxy-${id}:8080"
        else
            echo "[entrypoint] ✗ gh-proxy-${id}:8080  (unreachable)"
            all_ok=false
        fi
    done
    if [ "$all_ok" = true ]; then
        echo "[entrypoint] ✓ All tool containers reachable"
    else
        echo "[entrypoint] ⚠ Some tools unreachable — agents may have limited capabilities"
    fi
    echo "[entrypoint] =================================================="
) &

# ---- Patch models list in openclaw.json from OLLAMA_MODELS env (always — picks up env changes on restart) ----
if [ -n "${OLLAMA_MODELS:-}" ]; then
    CHAT_MODELS_JSON="[]"
    IFS=',' read -ra _MODELS <<< "${OLLAMA_MODELS}"
    for model in "${_MODELS[@]}"; do
        [[ "$model" == *"embed"* ]] && continue
        name=$(echo "$model" | sed 's/:.*$//' | sed 's/[-_.]/ /g' \
            | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')
        CHAT_MODELS_JSON=$(echo "$CHAT_MODELS_JSON" | jq \
            --arg id "$model" --arg name "$name" \
            '. + [{"id": $id, "name": $name, "reasoning": true}]')
    done
    jq --argjson models "$CHAT_MODELS_JSON" \
        '.models.providers.ollama.models = $models' \
        /root/.openclaw/openclaw.json > /tmp/openclaw.json.tmp \
        && mv /tmp/openclaw.json.tmp /root/.openclaw/openclaw.json
    echo "[entrypoint] models.providers.ollama.models patched — $(echo "$CHAT_MODELS_JSON" | jq 'length') models"
fi

# ---- Pull Ollama models (background, non-blocking) ----
(
    echo "[entrypoint] Waiting for Ollama to be ready ..."
    until curl -sf http://ollama:11434/api/tags > /dev/null 2>&1; do sleep 2; done
    echo "[entrypoint] Ollama ready — pulling models ..."
    IFS=',' read -ra _PULL_MODELS <<< "${OLLAMA_MODELS:-}"
    for model in "${_PULL_MODELS[@]}"; do
        echo "[entrypoint] Pulling ${model} ..."
        curl -sf http://ollama:11434/api/pull -d "{\"name\":\"${model}\"}" > /dev/null && \
            echo "[entrypoint] ✓ ${model}" || \
            echo "[entrypoint] ✗ ${model} failed (skipping)"
    done
    echo "[entrypoint] Model pull complete."
) &

# ---- Start OpenClaw gateway ----
echo "[entrypoint] Starting OpenClaw gateway ..."
cd /opt/openclaw

GATEWAY_ARGS=(
    "--bind" "${OPENCLAW_GATEWAY_BIND:-lan}"
    "--port" "18789"
    "--allow-unconfigured"
)

if [ -n "${OPENCLAW_GATEWAY_TOKEN:-}" ] && [ "${OPENCLAW_GATEWAY_TOKEN}" != "CHANGE_ME_GENERATE_STRONG_TOKEN" ]; then
    GATEWAY_ARGS+=("--token" "${OPENCLAW_GATEWAY_TOKEN}")
fi

exec node dist/index.js gateway "${GATEWAY_ARGS[@]}"
