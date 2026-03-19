#!/bin/bash
set -e

KEY="/root/.ollama/id_ed25519"
KEY_PUB="/root/.ollama/id_ed25519.pub"

mkdir -p /root/.ollama

# ---- Generate keypair if not present ----
if [ ! -f "${KEY}" ]; then
    echo "[ollama] Generating ed25519 keypair ..."
    ssh-keygen -t ed25519 -f "${KEY}" -N "" -q
fi

# ---- Print public key for registration ----
echo ""
echo "================================================================"
echo " Ollama Cloud Auth — register this public key at:"
echo " https://ollama.com/settings/keys"
echo "----------------------------------------------------------------"
awk '{print $1, $2}' "${KEY_PUB}"
echo "================================================================"
echo ""

# ---- Start Ollama in background, pull models, then foreground ----
ollama serve &
OLLAMA_PID=$!

# Wait for server to be ready
until ollama list &>/dev/null; do sleep 1; done

# Pull models from OLLAMA_MODELS env var (comma-separated)
# Note: GOMAXPROCS=1 in docker-compose prevents digest mismatch on pull (ollama/ollama#14554)
set +e
IFS=',' read -ra _PULL_MODELS <<< "${OLLAMA_MODELS:-}"
for model in "${_PULL_MODELS[@]}"; do
    if ! ollama list | grep -q "^${model}"; then
        echo "[ollama] Pulling ${model} ..."
        if ollama pull "${model}"; then
            echo "[ollama] ✓ ${model} ready"
        else
            echo "[ollama] ⚠ Failed to pull ${model} — server will continue without it"
        fi
    else
        echo "[ollama] ✓ ${model} already present"
    fi
done
set -e

wait $OLLAMA_PID
