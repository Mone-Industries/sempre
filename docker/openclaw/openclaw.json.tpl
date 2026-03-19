{
    "models": {
        "providers": {
            "ollama": {
                "baseUrl": "http://ollama:11434/v1",
                "apiKey": "ollama",
                "api": "openai-completions",
                "models": []
            }
        }
    },
    "agents": {
        "defaults": {
            "model": "ollama/${OLLAMA_MODEL}",
            "workspace": "/root/.openclaw/workspace",
            "userTimezone": "${USER_TIMEZONE}",
            "timeoutSeconds": 600,
            "compaction": {
                "mode": "safeguard"
            },
            "memorySearch": {
                "enabled": true,
                "provider": "ollama",
                "model": "nomic-embed-text",
                "remote": {
                    "baseUrl": "http://ollama:11434"
                },
                "sources": ["memory", "sessions"],
                "extraPaths": ["/root/.km"],
                "experimental": {
                    "sessionMemory": true
                },
                "sync": {
                    "watch": true,
                    "onSessionStart": true,
                    "onSearch": true
                }
            }
        },
        "list": []
    },
    "tools": {
        "agentToAgent": {
            "enabled": true,
            "allow": []
        }
    },
    "bindings": [],
    "commands": {
        "native": "auto",
        "nativeSkills": "auto",
        "restart": true
    },
    "hooks": {
        "internal": {
            "enabled": true,
            "entries": {
                "boot-md": { "enabled": true },
                "bootstrap-extra-files": { "enabled": true },
                "command-logger": { "enabled": true },
                "session-memory": { "enabled": true }
            }
        }
    },
    "channels": {
        "discord": {
            "enabled": true,
            "groupPolicy": "allowlist",
            "streaming": "off",
            "accounts": {
                "default": {
                    "groupPolicy": "allowlist",
                    "streaming": "off"
                }
            }
        }
    },
    "gateway": {
        "port": 18789,
        "mode": "local",
        "bind": "lan",
        "trustedProxies": ["172.16.0.0/12", "192.168.0.0/16", "10.0.0.0/8"],
        "controlUi": {
            "allowInsecureAuth": true,
            "allowedOrigins": [
                "http://localhost:18789",
                "${GATEWAY_ORIGIN}"${GATEWAY_ORIGINS_EXTRA_JSON}
            ]
        },
        "auth": {
            "mode": "token",
            "token": "${OPENCLAW_GATEWAY_TOKEN}"
        }
    }
}
