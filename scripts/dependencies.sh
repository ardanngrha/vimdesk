#!/bin/sh
# Optional macOS dependencies. Installs only missing formulae; no brew upgrade.
set -eu
case "${1:-core}" in
  core) packages='neovim git lazygit ripgrep fd python tree-sitter';;
  languages) packages='node gopls rust-analyzer pyright ruff';;
  *) echo 'Usage: ./scripts/dependencies.sh [core|languages]' >&2; exit 2;;
esac
if ! command -v brew >/dev/null 2>&1; then
  echo 'Homebrew is required for this helper: https://brew.sh' >&2
  exit 1
fi
for package in $packages; do
  if ! brew list --versions "$package" >/dev/null 2>&1; then
    HOMEBREW_NO_AUTO_UPDATE=1 brew install "$package"
  fi
done
if [ "${1:-core}" = languages ]; then
  APP_NAME=${NVIM_APPNAME:-nvim-workbench}
  DATA_BASE=${XDG_DATA_HOME:-"$HOME/.local/share"}
  case "$APP_NAME" in *[!A-Za-z0-9_-]*|'') echo 'Invalid NVIM_APPNAME' >&2; exit 2;; esac
  TOOLS_DIR="$DATA_BASE/$APP_NAME/tools"
  if [ ! -x "$TOOLS_DIR/node_modules/.bin/typescript-language-server" ]; then
    npm install --prefix "$TOOLS_DIR" typescript typescript-language-server
  fi
  echo 'Rust projects also need a Rust toolchain; Python projects need their own interpreter/venv.'
fi
echo 'Run ./install.sh doctor to check versions; existing outdated tools are not upgraded automatically.'
