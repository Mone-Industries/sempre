# sempre

> *Sempre* — Italian for "always". Your AI team is always on, always working, always learning.

Fork it. Fill in `config.json`. Run `make up`. Your AI company is live.

---

## How It Works

sempre is a **Docker-based multi-agent AI system** built on [OpenClaw](https://openclaw.ai) + [Ollama](https://ollama.com). You define a team of agents, each with a role and tool access. They collaborate, remember things, and get work done.

### The Big Picture

```
You (Discord / Web UI / SSH)
         │
         ▼
┌────────────────────────────────────────────────────────┐
│  nginx  — single SSL entry point (Tailscale cert)      │
│                                                        │
│  :NGINX_OPENCLAW_PORT  ───▶  OpenClaw Web UI           │
│  :NGINX_OLLAMA_PORT    ───▶  Ollama API                │
│  :NGINX_N8N_PORT       ───▶  n8n workflows             │
│  :NGINX_HTTP_PORT      ───▶  444 (rejected — SSL only) │
└──────────────────────┬─────────────────────────────────┘
                       │ HTTPS → HTTP (internal)
                       ▼
┌────────────────────────────────────────────────────────┐
│  openclaw-gateway  :18789                              │
│                                                        │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐               │
│  │  GM     │  │ Agent 1 │  │Agent N… │  ← config.json │
│  └────┬────┘  └────┬────┘  └────┬────┘               │
│       └────────────┼────────────┘                      │
│                    ▼                                    │
│              ollama  (LLM)                              │
│                    │                                    │
│                    ▼  ollama.com Cloud                  │
│         minimax · qwen · gemini · nemotron              │
└────────────────────────────────────────────────────────┘
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
    Per-agent tools (×N agents):
    gh-proxy       crawl4ai     browser-use
    (GitHub API)   (scraper)    (AI browser)

    Shared across all agents:
    /root/.km  (Obsidian KM vault — knowledge base)
    n8n        (workflow automation)
    gws CLI    (Google Workspace)
```

### How Agents Work Together

**GM (General Manager)** receives tasks from users via Discord or Web UI. It triages complexity, delegates to Worker agents in parallel, synthesizes results, and responds.

**Worker agents** run research, code, data extraction, and web tasks concurrently. Each worker has its own isolated tool stack so they never interfere with each other.

**Knowledge compounds over time** — every research result gets written to the shared Obsidian KM vault (`disks/km/`). On the next task, agents search this vault before going to the web. The team gets smarter with every session.

**n8n handles the boring parts** — scheduled reports, data sync, webhook triggers. Agents offload recurring work to n8n so they stay free for actual thinking.

### Tool Routing (enforced)

Agents follow strict platform service routing — they cannot use raw HTTP or native tools for tasks that have a dedicated service.

| Task | Service | How agents call it |
|------|---------|-------------------|
| Web search | Brave Search | native tool |
| Scrape URL → Markdown | Crawl4AI | `http://crawl4ai-{id}:11235/crawl` |
| Login, click, JS pages | Browser-use | `http://browser-use-{id}:8080/run` |
| GitHub REST / GraphQL | gh-proxy | `http://gh-proxy-{id}:8080/{path}` |
| Google Sheets / Docs / Gmail | gws CLI | `gws sheets read ...` (in container) |
| Scheduled automation | n8n | REST API + webhooks |
| Long-term knowledge | KM Vault | `/root/.km/` |

GitHub tokens are injected server-side by gh-proxy — **agents never see the actual token**.

---

## Installation

### 1. Prerequisites

| Tool | Install | Verify |
|------|---------|--------|
| Docker Desktop or OrbStack | [docker.com](https://www.docker.com/products/docker-desktop/) / [orbstack.dev](https://orbstack.dev) | `docker ps` |
| Tailscale | [tailscale.com/download](https://tailscale.com/download) | `tailscale status` |
| jq | `brew install jq` (macOS) · `apt install jq` (Linux) | `jq --version` |

---

### 2. Clone

```bash
git clone https://github.com/YOUR_ORG/sempre.git
cd sempre
```

---

### 3. Create `config.json`

```bash
make config
```

This copies `config.json.example` → `config.json`. Open `config.json` and fill in each section.

> `config.json` is gitignored — it contains your secrets. `config.json.example` is what's committed.

---

### 4. Configure `config.json`

#### Team + Agents

```json
"team": "sempre",
"agents": [
    {
        "id": "mone", "name": "Mone", "role": "gm",
        "discord_token": "", "github_token": "ghp_xxxx",
        "persona": "Direct and decisive team lead. Sets priorities clearly, delegates without hesitation."
    },
    {
        "id": "sam", "name": "Sam", "role": "worker",
        "discord_token": "", "github_token": "ghp_xxxx",
        "persona": "Methodical and detail-oriented. Takes quiet pride in getting things exactly right."
    }
]
```

- `"team"` — names all containers and the Docker network
- One `"gm"` agent required — this is the orchestrator
- Add as many `"worker"` agents as you want
- `"persona"` — unique personality injected into each agent's SOUL.md (they sound different)

#### OpenClaw secrets

```bash
openssl rand -hex 32   # use this for gateway_token
```

```json
"openclaw": {
    "gateway_token":  "paste_output_here",
    "root_password":  "your_ssh_password",
    "gateway_origin": "https://openclaw.sempre.orb.local"
}
```

#### Tailscale hostname + nginx ports

```bash
tailscale status   # find your machine hostname
```

```json
"tailscale_hostname": "your-machine.tailnet.ts.net",
"nginx": {
    "openclaw_port": 20443,
    "ollama_port":   11434,
    "n8n_port":      20678,
    "http_port":     20080
}
```

> `GATEWAY_ORIGIN_EXTRA` (Tailscale CORS origin) is derived automatically from these two fields — no need to set it separately.

#### n8n secrets

```bash
openssl rand -hex 32   # encryption_key — never change after first boot
```

```json
"n8n": {
    "encryption_key": "paste_output_here",
    "password":       "your_n8n_password",
    "webhook_secret": "any_random_string"
}
```

#### LLM models

```json
"llm": {
    "model":         "minimax-m2.7:cloud",
    "models":        "minimax-m2.7:cloud,nemotron-3-super:cloud,nomic-embed-text",
    "browser_model": "nemotron-3-super:cloud"
}
```

> `nomic-embed-text` must be in `models` — it powers semantic search for the KM vault.

#### Brave Search — optional

Get a free key at [brave.com/search/api](https://brave.com/search/api/):

```json
"brave_api_key": "BSA_xxxx"
```

#### Google Workspace — optional

1. [Google Cloud Console](https://console.cloud.google.com) → **IAM & Admin → Service Accounts** → Create → JSON key → download
2. Enable: [Sheets](https://console.cloud.google.com/apis/library/sheets.googleapis.com), [Drive](https://console.cloud.google.com/apis/library/drive.googleapis.com), [Gmail](https://console.cloud.google.com/apis/library/gmail.googleapis.com)
3. Encode locally — **never paste into a website**:

```bash
# macOS
base64 -i /path/to/service-account.json | tr -d '\n'

# Linux
base64 -w0 /path/to/service-account.json
```

```json
"google_service_account_b64": "eyJxxxxxxxx..."
```

---

### 5. Discord bots — optional

1. Go to [discord.com/developers/applications](https://discord.com/developers/applications)
2. Create **one application per agent**
3. **Bot** tab → enable **Message Content Intent** + **Server Members Intent** → copy Token
4. Paste each token into `config.json` as `agents[].discord_token`
5. `make invite-bots` → get invite URLs → add bots to your server

---

### 6. Start

```bash
make up
```

What happens:
1. Validates `config.json` — exits with a clear error if required fields are missing
2. Auto-generates SSL cert via `tailscale cert` if not present
3. Validates docker-compose config
4. Builds custom images
5. Starts all containers

On success:
```
╔══════════════════════════════════════════════════════════════╗
║  ✅  sempre · sempre is running
╠══════════════════════════════════════════════════════════════╣
║
║  🤖  OpenClaw    https://your-machine.ts.net:20443
║  🤖  OpenClaw    https://openclaw.sempre.orb.local  (OrbStack)
║  🔮  Ollama API  https://your-machine.ts.net:11434
║  🔄  n8n         https://your-machine.ts.net:20678
║  🔐  SSH         ssh root@localhost -p 2222
║
║  Agents: mone sam nina
╚══════════════════════════════════════════════════════════════╝
```

---

### 7. First boot: Register Ollama Cloud key

Ollama generates an ed25519 keypair on first start. Cloud models won't work until you register the public key.

```bash
docker logs sempre-ollama 2>&1 | grep ssh-ed25519
```

Copy the `ssh-ed25519 AAAA...` line → [ollama.com/settings/keys](https://ollama.com/settings/keys) → **Add key**.

```bash
docker restart sempre-ollama
```

> Without this step, all cloud models fail with `401`.

---

### 8. First boot: Get n8n API key

1. Open `https://your-machine.ts.net:{NGINX_N8N_PORT}`
2. Log in: `admin@local` / your `n8n.password`
3. **Settings → API Keys → Add API Key** → copy
4. Add to `config.json`:

```json
"n8n": {
    ...
    "api_key": "your_key_here"
}
```

5. Apply: `make restart`

---

## Access

| Service | URL | Auth |
|---------|-----|------|
| **OpenClaw** (Tailscale) | `https://{tailscale_hostname}:{nginx.openclaw_port}` | `openclaw.gateway_token` |
| **OpenClaw** (OrbStack) | `https://openclaw.{team}.orb.local` | same |
| **Ollama API** | `https://{tailscale_hostname}:{nginx.ollama_port}` | — |
| **n8n** | `https://{tailscale_hostname}:{nginx.n8n_port}` | `admin@local` / `n8n.password` |
| **SSH** | `ssh root@localhost -p 2222` | `openclaw.root_password` |

---

## Makefile Reference

### Setup & Config

```bash
make config       # Copy config.json.example → config.json (first time only)
make cert         # Force-regenerate Tailscale SSL cert (auto-runs on make up)
```

### Running

```bash
make up           # Validate → cert (if missing) → build → start everything
make down         # Stop all containers
make restart      # Stop + start (picks up config.json changes)
make generate     # Regenerate .env.generated + compose override from config.json
```

### Logs

```bash
make logs              # Tail all logs
make logs-openclaw     # OpenClaw gateway only
make logs-gh-proxy     # All GitHub proxy instances
make logs-crawl4ai     # All Crawl4AI instances
make logs-browser-use  # All Browser-use instances
```

### Rebuild

```bash
make restart-openclaw   # Rebuild + restart openclaw only
make rebuild-openclaw   # Full down → rebuild image → up
make build              # Rebuild all custom images (no-cache)
```

### Other

```bash
make ssh           # SSH into openclaw container
make shell         # docker exec bash into openclaw
make status        # Container status
make invite-bots   # Discord bot invite URLs
make validate      # Validate docker-compose.yml
make clean         # Remove containers, volumes, and images
```

### When to use what

| Changed | Command |
|---------|---------|
| `config.json` (secrets, ports, agents, models) | `make restart` |
| `docker/openclaw/*.md.tpl` (agent rules/skills) | `make restart` |
| `docker/openclaw/Dockerfile` or `entrypoint.sh` | `make rebuild-openclaw` |
| `docker-compose.yml` or service Dockerfile | `make up` |
| `disks/km/` (knowledge files) | immediate — auto-indexed |

---

## Multiple Teams on One Machine

Each team is a separate clone with its own `config.json`. Differentiate by port.

```bash
git clone ... sempre-team-a
# config.json: "team": "team-a", nginx.openclaw_port: 20443, nginx.n8n_port: 20678

git clone ... sempre-team-b
# config.json: "team": "team-b", nginx.openclaw_port: 20444, nginx.n8n_port: 20679
```

The SSL cert is shared — set `disks.ssl` in both teams to the same path.

---

## `config.json` Reference

| Field | Description | Required |
|-------|-------------|---------|
| `team` | Team name — used for container and network naming | ✓ |
| `agents[].id` | Unique agent ID (lowercase, used in tool endpoints) | ✓ |
| `agents[].name` | Display name | ✓ |
| `agents[].role` | `"gm"` (one) or `"worker"` | ✓ |
| `agents[].persona` | Personality injected into SOUL.md — each agent sounds unique | — |
| `agents[].discord_token` | Discord bot token | — |
| `agents[].github_token` | GitHub Personal Access Token (repo + read:org) | — |
| `disks.*` | Host paths for mounted volumes | ✓ |
| `tailscale_hostname` | Tailscale machine hostname | ✓ |
| `nginx.*_port` | Exposed ports for each service | ✓ |
| `openclaw.gateway_token` | Web UI auth (`openssl rand -hex 32`) | ✓ |
| `openclaw.root_password` | SSH password | — |
| `openclaw.gateway_origin` | Primary CORS origin (OrbStack URL) | — |
| `timezone` | Container timezone | — |
| `km_max_hops` | KM vault wikilink traversal depth | — |
| `llm.model` | Default model for all agents | ✓ |
| `llm.models` | Models to pull + show in UI (include `nomic-embed-text`) | ✓ |
| `llm.browser_model` | Model for browser-use (vision-capable recommended) | — |
| `brave_api_key` | Brave Search API key | — |
| `n8n.encryption_key` | n8n credential encryption (`openssl rand -hex 32`) | ✓ |
| `n8n.password` | n8n login password | — |
| `n8n.webhook_secret` | Shared secret for agent → n8n calls | — |
| `n8n.api_key` | n8n REST API key (generate after first boot) | — |
| `google_service_account_b64` | Google Service Account JSON as base64 | — |

---

## Disk Layout

```
disks/                        ← host-mounted volumes (gitignored)
├── openclaw/
│   ├── openclaw.json         ← generated on first run — edit freely after
│   └── agents/
│       ├── {gm}/workspace/   ← SOUL.md · AGENTS.md · TOOLS.md · IDENTITY.md
│       └── {worker}/workspace/
├── km/                       ← Obsidian KM vault — shared across all agents
│   ├── MOC/                  ← Maps of Content (index)
│   ├── Projects/
│   ├── Research/
│   ├── Tech/
│   └── Daily/
├── ollama/                   ← model weights + ed25519 keypair
├── crawl4ai/                 ← per-agent browser state
└── ssl/                      ← Tailscale SSL certs (auto-generated by make up)
    ├── cert.pem
    └── key.pem
```

Open `disks/km/` in [Obsidian](https://obsidian.md) to browse the knowledge graph visually.

---

## Customizing

| What to change | Edit | Command |
|----------------|------|---------|
| Add / remove agents | `config.json` → `agents[]` | `make restart` |
| Agent personality | `config.json` → `agents[].persona` | `make restart` |
| Agent behavior / rules | `docker/openclaw/SOUL.md.tpl` | `make restart` |
| Communication style | `docker/openclaw/COMMUNICATION.md.tpl` | `make restart` |
| Tool routing rules | `docker/openclaw/SKILL.md.tpl` | `make restart` |
| Task workflow rules | `docker/openclaw/WORKFLOW.md.tpl` | `make restart` |
| KM structure & SOP | `docker/openclaw/KM.md.tpl` | `make restart` |
| LLM model | `config.json` → `llm.model` | `make restart` |
| Add platform service | `docker-compose.yml` + `SKILL.md.tpl` + `SOUL.md.tpl` | `make up` |
| Add agent skill | New `.tpl` → `COPY` in Dockerfile → sync in `entrypoint.sh` | `make rebuild-openclaw` |
| Seed knowledge base | Drop `.md` files into `disks/km/` | immediate |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `make up` fails — config error | Check `openclaw.gateway_token` and `n8n.encryption_key` are not placeholders |
| `Config invalid` on startup | Delete `disks/openclaw/openclaw.json` → `make up` |
| Cloud models fail with 401 | Register ed25519 key at [ollama.com/settings/keys](https://ollama.com/settings/keys) → `docker restart {team}-ollama` |
| Discord bot not responding | Check `agents[].discord_token` in `config.json` + Message Content Intent enabled |
| New agent not appearing | Edit `config.json` → `make restart` |
| HTTPS connection refused | Verify `tailscale_hostname` matches `tailscale status` exactly |
| nginx SSL error | `make cert` to force-regenerate → `docker compose restart nginx` |
| Port conflict | Change `nginx.*_port` in `config.json` → `make restart` |
| n8n API key not working | Generate from n8n UI → Settings → API Keys → add to `config.json` → `make restart` |
| gws auth error | `echo $GOOGLE_SERVICE_ACCOUNT_B64 \| base64 -d \| jq .` to verify |
| Browser-use `CDP not initialized` | `docker restart browser-use-{id}` — recovers automatically |
| KM search returns nothing | Drop `.md` files into `disks/km/` — nomic-embed-text indexes on first query |
| Compose override missing | `make generate` |

---

Built on [OpenClaw](https://openclaw.ai) · Powered by [Ollama](https://ollama.com) · MIT License
