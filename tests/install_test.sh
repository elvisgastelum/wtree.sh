#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wtree-install-test.XXXXXX")"
TMP_DIR="$(CDPATH= cd -- "$TMP_DIR" && pwd)"

trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
    printf 'Test failed: %s\n' "$*" >&2
    exit 1
}

seed="$TMP_DIR/seed"
remote="$TMP_DIR/wtree.git"
repository="file://$remote"
home="$TMP_DIR/home"
install_dir="$home/.local/share/wtree.sh"

mkdir "$seed" "$home"
cp "$ROOT_DIR/bootstrap.sh" "$ROOT_DIR/install.sh" "$ROOT_DIR/Makefile" "$seed/"
cp -R "$ROOT_DIR/scripts" "$ROOT_DIR/skills" "$ROOT_DIR/commands" "$seed/"

git init --initial-branch=main "$seed" >/dev/null
git -C "$seed" add .
git -C "$seed" -c user.name=wtree-test -c user.email=wtree-test@example.invalid commit -m initial >/dev/null
git init --bare --initial-branch=main "$remote" >/dev/null
git -C "$seed" remote add origin "$remote"
git -C "$seed" push origin main >/dev/null

run_bootstrap() {
    env \
        HOME="$home" \
        SHELL=/bin/bash \
        WTREE_REPOSITORY="$repository" \
        WTREE_INSTALL_DIR="$install_dir" \
        sh "$ROOT_DIR/bootstrap.sh" >/dev/null
}

run_bootstrap

[[ -x "$install_dir/scripts/wtree" ]] || fail 'wtree command is not executable'
[[ "$(readlink "$home/.local/bin/wtree")" == "$install_dir/scripts/wtree" ]] || fail 'wtree symlink is incorrect'
[[ "$(readlink "$home/.claude/skills/wtree")" == "$install_dir/skills/wtree" ]] || fail 'Claude skill symlink is incorrect'
[[ "$(readlink "$home/.claude/commands/wtree.md")" == "$install_dir/commands/wtree.md" ]] || fail 'Claude command symlink is incorrect'
[[ "$(readlink "$home/.config/opencode/skills/wtree")" == "$install_dir/skills/wtree" ]] || fail 'OpenCode skill symlink is incorrect'
[[ "$(readlink "$home/.config/opencode/command/wtree.md")" == "$install_dir/commands/wtree.md" ]] || fail 'OpenCode command symlink is incorrect'
[[ "$(grep -Fc 'export PATH="$PATH:$HOME/.local/bin"' "$home/.bashrc")" == 1 ]] || fail 'PATH entry was not added exactly once'

touch "$seed/updated"
git -C "$seed" add updated
git -C "$seed" -c user.name=wtree-test -c user.email=wtree-test@example.invalid commit -m update >/dev/null
git -C "$seed" push origin main >/dev/null

run_bootstrap

[[ -f "$install_dir/updated" ]] || fail 'existing checkout was not fast-forwarded'
[[ "$(grep -Fc 'export PATH="$PATH:$HOME/.local/bin"' "$home/.bashrc")" == 1 ]] || fail 'PATH entry was duplicated'

env HOME="$home" make -C "$install_dir" uninstall >/dev/null

[[ ! -e "$home/.local/bin/wtree" ]] || fail 'wtree symlink was not removed'
[[ ! -e "$home/.claude/skills/wtree" ]] || fail 'Claude skill symlink was not removed'
[[ ! -e "$home/.claude/commands/wtree.md" ]] || fail 'Claude command symlink was not removed'
[[ ! -e "$home/.config/opencode/skills/wtree" ]] || fail 'OpenCode skill symlink was not removed'
[[ ! -e "$home/.config/opencode/command/wtree.md" ]] || fail 'OpenCode command symlink was not removed'

printf 'wtree installation tests passed\n'
