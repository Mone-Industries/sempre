#!/bin/sh
set -e

# Substitute only our template vars — leaves nginx $variables ($host, $remote_addr, etc.) intact
envsubst '${TAILSCALE_HOSTNAME} ${NGINX_OPENCLAW_PORT} ${NGINX_OLLAMA_PORT} ${NGINX_N8N_PORT}' \
    < /etc/nginx/nginx.conf.tpl \
    > /etc/nginx/nginx.conf

echo "[nginx] SSL proxy ready (HTTP rejected — SSL only):"
echo "  TAILSCALE_HOSTNAME = ${TAILSCALE_HOSTNAME}"
echo "  OpenClaw  → https://${TAILSCALE_HOSTNAME}:${NGINX_OPENCLAW_PORT}  → http://openclaw-gateway:18789"
echo "  Ollama    → https://${TAILSCALE_HOSTNAME}:${NGINX_OLLAMA_PORT} → http://ollama:11434"
echo "  n8n       → https://${TAILSCALE_HOSTNAME}:${NGINX_N8N_PORT}   → http://n8n:5678"

exec nginx -g "daemon off;"
