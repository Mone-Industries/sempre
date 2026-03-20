# ==============================================================================
# sempre – Makefile
# ==============================================================================
SHELL := /bin/bash

CFG                := config.json
COMPOSE            := docker compose --env-file .env.generated

TEAM               := $(shell jq -r '.team'                    $(CFG) 2>/dev/null || echo "sempre")
export TEAM_NAME   := $(TEAM)
TAILSCALE_HOSTNAME := $(shell jq -r '.tailscale_hostname'      $(CFG) 2>/dev/null)
NGINX_OPENCLAW_PORT := $(shell jq -r '.nginx.openclaw_port'    $(CFG) 2>/dev/null || echo "20443")
NGINX_OLLAMA_PORT  := $(shell jq -r '.nginx.ollama_port'       $(CFG) 2>/dev/null || echo "11434")
NGINX_N8N_PORT     := $(shell jq -r '.nginx.n8n_port'          $(CFG) 2>/dev/null || echo "20678")
HOST_SSL_DIR       := $(shell jq -r '.disks.ssl'               $(CFG) 2>/dev/null | sed 's|~|$(HOME)|')
SSH_PASS           := $(shell jq -r '.openclaw.root_password'  $(CFG) 2>/dev/null || echo "openclaw")
AGENT_IDS          := $(shell jq -r '.agents[].id'             $(CFG) 2>/dev/null | tr '\n' ' ')

.PHONY: help config generate build up down restart restart-openclaw rebuild-openclaw \
        logs logs-openclaw logs-gh-proxy logs-crawl4ai logs-browser-use \
        ssh shell status validate clean cert invite-bots \
        _check-config _ensure-env _ensure-cert

# ==============================================================================
# Help
# ==============================================================================
help:
	@echo ""
	@echo "  sempre — Multi-Agent AI System"
	@echo "  ══════════════════════════════════════════════════"
	@echo ""
	@echo "  First-time setup:"
	@echo "    make config       Copy config.json.example → config.json"
	@echo "    make cert         Generate Tailscale SSL cert (run once)"
	@echo "    make up           Build images + start everything"
	@echo ""
	@echo "  Daily:"
	@echo "    make up           Start (or restart after config change)"
	@echo "    make down         Stop all services"
	@echo "    make restart      Stop + start"
	@echo "    make logs         Tail all logs"
	@echo "    make status       Container status"
	@echo ""
	@echo "  Agent logs:"
	@echo "    make logs-openclaw     OpenClaw gateway"
	@echo "    make logs-gh-proxy     All GitHub proxies"
	@echo "    make logs-crawl4ai     All Crawl4AI instances"
	@echo "    make logs-browser-use  All Browser-use instances"
	@echo ""
	@echo "  Access:"
	@echo "    make ssh          SSH into OpenClaw container"
	@echo "    make shell        Exec bash into OpenClaw (no SSH)"
	@echo "    make invite-bots  Show Discord bot invite URLs"
	@echo ""
	@echo "  Rebuild:"
	@echo "    make restart-openclaw   Rebuild + restart openclaw only"
	@echo "    make rebuild-openclaw   Full down → rebuild → up"
	@echo "    make build              Rebuild all custom images (no-cache)"
	@echo ""
	@echo "  Other:"
	@echo "    make generate     Regenerate compose override + .env.generated"
	@echo "    make validate     Validate docker-compose.yml"
	@echo "    make clean        Remove containers, volumes, and images"
	@echo ""
	@echo "  ──────────────────────────────────────────────────"
	@echo "  Team:   $(TEAM)"
	@echo "  Agents: $(AGENT_IDS)"
	@echo ""

# ==============================================================================
# Setup
# ==============================================================================
config:
	@if [ ! -f config.json ]; then \
		cp config.json.example config.json; \
		echo "✅ Created config.json — edit it and fill in your values"; \
	else \
		echo "⚠️  config.json already exists, skipping"; \
	fi

