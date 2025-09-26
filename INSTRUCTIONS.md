# Ubuntu Developer Setup — Bundle

This bundle contains a **ready-to-run setup script** for a fresh Ubuntu developer machine.

## What gets installed
- **Core tools**: build-essential, git, curl/wget, zsh, tmux, fzf, ripgrep, htop, jq, vim/neovim, etc.
- **Docker Engine + Compose plugin**
- **Ruby** (RVM) — default Ruby 3.2.2 + bundler + rails
- **Node.js** (nvm) — latest LTS + Corepack (Yarn/pnpm)
- **DBeaver CE** (DB GUI) and **MongoDB shell** (`mongosh`)
- **Browsers & Apps**: Google Chrome, Firefox, Zoom, Microsoft Teams
- **Snap apps**: VS Code, Slack, Notepad++, Android Studio

## How to use
1) Download and unzip:
```bash
unzip ubuntu_dev_setup_bundle.zip -d ~/setup && cd ~/setup/ubuntu_dev_setup_bundle
```
2) Run the script:
```bash
chmod +x dev-setup.sh
./dev-setup.sh
```
3) **Log out and back in** (or reboot) so the `docker` group + `nvm` PATH take effect.

## Chrome extensions (quick-install links)
Open these after signing into Chrome:
- WhatsApp Web — https://chrome.google.com/webstore/detail/whatsapp-web/ophjlpahpchlmihnnnihgmmeilfjmjjc
- Messenger — https://chrome.google.com/webstore/detail/messenger/fbcnjjlefhkmefcedfihbohijidjhjgn
- Save to Google Drive — https://chrome.google.com/webstore/detail/save-to-google-drive/gmbmikajjgmnabiglmofipeabaddhgne
- Grammarly — https://chrome.google.com/webstore/detail/grammarly/kbfnbcaeplbcioakkpcpgfkobkghlhen

## Notes
- Prefer Docker for databases/services to keep your host clean.
- Want rbenv instead of RVM? Ask me for a variant.
- If Snap is disabled in your Ubuntu flavor, install the .deb versions of VS Code/Slack or enable Snap first.
