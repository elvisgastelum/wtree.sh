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

create_agent_remote() {
    local name="$1"
    local remote="$TMP_DIR/$name.git"
    local seed="$TMP_DIR/$name-seed"
    local branch

    git init --bare --initial-branch=main "$remote" >/dev/null
    git init --initial-branch=main "$seed" >/dev/null

    for branch in main alt; do
        if [[ "$branch" != 'main' ]]; then
            git -C "$seed" checkout -q -b "$branch"
        fi
        mkdir -p "$seed/.claude"
        printf '{"mcpServers":{"%s":{"type":"http","url":"https://example.invalid/mcp"}}}\n' "$branch" > "$seed/.mcp.json"
        printf '# %s instructions\n' "$branch" > "$seed/CLAUDE.md"
        printf '{"branch":"%s"}\n' "$branch" > "$seed/.claude/settings.json"
        git -C "$seed" add -A >/dev/null
        git -C "$seed" -c user.name=wtree-test -c user.email=wtree-test@example.invalid commit -m "$branch config" >/dev/null
    done

    git -C "$seed" remote add origin "$remote"
    git -C "$seed" push origin main alt >/dev/null 2>&1
    git -C "$remote" symbolic-ref HEAD refs/heads/main
    printf '%s\n' "$remote"
}

