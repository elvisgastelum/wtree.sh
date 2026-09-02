#!/bin/sh

set -eu

REPOSITORY="${WTREE_REPOSITORY:-https://github.com/elvisgastelum/wtree.sh.git}"
INSTALL_DIR="${WTREE_INSTALL_DIR:-$HOME/.local/share/wtree.sh}"
BRANCH="${WTREE_BRANCH:-main}"

if [ -t 1 ]; then
    BOLD='\033[1m'
    GREEN='\033[32m'
    BLUE='\033[34m'
    RED='\033[31m'
    RESET='\033[0m'
else
    BOLD=''
    GREEN=''
    BLUE=''
    RED=''
    RESET=''
fi

step() {
    printf '%b==>%b %s\n' "$BLUE$BOLD" "$RESET" "$*"
}

success() {
    printf '%b==>%b %s\n' "$GREEN$BOLD" "$RESET" "$*"
}

error() {
    printf '%bError:%b %s\n' "$RED$BOLD" "$RESET" "$*" >&2
    exit 1
}

command -v git >/dev/null 2>&1 || error 'Git is required. Install Git and run this command again.'
command -v bash >/dev/null 2>&1 || error 'Bash is required. Install Bash and run this command again.'

if [ -e "$INSTALL_DIR" ]; then
    [ -d "$INSTALL_DIR/.git" ] || error "$INSTALL_DIR exists but is not a wtree checkout."

    origin="$(git -C "$INSTALL_DIR" remote get-url origin 2>/dev/null || true)"
    [ "$origin" = "$REPOSITORY" ] || error "$INSTALL_DIR belongs to $origin, not $REPOSITORY."

    step 'Updating wtree'
    git -C "$INSTALL_DIR" pull --ff-only --quiet origin "$BRANCH" || error 'Could not fast-forward the existing checkout.'
else
    step 'Cloning wtree'
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone --branch "$BRANCH" --depth 1 --quiet "$REPOSITORY" "$INSTALL_DIR" || error 'Could not clone wtree.'
fi

step 'Installing wtree'
bash "$INSTALL_DIR/install.sh"
success 'wtree is ready'
printf 'Run %bwtree --help%b to get started.\n' "$BOLD" "$RESET"
