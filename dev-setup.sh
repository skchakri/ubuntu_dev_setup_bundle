#!/usr/bin/env bash
# Ubuntu Dev Machine Bootstrap (Rails + JS + Docker + Extras)
# Works on Ubuntu 22.04 / 24.04
# Version: 1.0.0

set -euo pipefail
log() { echo -e "\n\033[1;32m[SETUP]\033[0m $*\n"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

# Detect current user
if [[ "${SUDO_USER-}" != "" ]]; then
  REAL_USER="$SUDO_USER"
else
  REAL_USER="$(id -un)"
fi
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"

log "Running as $REAL_USER (home: $REAL_HOME)"

export DEBIAN_FRONTEND=noninteractive

# ---------- APT base ----------
log "Updating APT and installing base packages…"
# Clean up any broken MongoDB repositories from previous runs
sudo rm -f /etc/apt/sources.list.d/mongodb-org-*.list 2>/dev/null || true
sudo apt-get update -y
sudo apt-get upgrade -y || true

sudo apt-get install -y   build-essential git curl wget ca-certificates gnupg software-properties-common   unzip zip jq   vim neovim gedit   zsh tmux   fzf ripgrep htop tree   terminator   llvm pkg-config   libssl-dev libreadline-dev zlib1g-dev libyaml-dev libffi-dev   libgdbm-dev libdb-dev libncurses5-dev libsqlite3-dev sqlite3   libxml2-dev libxslt1-dev autoconf bison   dnsutils net-tools   apt-transport-https lsb-release

# ---------- Docker (official repo) ----------
if ! need_cmd docker; then
  log "Installing Docker Engine…"
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable"     | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker "$REAL_USER" || true
else
  log "Docker already installed; ensuring user in docker group…"
  sudo usermod -aG docker "$REAL_USER" || true
fi

# ---------- RVM + Ruby ----------
if ! need_cmd rvm; then
  log "Installing RVM (Ruby Version Manager)…"
  sudo apt-get install -y dirmngr gnupg2
  curl -sSL https://rvm.io/mpapis.asc | gpg --import - || true
  curl -sSL https://rvm.io/pkuczynski.asc | gpg --import - || true
  # Temporarily disable unbound variable check for RVM installation
  set +u
  curl -sSL https://get.rvm.io | bash -s stable
  echo 'export PATH="$HOME/.rvm/bin:$PATH"' >> "$REAL_HOME/.bashrc"
  echo '[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"' >> "$REAL_HOME/.bashrc"
  echo '[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"' >> "$REAL_HOME/.zshrc" 2>/dev/null || true
  source "$REAL_HOME/.rvm/scripts/rvm"
  # Re-enable unbound variable check
  set -u
else
  # Temporarily disable unbound variable check for RVM sourcing
  set +u
  source "$REAL_HOME/.rvm/scripts/rvm"
  set -u
  log "RVM already present."
fi

DEFAULT_RUBY="3.2.2"
# Temporarily disable unbound variable check for RVM commands
set +u
if ! rvm list strings | grep -q "^$DEFAULT_RUBY$"; then
  log "Installing Ruby $DEFAULT_RUBY via RVM…"
  rvm install "$DEFAULT_RUBY"
  rvm --default use "$DEFAULT_RUBY"
else
  log "Ruby $DEFAULT_RUBY already installed. Setting as default…"
  rvm --default use "$DEFAULT_RUBY"
fi

log "Installing baseline global gems…"
gem update --system
gem install bundler rails -N
# Re-enable unbound variable check
set -u

# ---------- Node.js (nvm) ----------
if [[ ! -d "$REAL_HOME/.nvm" ]]; then
  log "Installing nvm…"
  sudo -u "$REAL_USER" bash -lc 'curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash'
  {
    echo 'export NVM_DIR="$HOME/.nvm"'
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'
  } >> "$REAL_HOME/.bashrc"
  {
    echo 'export NVM_DIR="$HOME/.nvm"'
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
  } >> "$REAL_HOME/.zshrc" 2>/dev/null || true
fi

# shellcheck disable=SC1090
source "$REAL_HOME/.nvm/nvm.sh" 2>/dev/null || true
if need_cmd nvm; then
  sudo -u "$REAL_USER" bash -lc 'source "$HOME/.nvm/nvm.sh" && nvm install --lts && nvm alias default "lts/*" && corepack enable || true'
else
  log "nvm will be available next shell session."
fi

# ---------- DBeaver CE ----------
if ! need_cmd dbeaver; then
  log "Installing DBeaver CE…"
  # Download and install DBeaver CE directly from GitHub releases
  DBEAVER_VERSION=$(curl -s "https://api.github.com/repos/dbeaver/dbeaver/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null || echo "")
  if [[ -n "${DBEAVER_VERSION:-}" ]]; then
    wget -q "https://github.com/dbeaver/dbeaver/releases/latest/download/dbeaver-ce_${DBEAVER_VERSION}_amd64.deb" -O /tmp/dbeaver.deb 2>/dev/null
    if [[ -f /tmp/dbeaver.deb ]]; then
      sudo apt-get install -y /tmp/dbeaver.deb || sudo apt-get -f install -y && sudo apt-get install -y /tmp/dbeaver.deb || true
      rm -f /tmp/dbeaver.deb
      log "✅ DBeaver CE installed successfully"
    else
      log "⚠️ DBeaver download failed, skipping..."
    fi
  else
    log "⚠️ Could not get DBeaver version, skipping..."
  fi
fi

# ---------- MongoDB shell client ----------
if ! need_cmd mongosh; then
  log "Installing MongoDB shell client…"
  # Download and install mongosh directly from MongoDB downloads (works on all Ubuntu versions)
  MONGOSH_VERSION=$(curl -s "https://api.github.com/repos/mongodb-js/mongosh/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null || echo "")
  if [[ -n "${MONGOSH_VERSION:-}" ]]; then
    # Remove 'v' prefix if present
    MONGOSH_VERSION_CLEAN="${MONGOSH_VERSION#v}"
    wget -q "https://downloads.mongodb.com/compass/mongosh-${MONGOSH_VERSION_CLEAN}-linux-x64.tgz" -O /tmp/mongosh.tgz 2>/dev/null
    if [[ -f /tmp/mongosh.tgz ]]; then
      tar -zxf /tmp/mongosh.tgz -C /tmp/ 2>/dev/null
      sudo cp /tmp/mongosh-${MONGOSH_VERSION_CLEAN}-linux-x64/bin/* /usr/local/bin/ 2>/dev/null || true
      rm -rf /tmp/mongosh.tgz /tmp/mongosh-${MONGOSH_VERSION_CLEAN}-linux-x64
      log "✅ MongoDB shell (mongosh) installed successfully"
    else
      log "⚠️ MongoDB shell download failed, skipping..."
    fi
  else
    log "⚠️ Could not get mongosh version, skipping..."
  fi
fi

# ---------- Google Chrome ----------
if ! need_cmd google-chrome; then
  log "Installing Google Chrome…"
  wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
  sudo apt-get install -y /tmp/chrome.deb || sudo apt-get -f install -y && sudo apt-get install -y /tmp/chrome.deb || true
  rm -f /tmp/chrome.deb
fi

# ---------- Zoom ----------
if ! need_cmd zoom; then
  log "Installing Zoom…"
  wget -q https://zoom.us/client/latest/zoom_amd64.deb -O /tmp/zoom.deb
  sudo apt-get install -y /tmp/zoom.deb || sudo apt-get -f install -y && sudo apt-get install -y /tmp/zoom.deb || true
  rm -f /tmp/zoom.deb
fi

# ---------- Microsoft Teams ----------
if ! need_cmd teams; then
  log "Installing Microsoft Teams…"
  if wget -q --timeout=30 https://go.microsoft.com/fwlink/p/?LinkID=2112886 -O /tmp/teams.deb 2>/dev/null && [[ -f /tmp/teams.deb ]]; then
    sudo apt-get install -y /tmp/teams.deb || sudo apt-get -f install -y && sudo apt-get install -y /tmp/teams.deb || true
    rm -f /tmp/teams.deb
    log "✅ Microsoft Teams installed successfully"
  else
    log "⚠️ Microsoft Teams download failed or timed out, skipping..."
    rm -f /tmp/teams.deb
  fi
fi

# ---------- Firefox ----------
if ! need_cmd firefox; then
  log "Installing Firefox…"
  sudo apt-get install -y firefox
fi

# ---------- Sway Wayland Compositor (Hyprland alternative) ----------
if ! need_cmd sway; then
  log "Installing Sway Wayland compositor + supporting tools…"
  sudo apt-get install -y   sway waybar wofi   swaylock swayidle   foot alacritty   grim slurp wl-clipboard   light playerctl   brightnessctl pulseaudio-utils
fi

# ---------- Omarchy-inspired terminal tools ----------
log "Installing enhanced terminal tools (zoxide, starship, lazygit)…"

# Zoxide (smart cd replacement)
if ! need_cmd zoxide; then
  curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
  echo 'eval "$(zoxide init bash)"' >> "$REAL_HOME/.bashrc"
  echo 'eval "$(zoxide init zsh)"' >> "$REAL_HOME/.zshrc" 2>/dev/null || true
fi

# Starship prompt
if ! need_cmd starship; then
  curl -sS https://starship.rs/install.sh | sh -s -- -y
  echo 'eval "$(starship init bash)"' >> "$REAL_HOME/.bashrc"
  echo 'eval "$(starship init zsh)"' >> "$REAL_HOME/.zshrc" 2>/dev/null || true
fi

# LazyGit
if ! need_cmd lazygit; then
  log "Installing LazyGit (terminal git UI)…"
  LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null || echo "")
  if [[ -n "${LAZYGIT_VERSION:-}" ]]; then
    # Remove 'v' prefix if present
    LAZYGIT_VERSION_CLEAN="${LAZYGIT_VERSION#v}"
    if curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION_CLEAN}_Linux_x86_64.tar.gz" 2>/dev/null; then
      if tar xf lazygit.tar.gz lazygit 2>/dev/null && sudo install lazygit /usr/local/bin 2>/dev/null; then
        rm -f lazygit lazygit.tar.gz
        log "✅ LazyGit installed successfully"
      else
        log "⚠️ LazyGit extraction/installation failed, skipping..."
        rm -f lazygit lazygit.tar.gz
      fi
    else
      log "⚠️ LazyGit download failed, skipping..."
    fi
  else
    log "⚠️ Could not get LazyGit version, skipping..."
  fi
fi

# LazyDocker - Handle Docker permission timing
if ! need_cmd lazydocker; then
  log "Installing LazyDocker (terminal docker UI)…"
  # Check if Docker is installed and running
  if need_cmd docker; then
    # Try to install LazyDocker
    if curl -s https://raw.githubusercontent.com/jesseduffield/lazydocker/main/scripts/install_update_linux.sh | bash >/dev/null 2>&1; then
      log "✅ LazyDocker installed successfully"
      log "📋 Note: LazyDocker requires Docker group membership - effective after logout/login"
    else
      log "⚠️ LazyDocker installation failed - will be available after Docker setup completes"
    fi
  else
    log "⚠️ Docker not found - LazyDocker will be available after logout/login"
  fi
fi

# Eza (modern ls replacement)
if ! need_cmd eza; then
  log "Installing Eza (modern ls replacement)…"
  if sudo apt-get install -y eza 2>/dev/null; then
    log "✅ Eza installed via apt"
  else
    log "Installing Eza from GitHub releases…"
    if wget -c https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz -O - 2>/dev/null | tar xz 2>/dev/null; then
      sudo chmod +x eza && sudo mv eza /usr/local/bin/ 2>/dev/null
      log "✅ Eza installed from GitHub"
    else
      log "⚠️ Eza installation failed, ls will work as usual"
    fi
  fi
fi

# ---------- Programming fonts ----------
log "Installing programming fonts…"
sudo apt-get install -y fonts-jetbrains-mono fonts-firacode fonts-cascadia-code || true

# ---------- Snap apps ----------
if need_cmd snap; then
  log "Installing Snap apps (VS Code, Slack, Notepad++, Android Studio)…"
  sudo snap install code --classic || true
  sudo snap install slack --classic || true
  sudo snap install notepad-plus-plus || true
  sudo snap install android-studio --classic || true

  # Install Claude Code extension for VS Code
  if need_cmd code; then
    log "Installing Claude Code extension for VS Code…"
    sudo -u "$REAL_USER" code --install-extension anthropic.claude-code 2>/dev/null || true
  fi
fi

# ---------- Clone iCentris repositories ----------
PLATFORM_DIR="$REAL_HOME/platform"
if [[ ! -d "$PLATFORM_DIR" ]]; then
  log "Creating platform directory…"
  sudo -u "$REAL_USER" mkdir -p "$PLATFORM_DIR"
fi

log "Cloning iCentris repositories to ~/platform…"
REPOS=("pyr" "etl" "vibe-stream" "partyorder" "vibe-ingress" "icentris-cms" "icentris-rules" "zevents")
for repo in "${REPOS[@]}"; do
  if [[ ! -d "$PLATFORM_DIR/$repo" ]]; then
    log "Cloning $repo…"
    sudo -u "$REAL_USER" git clone "https://github.com/iCentris/$repo.git" "$PLATFORM_DIR/$repo" 2>/dev/null || log "⚠️ Failed to clone $repo (may be private or not found)"
  else
    log "✅ $repo already exists, skipping…"
  fi
done

# ---------- Shell default (optional) ----------
if need_cmd zsh; then
  if [[ "$SHELL" != *"zsh"* ]]; then
    log "Setting zsh as default shell (optional)…"
    chsh -s "$(command -v zsh)" "$REAL_USER" || true
  fi
fi

log "✅ Setup complete. Installed:\n- Core tools, Docker\n- Ruby ${DEFAULT_RUBY} (RVM) + Rails\n- Node LTS (nvm) + Corepack\n- DBeaver CE, MongoDB shell\n- Chrome, Firefox, Zoom, Teams\n- VS Code with Claude Code extension, Slack, Notepad++, Android Studio\n- Sway Wayland compositor + Waybar + Wofi\n- Enhanced terminal: Zoxide, Starship, LazyGit, LazyDocker, Eza\n- Terminal apps: Terminator, gedit\n- Programming fonts: JetBrains Mono, Fira Code, Cascadia Code\n- iCentris repositories cloned to ~/platform\n\n🔄 IMPORTANT: Log out and back in for:\n   • Docker group permissions (required for LazyDocker)\n   • nvm PATH configuration\n   • Shell enhancements (zoxide, starship)\n\n🪟 To use Sway: Select 'Sway' from login screen session options.\n\n⚠️ If any downloads failed, re-run the script after reboot."
