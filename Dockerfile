# CortexOS Server — Docker Image
# AI-Powered Server Management on Ubuntu 24.04
#
# Build:  docker build -t cortexos-server .
# Run:    docker run -d -p 18789:18789 -e ANTHROPIC_API_KEY=sk-ant-... cortexos-server
#
# NOTE: Ollama is NOT included (too large). Use the docker-compose.yml
# with the "local-ai" profile to run Ollama as a sidecar container.

FROM ubuntu:24.04

LABEL maintainer="Ivan Honer <ivanuser>"
LABEL description="CortexOS Server — AI-Powered Server Management"
LABEL version="0.1.0"

# Prevent interactive prompts during install
ENV DEBIAN_FRONTEND=noninteractive
ENV NVM_DIR=/root/.nvm
ENV NODE_VERSION=22
ENV PATH="/root/.nvm/versions/node/v${NODE_VERSION}/bin:${PATH}"

# ─── System dependencies ────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    sudo \
    nginx-light \
    jq \
    procps \
    net-tools \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# ─── Node.js via nvm ────────────────────────────────────────
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install ${NODE_VERSION} \
    && nvm alias default ${NODE_VERSION} \
    && nvm use default

# Make node/npm available without sourcing nvm
RUN ln -sf $(find /root/.nvm/versions/node -name "node" -type f | head -1) /usr/local/bin/node \
    && ln -sf $(find /root/.nvm/versions/node -name "npm" -type f | head -1) /usr/local/bin/npm \
    && ln -sf $(find /root/.nvm/versions/node -name "npx" -type f | head -1) /usr/local/bin/npx

# ─── OpenClaw ────────────────────────────────────────────────
RUN . "$NVM_DIR/nvm.sh" && npm install -g openclaw

# ─── Skills ──────────────────────────────────────────────────
COPY skills/ /var/lib/cortexos/skills/

# ─── Dashboard ───────────────────────────────────────────────
COPY dashboard/ /var/lib/cortexos/dashboard/

# ─── Configuration ───────────────────────────────────────────
RUN mkdir -p /root/.openclaw /var/log/cortex-server /etc/cortexos

# Default openclaw config — will be overridden by volume mount if present
RUN echo '{\
  "version": 1,\
  "gateway": {\
    "bind": "0.0.0.0",\
    "port": 18789\
  },\
  "skills": {\
    "directories": ["/var/lib/cortexos/skills"]\
  }\
}' > /root/.openclaw/openclaw.json

# ─── Entrypoint script ──────────────────────────────────────
COPY <<'ENTRYPOINT' /usr/local/bin/cortexos-entrypoint.sh
#!/bin/bash
set -e

# Source nvm
export NVM_DIR="/root/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# If GATEWAY_TOKEN is set to "auto" or empty, let openclaw handle it
if [ -n "$GATEWAY_TOKEN" ] && [ "$GATEWAY_TOKEN" != "auto" ]; then
    jq --arg token "$GATEWAY_TOKEN" '.gateway.token = $token' \
        /root/.openclaw/openclaw.json > /tmp/oc.json \
        && mv /tmp/oc.json /root/.openclaw/openclaw.json
fi

echo "╔══════════════════════════════════════════════╗"
echo "║         CortexOS Server v0.1.0               ║"
echo "║   AI-Powered Server Management                ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "Gateway binding to 0.0.0.0:18789"
echo ""

exec openclaw gateway run --bind lan
ENTRYPOINT
RUN chmod +x /usr/local/bin/cortexos-entrypoint.sh

# ─── Environment ─────────────────────────────────────────────
# Set via docker run -e or docker-compose environment
ENV ANTHROPIC_API_KEY=""
ENV OPENAI_API_KEY=""
ENV GATEWAY_TOKEN="auto"

# ─── Expose & Volume ────────────────────────────────────────
EXPOSE 18789
VOLUME ["/root/.openclaw"]

# ─── Health check ────────────────────────────────────────────
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -sf http://localhost:18789/health || exit 1

CMD ["/usr/local/bin/cortexos-entrypoint.sh"]
