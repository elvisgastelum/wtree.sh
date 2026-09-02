#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
WTREE="$ROOT_DIR/scripts/wtree"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wtree-test.XXXXXX")"

trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
    printf 'Test failed: %s\n' "$*" >&2
    exit 1
}

create_remote() {
    local name="$1"
    local default_branch="$2"
    local remote="$TMP_DIR/$name.git"
    local seed="$TMP_DIR/$name-seed"

    git init --bare --initial-branch="$default_branch" "$remote" >/dev/null
    git init --initial-branch="$default_branch" "$seed" >/dev/null
    git -C "$seed" -c user.name=wtree-test -c user.email=wtree-test@example.invalid commit --allow-empty -m initial >/dev/null
    git -C "$seed" remote add origin "$remote"
    git -C "$seed" push origin "$default_branch" >/dev/null
    printf '%s\n' "$remote"
}

clone_into() {
    local checkout="$1"
    shift

    (
        cd "$(dirname "$checkout")"
        "$WTREE" clone "$@" "$(basename "$checkout")"
    ) >/dev/null
}

main_remote="$(create_remote main main)"
default_parent="$TMP_DIR/default-parent"
mkdir "$default_parent"
(
    cd "$default_parent"
    "$WTREE" clone "$main_remote"
) >/dev/null
[[ -d "$default_parent/main/.bare" ]] || fail 'default destination did not contain bare repository'
[[ -d "$default_parent/main/main" ]] || fail 'default destination did not contain main worktree'

main_checkout="$TMP_DIR/main-checkout"
clone_into "$main_checkout" "$main_remote"
[[ -d "$main_checkout/.bare" ]] || fail 'missing bare repository'
[[ -d "$main_checkout/main" ]] || fail 'missing main worktree'
[[ "$(git -C "$main_checkout/.bare" symbolic-ref --short refs/remotes/origin/HEAD)" == 'origin/main' ]] || fail 'missing origin default branch'
[[ "$(git -C "$main_checkout/main" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}')" == 'origin/main' ]] || fail 'main worktree does not track origin/main'

nested_remote="$(create_remote nested dev/MAIN)"
nested_checkout="$TMP_DIR/nested-checkout"
clone_into "$nested_checkout" "$nested_remote"
[[ -d "$nested_checkout/MAIN" ]] || fail 'nested default branch did not use its basename'
[[ "$(git -C "$nested_checkout/MAIN" branch --show-current)" == 'dev/MAIN' ]] || fail 'nested default branch was not checked out'
[[ "$(git -C "$nested_checkout/.bare" symbolic-ref --short refs/remotes/origin/HEAD)" == 'origin/dev/MAIN' ]] || fail 'nested origin default branch was not recorded'

custom_checkout="$TMP_DIR/custom-checkout"
clone_into "$custom_checkout" --branch main --worktree-dir workspace "$main_remote"
[[ -d "$custom_checkout/workspace" ]] || fail 'custom worktree directory was not created'

no_default_remote="$TMP_DIR/no-default.git"
no_default_seed="$TMP_DIR/no-default-seed"
git init --bare --initial-branch=missing "$no_default_remote" >/dev/null
git init --initial-branch=topic "$no_default_seed" >/dev/null
git -C "$no_default_seed" -c user.name=wtree-test -c user.email=wtree-test@example.invalid commit --allow-empty -m initial >/dev/null
git -C "$no_default_seed" remote add origin "$no_default_remote"
git -C "$no_default_seed" push origin topic >/dev/null

missing_branch_checkout="$TMP_DIR/missing-branch-checkout"
mkdir "$missing_branch_checkout"
if (
    cd "$missing_branch_checkout"
    "$WTREE" clone "$no_default_remote"
) >/dev/null 2>&1; then
    fail 'missing remote default branch did not require --branch outside a terminal'
fi

no_default_checkout="$TMP_DIR/no-default-checkout"
clone_into "$no_default_checkout" --branch topic "$no_default_remote"
[[ -d "$no_default_checkout/topic" ]] || fail 'explicit branch was not cloned without remote default branch'

existing_checkout="$TMP_DIR/existing-checkout"
mkdir "$existing_checkout"
if (
    cd "$TMP_DIR"
    "$WTREE" clone "$main_remote" "$existing_checkout"
) >/dev/null 2>&1; then
    fail 'existing destination directory was overwritten'
fi

printf 'wtree integration tests passed\n'
