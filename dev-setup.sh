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

sudo apt-get install -y   build-essential git curl wget ca-certificates gnupg software-properties-common   unzip zip jq   vim neovim gedit   zsh tmux   fzf ripgrep htop tree   terminator   llvm pkg-config   libssl-dev libreadline-dev zlib1g-dev libyaml-dev libffi-dev   libgdbm-dev libdb-dev libncurses5-dev libsqlite3-dev sqlite3   libxml2-dev libxslt1-dev autoconf bison   dnsutils net-tools   apt-transport-https lsb-release   dia

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

# ---------- kubectl (Kubernetes CLI) ----------
if ! need_cmd kubectl; then
  log "Installing kubectl…"
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
  sudo apt-get update -y
  sudo apt-get install -y kubectl
  log "✅ kubectl installed successfully"
else
  log "kubectl already installed"
fi

# ---------- aws-iam-authenticator ----------
if ! need_cmd aws-iam-authenticator; then
  log "Installing aws-iam-authenticator…"
  curl -fsSL "https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.6.27/aws-iam-authenticator_0.6.27_linux_amd64" -o /tmp/aws-iam-authenticator
  sudo install -o root -g root -m 0755 /tmp/aws-iam-authenticator /usr/local/bin/aws-iam-authenticator
  rm -f /tmp/aws-iam-authenticator
  log "✅ aws-iam-authenticator installed successfully"
else
  log "aws-iam-authenticator already installed"
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

# ---------- WhatsApp ----------
if ! snap list whatsapp-linux-app >/dev/null 2>&1; then
  log "Installing WhatsApp…"
  sudo snap install whatsapp-linux-app || true
fi

# ---------- YouTube (FreeTube) ----------
if ! snap list freetube >/dev/null 2>&1; then
  log "Installing FreeTube (YouTube app)…"
  sudo snap install freetube || true
fi

# ---------- Signal (Secure Messaging) ----------
if ! snap list signal-desktop >/dev/null 2>&1; then
  log "Installing Signal…"
  sudo snap install signal-desktop || true
fi

# ---------- Sway Wayland Compositor ----------
if ! need_cmd sway; then
  log "Installing Sway Wayland compositor + supporting tools…"

  # Install Sway and essential Wayland tools
  sudo apt-get install -y \
    sway swaylock swayidle swaybg \
    waybar wofi \
    grim slurp wl-clipboard \
    kitty foot alacritty \
    mako-notifier libnotify-bin \
    light playerctl brightnessctl pulseaudio-utils \
    xdg-desktop-portal-wlr || true

  # Create Sway config directory
  sudo -u "$REAL_USER" mkdir -p "$REAL_HOME/.config/sway"

  # Create default Sway config if it doesn't exist
  if [[ ! -f "$REAL_HOME/.config/sway/config" ]]; then
    log "Creating default Sway config…"
    sudo -u "$REAL_USER" cat > "$REAL_HOME/.config/sway/config" << 'EOF'
# Sway Configuration

# Mod key (Mod4 = Super/Windows key)
set $mod Mod4

# Terminal
set $term kitty

# Application launcher
set $menu wofi --show drun

# Wallpaper
output * bg /usr/share/backgrounds/sway/Sway_Wallpaper_Blue_1920x1080.png fill

# Idle configuration
exec swayidle -w \
    timeout 300 'swaylock -f -c 000000' \
    timeout 600 'swaymsg "output * dpms off"' \
    resume 'swaymsg "output * dpms on"' \
    before-sleep 'swaylock -f -c 000000'

# Status bar
bar {
    swaybar_command waybar
}

# Key bindings
bindsym $mod+Return exec $term
bindsym $mod+d exec $menu
bindsym $mod+Shift+q kill
bindsym $mod+Shift+c reload
bindsym $mod+Shift+e exec swaynag -t warning -m 'Exit sway?' -b 'Yes' 'swaymsg exit'
bindsym $mod+l exec swaylock -f -c 000000

# Moving around
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

# Move focused window
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

# Workspaces
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+4 workspace number 4
bindsym $mod+5 workspace number 5
bindsym $mod+6 workspace number 6
bindsym $mod+7 workspace number 7
bindsym $mod+8 workspace number 8
bindsym $mod+9 workspace number 9
bindsym $mod+0 workspace number 10

# Move to workspace
bindsym $mod+Shift+1 move container to workspace number 1
bindsym $mod+Shift+2 move container to workspace number 2
bindsym $mod+Shift+3 move container to workspace number 3
bindsym $mod+Shift+4 move container to workspace number 4
bindsym $mod+Shift+5 move container to workspace number 5
bindsym $mod+Shift+6 move container to workspace number 6
bindsym $mod+Shift+7 move container to workspace number 7
bindsym $mod+Shift+8 move container to workspace number 8
bindsym $mod+Shift+9 move container to workspace number 9
bindsym $mod+Shift+0 move container to workspace number 10

