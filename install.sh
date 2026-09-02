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

mkdir -p "$LOCAL_BIN" "$HOME/.claude/skills" "$HOME/.claude/commands" "$HOME/.config/opencode/command"
chmod 755 "$ROOT_DIR/scripts/wtree"

ln -sfn "$ROOT_DIR/scripts/wtree" "$LOCAL_BIN/wtree"
ln -sfn "$ROOT_DIR/skills/wtree" "$HOME/.claude/skills/wtree"
ln -sfn "$ROOT_DIR/commands/wtree.md" "$HOME/.claude/commands/wtree.md"
ln -sfn "$ROOT_DIR/commands/wtree.md" "$HOME/.config/opencode/command/wtree.md"

if [[ ! -f "$PROFILE" ]] || ! grep -Fq 'HOME/.local/bin' "$PROFILE"; then
    {
        printf '\n# wtree\n'
        printf 'export PATH="$PATH:$HOME/.local/bin"\n'
    } >> "$PROFILE"
fi

printf 'Installed wtree at %s\n' "$LOCAL_BIN/wtree"
printf 'Installed the wtree command and skill for Claude Code and OpenCode.\n'
printf 'Restart Claude Code or OpenCode, then open a new shell to use PATH changes.\n'
