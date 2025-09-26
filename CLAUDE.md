# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Ubuntu developer setup bundle containing a comprehensive bootstrap script (`dev-setup.sh`) for setting up a fresh Ubuntu development environment. The script automates the installation of essential development tools, programming languages, databases, browsers, and productivity applications.

## Key Components

- **dev-setup.sh**: Main setup script that installs and configures the entire development environment
- **INSTRUCTIONS.md**: User-facing documentation explaining what gets installed and how to use the bundle

## Running the Setup Script

To execute the main setup script:
```bash
chmod +x dev-setup.sh
./dev-setup.sh
```

The script requires sudo privileges and will:
1. Install system packages via APT
2. Set up Docker with user permissions
3. Install Ruby via RVM (default 3.2.2)
4. Install Node.js via nvm (latest LTS)
5. Install various development tools and applications

## Script Architecture

The setup script follows these patterns:
- Uses `set -euo pipefail` for strict error handling
- Detects the real user when run with sudo via `SUDO_USER`
- Implements idempotent installations (checks if tools already exist)
- Uses helper functions: `log()` for output, `need_cmd()` for command detection
- Modifies both `.bashrc` and `.zshrc` for shell compatibility

## Post-Installation Requirements

After running the script, users must log out and back in (or reboot) for:
- Docker group permissions to take effect
- nvm PATH configuration to be available

## Development Tools Installed

- **Languages**: Ruby (RVM), Node.js (nvm)
- **Databases**: DBeaver CE, MongoDB shell
- **Development**: VS Code, Docker, Git, build tools
- **Communication**: Slack, Zoom, Microsoft Teams
- **Browsers**: Chrome, Firefox
- **Utilities**: tmux, fzf, ripgrep, htop, jq, vim/neovim