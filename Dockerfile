FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Dev essentials
RUN apt-get update && apt-get install -y \
    git curl wget ripgrep fd-find jq \
    python3 python3-pip python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Node.js (for MCP servers via npx)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# gh CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Playwright MCP: install server first, then matching Chromium
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright
RUN npm install -g @playwright/mcp@latest \
    && npx --prefix /usr/lib/node_modules/@playwright/mcp playwright install --with-deps chromium

# Non-root user matching host uid/gid for mount permissions
RUN userdel -r ubuntu 2>/dev/null; \
    groupadd -f -g 1000 dev && useradd -m -s /bin/bash -u 1000 -g 1000 dev
USER dev
ENV HOME=/home/dev

# Claude binary will be mounted at runtime at /home/dev/.local/bin/claude
ENV PATH="/home/dev/.local/bin:${PATH}"

WORKDIR /workspace
ENTRYPOINT ["claude", "--dangerously-skip-permissions"]
