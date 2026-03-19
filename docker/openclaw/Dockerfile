# ============================================================
# OpenClaw Gateway – Ubuntu 24.04 + Node 22 + SSH
# ============================================================
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

# ---- Base packages + SSH server ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    curl \
    git \
    build-essential \
    python3 \
    ca-certificates \
    jq \
    gettext-base \
    zsh \
    bat \
    fzf \
    zoxide \
    eza \
    zsh-syntax-highlighting \
    zsh-autosuggestions \
    wget \
    sudo \
    dnsutils \
    && mkdir -p /var/run/sshd \
    && rm -rf /var/lib/apt/lists/*

# ---- Docker CLI (for docker exec into github-mcp containers) ----
RUN apt-get update && apt-get install -y --no-install-recommends gnupg \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] \
       https://download.docker.com/linux/ubuntu noble stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# ---- Setup Zsh & Starship ----
# Download starship binary directly (avoids install script GitHub rate-limit issues on ARM)
RUN ARCH=$(uname -m) \
    && case "$ARCH" in \
         aarch64) SA=aarch64-unknown-linux-musl ;; \
         x86_64)  SA=x86_64-unknown-linux-musl ;; \
         *) echo "Unsupported arch: $ARCH" && exit 1 ;; \
       esac \
    && for i in 1 2 3; do \
         curl -fL "https://github.com/starship/starship/releases/latest/download/starship-${SA}.tar.gz" \
           -o /tmp/starship.tar.gz && break || sleep 10; \
       done \
    && tar -xzf /tmp/starship.tar.gz -C /usr/local/bin \
    && rm /tmp/starship.tar.gz \
    && chsh -s /usr/bin/zsh root \
    && mkdir -p /root/.config \
    && starship preset nerd-font-symbols -o /root/.config/starship.toml \
    && echo 'eval "$(starship init zsh)"' >> /root/.zshrc \
    && echo 'eval "$(zoxide init zsh)"' >> /root/.zshrc \
    && echo 'source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh' >> /root/.zshrc \
    && echo 'source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' >> /root/.zshrc \
    && echo 'alias cat="batcat"' >> /root/.zshrc \
    && echo 'alias ls="eza --icons=always"' >> /root/.zshrc \
    && echo 'alias ll="eza -alF --icons=always"' >> /root/.zshrc \
    && echo 'alias la="eza -a --icons=always"' >> /root/.zshrc \
    && echo 'alias l="eza -F --icons=always"' >> /root/.zshrc

# ---- Node.js 22 (LTS) ----
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# ---- pnpm ----
RUN npm install -g pnpm

# ---- Google Workspace CLI ----
RUN npm install -g @googleworkspace/cli \
    && mkdir -p /root/.gws

# ---- Clone & build OpenClaw ----
ARG OPENCLAW_VERSION=v2026.3.8
RUN git clone --depth 1 --branch ${OPENCLAW_VERSION} \
        https://github.com/openclaw/openclaw.git /opt/openclaw \
    && cd /opt/openclaw \
    && pnpm install --frozen-lockfile \
    && pnpm build

# ---- openclaw global CLI ----
RUN echo '#!/bin/sh\nexec node /opt/openclaw/dist/index.js "$@"' > /usr/local/bin/openclaw \
    && chmod +x /usr/local/bin/openclaw

# ---- SSH config ----
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# ---- Create data dirs + team.json mount point ----
RUN mkdir -p /root/.openclaw /root/.km /root/workspace/skills /opt/sempre

# ---- Copy default configs & workspace seed files ----
# All stored in /opt/openclaw-default — entrypoint copies on first run only
RUN mkdir -p /opt/openclaw-default
COPY openclaw.json.tpl  /opt/openclaw-default/openclaw.json.tpl
COPY TOOLS.md.tpl       /opt/openclaw-default/TOOLS.md.tpl
COPY SKILL.md.tpl       /opt/openclaw-default/SKILL.md.tpl
COPY KM.md.tpl          /opt/openclaw-default/KM.md.tpl
COPY WORKFLOW.md.tpl      /opt/openclaw-default/WORKFLOW.md.tpl
COPY COMMUNICATION.md.tpl /opt/openclaw-default/COMMUNICATION.md.tpl
COPY SOUL.md.tpl          /opt/openclaw-default/SOUL.md.tpl
COPY IDENTITY.md.tpl    /opt/openclaw-default/IDENTITY.md.tpl
COPY USER.md            /opt/openclaw-default/USER.md
COPY HEARTBEAT.md       /opt/openclaw-default/HEARTBEAT.md

# ---- Expose ports ----
# 22   = SSH
# 18789 = OpenClaw gateway UI
# 18790 = OpenClaw bridge
EXPOSE 22 18789 18790

# ---- Entrypoint ----
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]

