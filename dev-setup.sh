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

# ---------- Hyprland Wayland Compositor (with Nvidia support) ----------
if ! need_cmd Hyprland; then
  log "Installing Hyprland Wayland compositor + supporting tools…"

  # Install supporting Wayland tools first
  sudo apt-get install -y \
    waybar wofi kitty foot alacritty \
    grim slurp wl-clipboard \
    swaylock swayidle \
    light playerctl brightnessctl pulseaudio-utils \
    dunst libnotify-bin || true

  # Install Hyprland build dependencies
  sudo apt-get install -y \
    meson wget build-essential ninja-build cmake-extras cmake gettext gettext-base \
    fontconfig libfontconfig-dev libffi-dev libxml2-dev libdrm-dev libxkbcommon-x11-dev \
    libxkbregistry-dev libxkbcommon-dev libpixman-1-dev libudev-dev libseat-dev seatd \
    libxcb-dri3-dev libvulkan-dev libvulkan-volk-dev vulkan-utility-libraries-dev \
    libegl-dev libgles2 libegl1-mesa-dev glslang-tools \
    libinput-bin libinput-dev libxcb-composite0-dev libavutil-dev libavcodec-dev \
    libavformat-dev libxcb-ewmh2 libxcb-ewmh-dev libxcb-present-dev libxcb-icccm4-dev \
    libxcb-render-util0-dev libxcb-res0-dev libxcb-xinput-dev xdg-desktop-portal-wlr \
    libtomlplusplus3 || true

  # Upgrade CMake if needed (Hyprland requires 3.30+)
  CMAKE_VERSION=$(cmake --version 2>/dev/null | head -n1 | grep -oP '\d+\.\d+' | head -1 || echo "0")
  if ! awk -v ver="$CMAKE_VERSION" 'BEGIN{exit(!(ver>=3.30))}' 2>/dev/null; then
    log "Upgrading CMake to latest version (required for Hyprland)…"
    # Remove old cmake
    sudo apt-get remove -y cmake cmake-data 2>/dev/null || true

    # Install latest CMake from Kitware's repository
    wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | sudo tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/kitware.list >/dev/null
    sudo apt-get update -y
    sudo apt-get install -y cmake || true
  fi

  # Build and install Hyprland from source
  log "Building Hyprland from source (this may take 5-10 minutes)…"
  # Temporarily disable unbound variable check for Hyprland build
  set +u
  TEMP_BUILD_DIR=$(mktemp -d)
  cd "$TEMP_BUILD_DIR"

  if git clone --recursive https://github.com/hyprwm/Hyprland 2>/dev/null; then
    cd Hyprland
    # Build with Nvidia support
    if make all && sudo make install; then
      log "✅ Hyprland built and installed successfully"

      # Create desktop session file for login screen
      sudo tee /usr/share/wayland-sessions/hyprland.desktop >/dev/null << 'DESKTOP_EOF'
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
DESKTOP_EOF

      log "✅ Hyprland session file created at /usr/share/wayland-sessions/hyprland.desktop"
    else
      log "⚠️ Hyprland build failed. Check /tmp/hyprland-build.log for details"
    fi
  else
    log "⚠️ Failed to clone Hyprland repository"
  fi

  cd /tmp
  rm -rf "$TEMP_BUILD_DIR"
  # Re-enable unbound variable check
  set -u

  # Create default config
  sudo -u "$REAL_USER" mkdir -p "$REAL_HOME/.config/hypr"
  if [[ ! -f "$REAL_HOME/.config/hypr/hyprland.conf" ]]; then
    log "Creating default Hyprland config with Nvidia optimizations…"
    sudo -u "$REAL_USER" cat > "$REAL_HOME/.config/hypr/hyprland.conf" << 'EOF'
# Hyprland Configuration with Nvidia Support

# Environment variables for Nvidia
env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = WLR_NO_HARDWARE_CURSORS,1

# Monitor configuration
monitor=,preferred,auto,1

# Execute apps at launch
exec-once = waybar
exec-once = dunst
exec-once = swayidle -w timeout 300 'swaylock -f -c 000000' timeout 600 'hyprctl dispatch dpms off' resume 'hyprctl dispatch dpms on'

# Input configuration
input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = false
    }
    sensitivity = 0
}

# General settings
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

# Decoration
decoration {
    rounding = 5
    blur {
        enabled = true
        size = 3
        passes = 1
    }
    drop_shadow = true
    shadow_range = 4
    shadow_render_power = 3
    col.shadow = rgba(1a1a1aee)
}

# Animations
animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

# Layouts
dwindle {
    pseudotile = true
    preserve_split = true
}

# Key bindings
$mainMod = SUPER

bind = $mainMod, Return, exec, kitty
bind = $mainMod, Q, killactive,
bind = $mainMod, M, exit,
bind = $mainMod, E, exec, thunar
bind = $mainMod, V, togglefloating,
bind = $mainMod, D, exec, wofi --show drun
bind = $mainMod, P, pseudo,
bind = $mainMod, J, togglesplit,
bind = $mainMod, L, exec, swaylock -f -c 000000

# Move focus with mainMod + arrow keys
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Switch workspaces with mainMod + [0-9]
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

# Move active window to workspace with mainMod + SHIFT + [0-9]
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

# Scroll through workspaces with mainMod + scroll
bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1

# Move/resize windows with mainMod + LMB/RMB
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

# Screenshot
bind = , Print, exec, grim -g "$(slurp)" - | wl-copy

# Volume control
bind = , XF86AudioRaiseVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ +5%
bind = , XF86AudioLowerVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ -5%
bind = , XF86AudioMute, exec, pactl set-sink-mute @DEFAULT_SINK@ toggle

# Brightness control
bind = , XF86MonBrightnessUp, exec, brightnessctl set +5%
bind = , XF86MonBrightnessDown, exec, brightnessctl set 5%-

# Media controls
bind = , XF86AudioPlay, exec, playerctl play-pause
bind = , XF86AudioNext, exec, playerctl next
bind = , XF86AudioPrev, exec, playerctl previous
EOF
  fi

  log "✅ Hyprland installed with Nvidia support"
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

log "✅ Setup complete. Installed:\n- Core tools, Docker\n- Ruby ${DEFAULT_RUBY} (RVM) + Rails\n- Node LTS (nvm) + Corepack\n- DBeaver CE, MongoDB shell\n- Browsers: Chrome, Firefox\n- Communication: Zoom, Teams, WhatsApp, Signal\n- Media: FreeTube (YouTube)\n- VS Code with Claude Code extension, Slack, Notepad++, Android Studio\n- Hyprland Wayland compositor + Waybar + Wofi (with Nvidia support)\n- Enhanced terminal: Zoxide, Starship, LazyGit, LazyDocker, Eza\n- Terminal apps: Terminator, gedit\n- Programming fonts: JetBrains Mono, Fira Code, Cascadia Code\n- iCentris repositories cloned to ~/platform\n\n🔄 IMPORTANT: Log out and back in for:\n   • Docker group permissions (required for LazyDocker)\n   • nvm PATH configuration\n   • Shell enhancements (zoxide, starship)\n\n🪟 To use Hyprland: Select 'Hyprland' from login screen session options.\n\n⚠️ If any downloads failed, re-run the script after reboot."