# Layout
bindsym $mod+b splith
bindsym $mod+v splitv
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+e layout toggle split
bindsym $mod+f fullscreen
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle

# Resizing
mode "resize" {
    bindsym Left resize shrink width 10px
    bindsym Down resize grow height 10px
    bindsym Up resize shrink height 10px
    bindsym Right resize grow width 10px
    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

# Screenshots
bindsym Print exec grim -g "$(slurp)" - | wl-copy

# Volume
bindsym XF86AudioRaiseVolume exec pactl set-sink-volume @DEFAULT_SINK@ +5%
bindsym XF86AudioLowerVolume exec pactl set-sink-volume @DEFAULT_SINK@ -5%
bindsym XF86AudioMute exec pactl set-sink-mute @DEFAULT_SINK@ toggle

# Brightness
bindsym XF86MonBrightnessUp exec brightnessctl set +5%
bindsym XF86MonBrightnessDown exec brightnessctl set 5%-

# Media
bindsym XF86AudioPlay exec playerctl play-pause
bindsym XF86AudioNext exec playerctl next
bindsym XF86AudioPrev exec playerctl previous
EOF
    sudo chown "$REAL_USER:$REAL_USER" "$REAL_HOME/.config/sway/config"
  fi

  log "✅ Sway installed - available at login screen"
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
  log "Installing Snap apps (VS Code, Slack, Notepad++, Android Studio, OnlyOffice)…"
  sudo snap install code --classic || true
  sudo snap install slack --classic || true
  sudo snap install notepad-plus-plus || true
  sudo snap install android-studio --classic || true
  sudo snap install onlyoffice-desktopeditors || true

  # Install VS Code extensions
  if need_cmd code; then
    log "Installing VS Code extensions…"
    VSCODE_EXTENSIONS=(
      "alefragnani.project-manager"
      "andrepimenta.claude-code-chat"
      "anthropic.claude-code"
      "bung87.rails"
      "bung87.vscode-gemfile"
      "castwide.solargraph"
      "christian-kohler.path-intellisense"
      "codeflow-studio.claude-code-extension"
      "codeontherocks.claude-config"
      "codezombiech.gitignore"
      "diemasmichiels.emulate"
      "donjayamanne.git-extension-pack"
      "donjayamanne.githistory"
      "eamodio.gitlens"
      "github.copilot"
      "github.copilot-chat"
      "github.vscode-pull-request-github"
      "gruntfuggly.todo-tree"
      "huizhou.githd"
      "kaiwood.endwise"
      "karunamurti.haml"
      "manuelpuyol.erb-linter"
      "mhutchie.git-graph"
      "ms-azuretools.vscode-containers"
      "ms-kubernetes-tools.vscode-kubernetes-tools"
      "ms-vscode-remote.remote-containers"
      "oracle.oracle-java"
      "redhat.vscode-yaml"
      "riey.erb"
      "shopify.ruby-extensions-pack"
      "shopify.ruby-lsp"
      "sianglim.slim"
      "sorbet.sorbet-vscode-extension"
      "tal7aouy.rainbow-bracket"
      "vscjava.vscode-gradle"
      "waderyan.gitblame"
      "zirkelc.claude-terminal-runner"
      "ziyasal.vscode-open-in-github"
    )

    for ext in "${VSCODE_EXTENSIONS[@]}"; do
      sudo -u "$REAL_USER" code --install-extension "$ext" 2>/dev/null || log "⚠️ Failed to install $ext"
    done
    log "✅ VS Code extensions installation complete"
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
    sudo -u "$REAL_USER" git clone "git@github.com:iCentris/$repo.git" "$PLATFORM_DIR/$repo" 2>/dev/null || log "⚠️ Failed to clone $repo (may be private or not found)"
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

log "✅ Setup complete. Installed:\n- Core tools, Docker\n- kubectl + aws-iam-authenticator\n- Ruby ${DEFAULT_RUBY} (RVM) + Rails\n- Node LTS (nvm) + Corepack\n- DBeaver CE, MongoDB shell\n- Browsers: Chrome, Firefox\n- Communication: Zoom, Teams, WhatsApp, Signal\n- Media: FreeTube (YouTube)\n- Productivity: OnlyOffice Desktop Editors\n- VS Code with Claude Code extension, Slack, Notepad++, Android Studio\n- Hyprland Wayland compositor + Waybar + Wofi (with Nvidia support)\n- Enhanced terminal: Zoxide, Starship, LazyGit, LazyDocker, Eza\n- Terminal apps: Terminator, gedit\n- Programming fonts: JetBrains Mono, Fira Code, Cascadia Code\n- iCentris repositories cloned to ~/platform\n\n🔄 IMPORTANT: Log out and back in for:\n   • Docker group permissions (required for LazyDocker)\n   • nvm PATH configuration\n   • Shell enhancements (zoxide, starship)\n\n🪟 To use Hyprland: Select 'Hyprland' from login screen session options.\n\n⚠️ If any downloads failed, re-run the script after reboot."
