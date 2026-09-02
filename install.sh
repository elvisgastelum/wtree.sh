#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
LOCAL_BIN="$HOME/.local/bin"
SHELL_NAME="$(basename "${SHELL:-sh}")"

case "$SHELL_NAME" in
    zsh) PROFILE="$HOME/.zshrc" ;;
    bash) PROFILE="$HOME/.bashrc" ;;
    *) PROFILE="$HOME/.profile" ;;
esac

if [[ -t 1 ]]; then
    BOLD=$'\033[1m'
    GREEN=$'\033[32m'
    BLUE=$'\033[34m'
    RESET=$'\033[0m'
else
    BOLD=''
    GREEN=''
    BLUE=''
    RESET=''
fi

step() {
    printf '%b==>%b %s\n' "$BLUE$BOLD" "$RESET" "$*"
}

success() {
    printf '%b==>%b %s\n' "$GREEN$BOLD" "$RESET" "$*"
}

step 'Preparing local command directory'
mkdir -p "$LOCAL_BIN" "$HOME/.claude/skills" "$HOME/.claude/commands" "$HOME/.config/opencode/skills" "$HOME/.config/opencode/command"

step 'Installing wtree command'
chmod 755 "$ROOT_DIR/scripts/wtree"

ln -sfn "$ROOT_DIR/scripts/wtree" "$LOCAL_BIN/wtree"

step 'Installing AI command integrations'
ln -sfn "$ROOT_DIR/skills/wtree" "$HOME/.claude/skills/wtree"
ln -sfn "$ROOT_DIR/commands/wtree.md" "$HOME/.claude/commands/wtree.md"
ln -sfn "$ROOT_DIR/skills/wtree" "$HOME/.config/opencode/skills/wtree"
ln -sfn "$ROOT_DIR/commands/wtree.md" "$HOME/.config/opencode/command/wtree.md"

if [[ ! -f "$PROFILE" ]] || ! grep -Fq 'HOME/.local/bin' "$PROFILE"; then
    step "Adding ~/.local/bin to $PROFILE"
    {
        printf '\n# wtree\n'
        printf 'export PATH="$PATH:$HOME/.local/bin"\n'
    } >> "$PROFILE"
else
    step "~/.local/bin is already configured in $PROFILE"
fi

success "Installed wtree at $LOCAL_BIN/wtree"
printf 'Open a new shell to use PATH changes. Restart Claude Code or OpenCode to reload wtree.\n'
