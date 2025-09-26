#!/usr/bin/env bash
# Ubuntu Dev Machine Bootstrap (Rails + JS + Docker + Extras)
# Works on Ubuntu 22.04 / 24.04

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
sudo apt-get update -y
sudo apt-get upgrade -y || true

sudo apt-get install -y   build-essential git curl wget ca-certificates gnupg software-properties-common   unzip zip jq   vim neovim   zsh tmux   fzf ripgrep htop tree   llvm pkg-config   libssl-dev libreadline-dev zlib1g-dev libyaml-dev libffi-dev   libgdbm-dev libdb-dev libncurses5-dev libsqlite3-dev sqlite3   libxml2-dev libxslt1-dev autoconf bison   dnsutils net-tools   apt-transport-https lsb-release

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
  curl -sSL https://get.rvm.io | bash -s stable
  echo 'export PATH="$HOME/.rvm/bin:$PATH"' >> "$REAL_HOME/.bashrc"
  echo '[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"' >> "$REAL_HOME/.bashrc"
  echo '[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"' >> "$REAL_HOME/.zshrc" 2>/dev/null || true
  source "$REAL_HOME/.rvm/scripts/rvm"
else
  source "$REAL_HOME/.rvm/scripts/rvm"
  log "RVM already present."
fi

DEFAULT_RUBY="3.2.2"
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
  sudo add-apt-repository -y ppa:dbeaver-team/dbeaver-ce
  sudo apt-get update -y
  sudo apt-get install -y dbeaver-ce
fi

# ---------- MongoDB shell client ----------
if ! need_cmd mongosh; then
  log "Installing MongoDB shell client…"
  curl -fsSL https://pgp.mongodb.com/server-7.0.asc | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server.gpg
  echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server.gpg ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/7.0 multiverse"     | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
  sudo apt-get update -y
  sudo apt-get install -y mongodb-mongosh
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
  wget -q https://go.microsoft.com/fwlink/p/?LinkID=2112886 -O /tmp/teams.deb
  sudo apt-get install -y /tmp/teams.deb || sudo apt-get -f install -y && sudo apt-get install -y /tmp/teams.deb || true
  rm -f /tmp/teams.deb
fi

# ---------- Firefox ----------
if ! need_cmd firefox; then
  log "Installing Firefox…"
  sudo apt-get install -y firefox
fi

# ---------- Snap apps ----------
if need_cmd snap; then
  log "Installing Snap apps (VS Code, Slack, Notepad++, Android Studio)…"
  sudo snap install code --classic || true
  sudo snap install slack --classic || true
  sudo snap install notepad-plus-plus || true
  sudo snap install android-studio --classic || true
fi

# ---------- Shell default (optional) ----------
if need_cmd zsh; then
  if [[ "$SHELL" != *"zsh"* ]]; then
    log "Setting zsh as default shell (optional)…"
    chsh -s "$(command -v zsh)" "$REAL_USER" || true
  fi
fi

log "✅ Setup complete. Installed:\n- Core tools, Docker\n- Ruby ${DEFAULT_RUBY} (RVM) + Rails\n- Node LTS (nvm) + Corepack\n- DBeaver CE, MongoDB shell\n- Chrome, Firefox, Zoom, Teams\n- VS Code, Slack, Notepad++, Android Studio\n\nNOTE: Log out/in for docker group and nvm PATH to apply."
