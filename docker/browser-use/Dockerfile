# ============================================================
# browser-use – AI-driven browser agent (LLM decides actions)
# Follows official browser-use Dockerfile pattern:
# https://github.com/browser-use/browser-use/blob/main/Dockerfile
# ============================================================
FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    ca-certificates \
    fonts-liberation \
    fonts-noto-core \
    && rm -rf /var/lib/apt/lists/* \
    && update-ca-certificates

RUN pip install --no-cache-dir browser-use fastapi uvicorn playwright

RUN python -m playwright install chromium --with-deps

COPY server.py /app/server.py

ENV IN_DOCKER=True

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -sf http://localhost:8080/health || exit 1

CMD ["python", "/app/server.py"]