# ==============================================================================
# Generate (always fresh)
# ==============================================================================
generate: _check-config
	@bash scripts/generate.sh

# Lightweight: only generate if .env.generated is missing
_ensure-env:
	@[ -f .env.generated ] || bash scripts/generate.sh

# ==============================================================================
# Validation
# ==============================================================================
_check-config:
	@if [ ! -f $(CFG) ]; then \
		echo "❌ config.json not found — run: make config"; \
		exit 1; \
	fi
	@echo "🔍 Validating config.json ..." && \
	error=0 && \
	token=$$(jq -r '.openclaw.gateway_token' $(CFG)) && \
	if [ -z "$$token" ] || [ "$$token" = "null" ]; then \
		echo "❌ openclaw.gateway_token is empty → run: openssl rand -hex 32"; error=1; \
	elif echo "$$token" | grep -q "CHANGE_ME"; then \
		echo "❌ openclaw.gateway_token is still the default → run: openssl rand -hex 32"; error=1; \
	fi && \
	enc=$$(jq -r '.n8n.encryption_key' $(CFG)) && \
	if echo "$$enc" | grep -q "CHANGE_ME"; then \
		echo "❌ n8n.encryption_key is still the default → run: openssl rand -hex 32"; error=1; \
	fi && \
	while IFS= read -r agent; do \
		id=$$(echo "$$agent" | jq -r '.id'); \
		github=$$(echo "$$agent" | jq -r '.github_token // ""'); \
		discord=$$(echo "$$agent" | jq -r '.discord_token // ""'); \
		if [ -z "$$github" ] || [ "$$github" = "ghp_xxxx" ]; then \
			echo "⚠️  agents[$$id].github_token not set — GitHub disabled for $$id"; \
		fi; \
		if [ -z "$$discord" ]; then \
			echo "⚠️  agents[$$id].discord_token not set — Discord disabled for $$id"; \
		fi; \
	done < <(jq -c '.agents[]' $(CFG)) && \
	brave=$$(jq -r '.brave_api_key' $(CFG)) && \
	if [ -z "$$brave" ] || [ "$$brave" = "BSA_xxxx" ] || [ "$$brave" = "null" ]; then \
		echo "⚠️  brave_api_key not set — Brave Search disabled"; \
	fi && \
	if [ "$$error" = "1" ]; then echo "" && echo "   Fix the above in config.json then retry." && exit 1; fi && \
	echo "✅ config.json validation passed"

# ==============================================================================
# SSL Certificate
# ==============================================================================
_ensure-cert:
	@if [ ! -f "$(HOST_SSL_DIR)/cert.pem" ]; then \
		echo "🔐 SSL cert not found — generating via Tailscale ..."; \
		$(MAKE) cert; \
	fi

cert: _check-config
	@if [ -z "$(TAILSCALE_HOSTNAME)" ]; then \
		echo "❌ tailscale_hostname not set in config.json"; exit 1; \
	fi
	@mkdir -p $(HOST_SSL_DIR)
	tailscale cert \
		--cert-file $(HOST_SSL_DIR)/cert.pem \
		--key-file  $(HOST_SSL_DIR)/key.pem \
		$(TAILSCALE_HOSTNAME)
	@echo "✅ Certificate saved → $(HOST_SSL_DIR)/"

# ==============================================================================
# Discord Bots
# ==============================================================================
invite-bots: _ensure-env
	@echo ""
	@echo "  🤖 Discord Bot Invite Links"
	@echo "  ──────────────────────────────────────────────────"
	@echo "  1. Create $(shell jq '.agents | length' $(CFG) 2>/dev/null || echo "N") apps at: https://discord.com/developers/applications"
	@echo "  2. Enable Message Content Intent + Server Members Intent for each"
	@echo "  3. Replace YOUR_CLIENT_ID below with each app's Client ID:"
	@echo ""
	@jq -r '.agents[] | "  \(.name) (\(.role)):\n  https://discord.com/api/oauth2/authorize?client_id=YOUR_CLIENT_ID&permissions=274877958144&scope=bot\n"' $(CFG) 2>/dev/null
	@echo ""