no_agent_links() {
    local checkout="$1"
    local name

    for name in .mcp.json CLAUDE.md AGENTS.md .claude .opencode; do
        [[ ! -e "$checkout/$name" && ! -L "$checkout/$name" ]] || return 1
    done
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

no_agent_links "$main_checkout" || fail 'repository without agent configuration produced root links'

agent_remote="$(create_agent_remote agent)"
agent_checkout="$TMP_DIR/agent-checkout"
clone_into "$agent_checkout" "$agent_remote"

[[ -L "$agent_checkout/.mcp.json" ]] || fail '.mcp.json was not linked into the checkout root'
[[ -L "$agent_checkout/CLAUDE.md" ]] || fail 'CLAUDE.md was not linked into the checkout root'
[[ -L "$agent_checkout/.claude" ]] || fail '.claude was not linked into the checkout root'
[[ "$(readlink "$agent_checkout/.mcp.json")" == 'main/.mcp.json' ]] || fail '.mcp.json link is not relative to the checkout root'
[[ "$(readlink "$agent_checkout/.claude")" == 'main/.claude' ]] || fail '.claude link is not relative to the checkout root'
[[ "$(cat "$agent_checkout/.mcp.json")" == "$(cat "$agent_checkout/main/.mcp.json")" ]] || fail '.mcp.json link does not resolve to the worktree file'
[[ "$(cat "$agent_checkout/.claude/settings.json")" == "$(cat "$agent_checkout/main/.claude/settings.json")" ]] || fail '.claude link does not resolve to the worktree directory'
[[ ! -e "$agent_checkout/AGENTS.md" && ! -L "$agent_checkout/AGENTS.md" ]] || fail 'absent AGENTS.md was linked anyway'
[[ ! -e "$agent_checkout/.opencode" && ! -L "$agent_checkout/.opencode" ]] || fail 'absent .opencode was linked anyway'

no_link_checkout="$TMP_DIR/no-link-checkout"
clone_into "$no_link_checkout" --no-link "$agent_remote"
no_agent_links "$no_link_checkout" || fail '--no-link still linked agent configuration'

git -C "$agent_checkout/.bare" worktree add --track -b alt "$agent_checkout/alt" origin/alt >/dev/null 2>&1

if (
    cd "$agent_checkout"
    "$WTREE" link
) >/dev/null 2>&1; then
    fail 'wtree link chose a worktree while several were registered'
fi

(
    cd "$agent_checkout"
    "$WTREE" link alt
) >/dev/null
[[ "$(readlink "$agent_checkout/.mcp.json")" == 'alt/.mcp.json' ]] || fail 'wtree link did not retarget the .mcp.json link'
[[ "$(readlink "$agent_checkout/.claude")" == 'alt/.claude' ]] || fail 'wtree link did not retarget the .claude link'
[[ "$(cat "$agent_checkout/.mcp.json")" == "$(cat "$agent_checkout/alt/.mcp.json")" ]] || fail 'retargeted .mcp.json does not resolve to the alt worktree'

if (
    cd "$agent_checkout"
    "$WTREE" link missing-worktree
) >/dev/null 2>&1; then
    fail 'wtree link accepted an unregistered worktree'
fi

(
    cd "$agent_checkout/alt"
    "$WTREE" link main
) >/dev/null
[[ "$(readlink "$agent_checkout/.mcp.json")" == 'main/.mcp.json' ]] || fail 'wtree link did not resolve the checkout root from inside a worktree'

rm "$agent_checkout/CLAUDE.md"
printf 'handwritten\n' > "$agent_checkout/CLAUDE.md"
(
    cd "$agent_checkout"
    "$WTREE" link main
) >/dev/null 2>&1 || fail 'wtree link failed when a regular file occupied a link path'
[[ ! -L "$agent_checkout/CLAUDE.md" ]] || fail 'an existing regular file was replaced by a link'
[[ "$(cat "$agent_checkout/CLAUDE.md")" == 'handwritten' ]] || fail 'an existing regular file was overwritten'

single_checkout="$TMP_DIR/single-checkout"
clone_into "$single_checkout" --no-link "$agent_remote"
(
    cd "$single_checkout"
    "$WTREE" link
) >/dev/null
[[ "$(readlink "$single_checkout/.mcp.json")" == 'main/.mcp.json' ]] || fail 'wtree link did not use the only registered worktree'

outside_root="$TMP_DIR/outside"
mkdir "$outside_root"
if (
    cd "$outside_root"
    "$WTREE" link
) >/dev/null 2>&1; then
    fail 'wtree link ran outside a wtree checkout'
fi

existing_checkout="$TMP_DIR/existing-checkout"
mkdir "$existing_checkout"
if (
    cd "$TMP_DIR"
    "$WTREE" clone "$main_remote" "$existing_checkout"
) >/dev/null 2>&1; then
    fail 'existing destination directory was overwritten'
fi

# --- wtree remove ---------------------------------------------------------

TEST_ID=(-c user.name=wtree-test -c user.email=wtree-test@example.invalid)

commit_in() {
    local worktree="$1"
    local file="$2"
    local content="$3"
    local message="$4"

    printf '%s\n' "$content" > "$worktree/$file"
    git -C "$worktree" add -A >/dev/null
    git -C "$worktree" "${TEST_ID[@]}" commit -m "$message" >/dev/null
}

add_worktree() {
    local checkout="$1"
    local name="$2"

    git -C "$checkout" worktree add -b "$name" "$checkout/$name" origin/main >/dev/null 2>&1
}

run_wtree() {
    local dir="$1"
    shift

    (
        cd "$dir"
        "$WTREE" "$@"
    )
}

branch_exists_in() {
    git -C "$1" show-ref --verify --quiet "refs/heads/$2"
}

remove_remote="$(create_agent_remote agent-remove)"
remove_checkout="$TMP_DIR/remove-checkout"
clone_into "$remove_checkout" "$remove_remote"

# A branch merged with a merge commit is removed together with its branch.
add_worktree "$remove_checkout" merged
commit_in "$remove_checkout/merged" feature.txt merged 'add feature'
git -C "$remove_checkout/main" "${TEST_ID[@]}" merge --no-ff -m 'merge merged' merged >/dev/null
git -C "$remove_checkout/main" push origin main >/dev/null 2>&1

dry_run_output="$(run_wtree "$remove_checkout" remove --dry-run merged)"
[[ "$dry_run_output" == *'has landed on origin/main'* ]] || fail 'wtree remove --dry-run did not report the merged branch as landed'
[[ -d "$remove_checkout/merged" ]] || fail 'wtree remove --dry-run removed the worktree'
branch_exists_in "$remove_checkout" merged || fail 'wtree remove --dry-run deleted the branch'

run_wtree "$remove_checkout" remove merged >/dev/null
[[ ! -e "$remove_checkout/merged" ]] || fail 'wtree remove left the worktree directory behind'
! branch_exists_in "$remove_checkout" merged || fail 'wtree remove left the merged branch behind'
git -C "$remove_checkout" worktree list --porcelain | grep -qxF "worktree $remove_checkout/merged" && fail 'wtree remove left the worktree registered'

# A squash-merged branch has a tip that is not an ancestor of the base, and is
# still removed: the decision is made by patch-id, not by ancestry.
add_worktree "$remove_checkout" squashed
commit_in "$remove_checkout/squashed" one.txt one 'add one'
commit_in "$remove_checkout/squashed" two.txt two 'add two'
git -C "$remove_checkout/main" merge --squash squashed >/dev/null
git -C "$remove_checkout/main" "${TEST_ID[@]}" commit -m 'squashed squashed' >/dev/null
git -C "$remove_checkout/main" push origin main >/dev/null 2>&1

git -C "$remove_checkout" merge-base --is-ancestor squashed origin/main && fail 'the squash fixture did not produce a non-ancestor tip'
[[ -z "$(git -C "$remove_checkout" branch --merged origin/main --list squashed)" ]] || fail 'the squash fixture did not produce a branch git calls unmerged'

remove_output="$(run_wtree "$remove_checkout" remove squashed)"
[[ "$remove_output" == *'squashed or rebased commit'* ]] || fail 'wtree remove did not report the squash-merged branch deletion'
[[ ! -e "$remove_checkout/squashed" ]] || fail 'wtree remove left the squash-merged worktree behind'
! branch_exists_in "$remove_checkout" squashed || fail 'wtree remove left the squash-merged branch behind'

# Unlanded commits are refused, and --force discards them.
add_worktree "$remove_checkout" unlanded
commit_in "$remove_checkout/unlanded" pending.txt pending 'add pending'
if run_wtree "$remove_checkout" remove unlanded >/dev/null 2>&1; then
    fail 'wtree remove removed a worktree holding unlanded commits'
fi
if run_wtree "$remove_checkout" remove --dry-run unlanded >/dev/null 2>&1; then
    fail 'wtree remove --dry-run reported success for unlanded commits'
fi
[[ -d "$remove_checkout/unlanded" ]] || fail 'a refused wtree remove still removed the worktree'
run_wtree "$remove_checkout" remove --force unlanded >/dev/null
[[ ! -e "$remove_checkout/unlanded" ]] || fail 'wtree remove --force left the worktree behind'
! branch_exists_in "$remove_checkout" unlanded || fail 'wtree remove --force left the unlanded branch behind'

# Untracked files alone are enough to refuse.
add_worktree "$remove_checkout" dirty
printf 'scratch\n' > "$remove_checkout/dirty/untracked.txt"
if run_wtree "$remove_checkout" remove dirty >/dev/null 2>&1; then
    fail 'wtree remove removed a worktree holding untracked files'
fi
run_wtree "$remove_checkout" remove --force dirty >/dev/null
[[ ! -e "$remove_checkout/dirty" ]] || fail 'wtree remove --force left the dirty worktree behind'

# --keep-branch removes the directory only.
add_worktree "$remove_checkout" kept
run_wtree "$remove_checkout" remove --keep-branch kept >/dev/null
[[ ! -e "$remove_checkout/kept" ]] || fail 'wtree remove --keep-branch left the worktree behind'
branch_exists_in "$remove_checkout" kept || fail 'wtree remove --keep-branch deleted the branch'

# Guards.
add_worktree "$remove_checkout" guarded
if run_wtree "$remove_checkout" remove main >/dev/null 2>&1; then
    fail 'wtree remove removed the default-branch worktree'
fi
if run_wtree "$remove_checkout/guarded" remove guarded >/dev/null 2>&1; then
    fail 'wtree remove ran from inside the worktree it removes'
fi
if run_wtree "$remove_checkout" remove nosuch >/dev/null 2>&1; then
    fail 'wtree remove accepted an unregistered worktree'
fi
if run_wtree "$remove_checkout" remove >/dev/null 2>&1; then
    fail 'wtree remove ran without naming a worktree'
fi
run_wtree "$remove_checkout" remove guarded >/dev/null

single_remove_checkout="$TMP_DIR/single-remove-checkout"
clone_into "$single_remove_checkout" "$main_remote"
if run_wtree "$single_remove_checkout" remove main >/dev/null 2>&1; then
    fail 'wtree remove emptied a checkout of every worktree'
fi

if (
    cd "$outside_root"
    "$WTREE" remove anything
) >/dev/null 2>&1; then
    fail 'wtree remove ran outside a wtree checkout'
fi

# Removing the worktree the checkout root's agent configuration points at
# repoints it, because the alternative is a root full of dangling links.
add_worktree "$remove_checkout" linked
commit_in "$remove_checkout/linked" linked.txt linked 'add linked'
git -C "$remove_checkout/main" "${TEST_ID[@]}" merge --no-ff -m 'merge linked' linked >/dev/null
git -C "$remove_checkout/main" push origin main >/dev/null 2>&1
run_wtree "$remove_checkout" link linked >/dev/null
[[ "$(readlink "$remove_checkout/CLAUDE.md")" == 'linked/CLAUDE.md' ]] || fail 'the link fixture did not point at the linked worktree'

run_wtree "$remove_checkout" remove linked >/dev/null
[[ "$(readlink "$remove_checkout/CLAUDE.md")" == 'main/CLAUDE.md' ]] || fail 'wtree remove did not repoint CLAUDE.md at the remaining worktree'
[[ "$(readlink "$remove_checkout/.claude")" == 'main/.claude' ]] || fail 'wtree remove did not repoint .claude at the remaining worktree'
[[ -f "$remove_checkout/CLAUDE.md" ]] || fail 'wtree remove left a dangling CLAUDE.md link at the checkout root'
[[ "$(cat "$remove_checkout/CLAUDE.md")" == '# main instructions' ]] || fail 'the repointed link does not resolve to the remaining worktree'

# With several worktrees left there is nothing to guess: the links are removed
# so that wtree link can recreate them.
add_worktree "$remove_checkout" ambiguous-one
add_worktree "$remove_checkout" ambiguous-two
run_wtree "$remove_checkout" link ambiguous-one >/dev/null
run_wtree "$remove_checkout" remove ambiguous-one >/dev/null 2>&1
no_agent_links "$remove_checkout" || fail 'wtree remove left agent configuration links pointing into a removed worktree'
run_wtree "$remove_checkout" link ambiguous-two >/dev/null
[[ "$(readlink "$remove_checkout/CLAUDE.md")" == 'ambiguous-two/CLAUDE.md' ]] || fail 'wtree link could not recreate the links after a removal'
run_wtree "$remove_checkout" remove ambiguous-two >/dev/null 2>&1

printf 'wtree integration tests passed\n'
