# Ubuntu Developer Setup Bundle

🚀 **One-click setup script for a complete Ubuntu development environment**

This repository contains a comprehensive setup script that transforms a fresh Ubuntu installation into a fully-configured development machine with all essential tools, programming languages, and applications.

## ⚡ Quick Start

```bash
git clone https://github.com/skchakri/ubuntu_dev_setup_bundle.git
cd ubuntu_dev_setup_bundle
chmod +x dev-setup.sh
./dev-setup.sh
```

**Important:** Log out and back in (or reboot) after installation for all changes to take effect.

## 🛠️ What Gets Installed

### Core Development Tools
- **Build essentials**: gcc, make, git, curl, wget
- **Shell tools**: zsh, tmux, fzf, ripgrep, htop, jq
- **Editors**: vim, neovim

### Programming Languages & Package Managers
- **Ruby 3.2.2** via RVM + bundler + rails
- **Node.js LTS** via nvm + Corepack (yarn/pnpm support)

### Containerization & Databases
- **Docker Engine** + Docker Compose plugin
- **DBeaver CE** (database GUI)
- **MongoDB shell** (mongosh)

### Wayland Compositor & Window Management
- **Sway** - Tiling Wayland compositor (Hyprland alternative)
- **Waybar** - Customizable status bar
- **Wofi** - Application launcher
- **Supporting tools**: swaylock, swayidle, grim, slurp

### Enhanced Terminal Experience
- **Zoxide** - Smart directory jumper (better cd)
- **Starship** - Beautiful, customizable prompt
- **LazyGit** - Terminal UI for git operations
- **LazyDocker** - Terminal UI for Docker management
- **Eza** - Modern ls replacement with colors

### Applications & Browsers
- **Browsers**: Google Chrome, Firefox
- **Communication**: Zoom, Microsoft Teams, Slack
- **Development**: VS Code, Android Studio
- **Terminals**: foot, alacritty
- **Utilities**: Notepad++

### Programming Fonts
- **JetBrains Mono** - Popular coding font
- **Fira Code** - Font with programming ligatures
- **Cascadia Code** - Microsoft's developer font

## 🎯 Supported Ubuntu Versions

- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS

## 📋 Post-Installation

### Essential Next Steps
1. **Restart your session** - Log out and back in for Docker group permissions and nvm PATH
2. **Configure your shell** - The script sets zsh as default (optional)
3. **Install Chrome extensions** - See quick-install links in [INSTRUCTIONS.md](INSTRUCTIONS.md)

### Verify Installation
```bash
# Check Docker
docker --version
docker-compose --version

# Check Ruby
ruby --version
rails --version

# Check Node.js
node --version
npm --version

# Check enhanced terminal tools
zoxide --version
starship --version
lazygit --version
eza --version

# Check Sway (if using Wayland session)
sway --version
```

## 🔧 Customization

The script is designed to be:
- **Idempotent** - Safe to run multiple times
- **Non-destructive** - Won't overwrite existing installations
- **User-aware** - Handles sudo execution properly

Want rbenv instead of RVM? Need different Ruby/Node versions? The script can be easily modified for your needs.

## 📁 Repository Structure

```
├── dev-setup.sh     # Main installation script
├── INSTRUCTIONS.md  # Detailed usage instructions
├── CLAUDE.md        # Development guidance
└── README.md        # This file
```

## 🐛 Troubleshooting

**Docker permission issues?**
```bash
sudo usermod -aG docker $USER
# Then log out and back in
```

**nvm not found?**
```bash
source ~/.bashrc
# or start a new terminal session
```

**Snap apps not installing?**
- Some Ubuntu flavors disable snap by default
- Install .deb versions instead or enable snap first

**Sway not working?**
- Ensure you're using a Wayland session (not X11)
- Some graphics drivers may have compatibility issues
- Use `WAYLAND_DISPLAY=wayland-1 sway` to test

**Terminal tools not found after installation?**
- Run `source ~/.bashrc` or start a new terminal session
- Check that the tools are in your PATH with `echo $PATH`

## 🤝 Contributing

Feel free to submit issues and enhancement requests! This script is designed to be a solid foundation that can be customized for different development needs.

## 📄 License

This project is open source and available under standard terms for educational and development use.