# ==============================================================================
# Build
# ==============================================================================
build: _ensure-env
	@echo "🔨 Building custom Docker images (no-cache) ..."
	$(COMPOSE) build --no-cache

# ==============================================================================
# Up / Down
# ==============================================================================
up: generate _ensure-cert
	@echo "🔍 Validating docker-compose ..."
	@$(COMPOSE) config --quiet && echo "✅ docker-compose config OK"
	@echo "🔨 Building images ..."
	@$(COMPOSE) build
	@echo "🚀 Starting all services ..."
	$(COMPOSE) up -d
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════════╗"
	@echo "║  ✅  sempre · $(TEAM) is running"
	@echo "╠══════════════════════════════════════════════════════════════╣"
	@echo "║"
	@echo "║  🤖  OpenClaw    https://$(TAILSCALE_HOSTNAME):$(NGINX_OPENCLAW_PORT)"
	@echo "║  🤖  OpenClaw    https://openclaw.$(TEAM).orb.local  (OrbStack)"
	@echo "║  🔮  Ollama API  https://$(TAILSCALE_HOSTNAME):$(NGINX_OLLAMA_PORT)"
	@echo "║  🔄  n8n         https://$(TAILSCALE_HOSTNAME):$(NGINX_N8N_PORT)"
	@echo "║  🔐  SSH         ssh root@localhost -p 2222"
	@echo "║"
	@echo "║  Agents: $(AGENT_IDS)"
	@echo "║"
	@echo "╚══════════════════════════════════════════════════════════════╝"
	@echo ""
	@$(COMPOSE) ps

down: _ensure-env
	@echo "🛑 Stopping all services ..."
	$(COMPOSE) down

restart: down up

restart-openclaw: generate
	@echo "🔄 Rebuilding and restarting openclaw only ..."
	$(COMPOSE) up -d --build --no-deps openclaw
	@echo "✅ OpenClaw restarted"

rebuild-openclaw: down
	@echo "🔨 Rebuilding openclaw image ..."
	$(COMPOSE) build openclaw
	$(MAKE) up

# ==============================================================================
# Logs
# ==============================================================================
logs: _ensure-env
	$(COMPOSE) logs -f --tail=100

logs-openclaw: _ensure-env
	$(COMPOSE) logs -f --tail=100 openclaw

logs-gh-proxy: _ensure-env
	$(COMPOSE) logs -f --tail=100 $(addprefix gh-proxy-,$(AGENT_IDS))

logs-crawl4ai: _ensure-env
	$(COMPOSE) logs -f --tail=100 $(addprefix crawl4ai-,$(AGENT_IDS))

logs-browser-use: _ensure-env
	$(COMPOSE) logs -f --tail=100 $(addprefix browser-use-,$(AGENT_IDS))

# ==============================================================================
# SSH / Shell
# ==============================================================================
ssh:
	@echo "🔐 SSH into OpenClaw (password: openclaw.root_password in config.json)"
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@localhost -p 2222

shell:
	@echo "🐚 Exec bash into OpenClaw container ..."
	docker exec -it $(TEAM)-openclaw bash

# ==============================================================================
# Status / Validate / Clean
# ==============================================================================
status: _ensure-env
	@echo ""
	@echo "  Container Status — $(TEAM)"
	@echo "  ──────────────────────────────────────────────────"
	@$(COMPOSE) ps
	@echo ""

validate: _ensure-env
	@echo "🔍 Validating docker-compose.yml ..."
	$(COMPOSE) config --quiet && echo "✅ docker-compose.yml is valid"

clean: _ensure-env
	@echo "🧹 Removing containers, volumes, and custom images ..."
	$(COMPOSE) down -v --rmi local
	@echo "✅ Cleaned up"
