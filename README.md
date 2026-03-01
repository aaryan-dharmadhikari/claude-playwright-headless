# claude-playwright-headless

Run [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with `--dangerously-skip-permissions` inside a Docker container with headless [Playwright](https://github.com/microsoft/playwright-mcp) browser automation.

Claude gets full access to your project directory and a headless Chromium browser, but nothing else on your host.

## What's in the box

| Tool | Purpose |
|------|---------|
| Python 3, pip, uv, venv | Python development |
| Node.js 22, npm | JS/TS development, MCP servers |
| git, gh | Version control, GitHub operations |
| ripgrep, fd, jq, curl | Search and scripting |
| **Playwright MCP + Chromium** | **Headless browser automation** |

## Quick start

### Prerequisites

- Docker
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated

### Install

```bash
git clone https://github.com/aaryan-dharmadhikari/claude-playwright-headless.git
cd claude-playwright-headless

# Build the image (~1.2GB)
docker build -t claude-playwright-headless .

# Add the wrapper to your PATH
chmod +x claude-playwright-headless
ln -sf "$(pwd)/claude-playwright-headless" ~/.local/bin/claude-playwright-headless
```

### Usage

```bash
# Interactive session
claude-playwright-headless ~/my-project

# Headless one-shot
claude-playwright-headless ~/my-project -p "refactor the auth module" --output-format text

# Browse the web
claude-playwright-headless ~/my-project -p "go to https://example.com and summarise the page" --output-format text

# Pass any Claude CLI flags
claude-playwright-headless ~/my-project --model sonnet
```

First argument is the project directory (defaults to `.`). Everything after is forwarded to `claude`.

## How it works

```
┌─────────────────────────────────────────────┐
│  Docker container                           │
│                                             │
│  /workspace (your project)  ← read-write    │
│  Claude Code CLI            ← read-only     │
│  ~/.claude/ (auth/state)    ← read-write    │
│  ~/CLAUDE.md                ← read-only     │
│  Playwright MCP + Chromium                  │
│                                             │
│  Everything else: inaccessible              │
└─────────────────────────────────────────────┘
```

### Restricted

- **Filesystem**: Claude cannot read, write, or delete anything outside the mounted project directory. Your home directory, other projects, system files, SSH keys, dotfiles, etc. are all inaccessible.
- **Processes**: Claude cannot see or interact with host processes. It can only run processes inside the container.
- **Destructive commands**: `rm -rf /` or similar only affects the ephemeral container — the host is untouched.
- **Permission prompts**: There are none (`--dangerously-skip-permissions`), but the blast radius is limited to the project directory.

### Not restricted

- **Project directory**: Claude has full read-write access to everything in the mounted project. It can create, edit, and delete any file there.
- **Network**: Unrestricted. Claude can make HTTP requests, install packages (pip, npm), call APIs, browse the web via Playwright, and access any external service.
- **Claude state**: `~/.claude/` and `~/.claude.json` are mounted read-write so auth and session state persist between runs.
- **Git operations**: Claude can commit, push, and pull within the project. However, `gh` CLI is not pre-authenticated inside the container (see Gotchas).

## Playwright MCP

The [Playwright MCP server](https://github.com/microsoft/playwright-mcp) is pre-installed and configured automatically. Claude can:

- Navigate to URLs and extract content via accessibility snapshots
- Click, type, fill forms, upload files
- Take screenshots
- Inspect network requests and console output

The MCP config lives in `mcp.json`. To add more MCP servers, edit it and rebuild.

## Customisation

### Adding tools

Edit the `Dockerfile`:

```dockerfile
RUN apt-get update && apt-get install -y your-package && rm -rf /var/lib/apt/lists/*
```

Then rebuild: `docker build -t claude-playwright-headless .`

### Different UID/GID

Default is 1000:1000. If your host user differs:

```dockerfile
RUN userdel -r ubuntu 2>/dev/null; \
    groupadd -f -g YOUR_GID dev && useradd -m -s /bin/bash -u YOUR_UID -g YOUR_GID dev
```

### Adding MCP servers

Edit `mcp.json`:

```json
{
  "mcpServers": {
    "playwright": { "..." : "..." },
    "my-server": {
      "command": "npx",
      "args": ["-y", "my-mcp-server@latest"]
    }
  }
}
```

## Gotchas

- **gh CLI auth**: Mounting `~/.config/gh` read-only causes Claude Code to hang. If you need gh inside the container, run `gh auth login` interactively.
- **Shared memory**: Chrome needs >64MB `/dev/shm`. The wrapper passes `--shm-size=1g` automatically.
- **Playwright version pinning**: Chromium must match the `@playwright/mcp` version. The Dockerfile installs browsers *after* the MCP package to ensure this. Rebuild the image when updating.
- **CLAUDE.md**: The wrapper mounts `~/CLAUDE.md` read-only if it exists. This lets Claude pick up your global instructions inside the sandbox.

## License

MIT
