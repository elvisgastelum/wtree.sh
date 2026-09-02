# wtree

`wtree` creates Git repositories that share a bare repository and use sibling worktrees for branches.

```text
checkout/
  .bare/       # shared bare Git repository
  main/        # initial worktree
  feature-x/   # additional worktree
```

## Install

Install from a new machine:

```bash
curl -fsSL https://raw.githubusercontent.com/elvisgastelum/wtree.sh/main/bootstrap.sh | sh
```

This clones wtree into `~/.local/share/wtree.sh`, makes `scripts/wtree` executable, links it as `~/.local/bin/wtree`, and adds `~/.local/bin` to the active shell profile only when it is not already configured. Re-running the command safely fast-forwards the checkout.

For an existing local clone:

```bash
make install
```

Both installation methods also install linked global integrations for Claude Code and OpenCode:

- `~/.claude/skills/wtree`
- `~/.claude/commands/wtree.md`
- `~/.config/opencode/skills/wtree`
- `~/.config/opencode/command/wtree.md`

Open a new shell after an added PATH entry. Restart Claude Code and OpenCode after installation so they reload the command and skill.

Remove links that point to this checkout with:

```bash
make uninstall
```

Uninstall leaves the PATH entry in place because it may be used by other tools.

## Clone

Run `wtree clone` from the parent directory where the checkout should be created. It creates a repository-named child directory containing `.bare`, fetches all remote branches as remote-tracking branches, and creates the first worktree from the remote's default branch.

```bash
cd ~/Projects
wtree clone git@github.com:owner/repository.git
```

The example creates `~/Projects/repository/`. Pass a destination directory to choose a different checkout name or location:

```bash
wtree clone git@github.com:owner/repository.git ~/Projects/custom-repository
```

Specify a branch when you do not want the remote default branch:

```bash
wtree clone --branch main https://github.com/owner/repository.git
```

Options:

```text
-b, --branch <name>     First worktree branch.
    --worktree-dir <path>
                        First worktree directory (default: branch basename).
    --bare-dir <path>   Bare repository directory (default: .bare).
-r, --remote <name>     Remote name (default: origin).
    --no-link           Skip linking agent configuration after cloning.
-h, --help              Show help.
-V, --version           Show the version.
```

For a default branch named `dev/MAIN`, the initial worktree is `MAIN/`. Use `--worktree-dir` to override that name:

```bash
wtree clone --branch dev/MAIN --worktree-dir dev-main <repo-url>
```

If the remote has no default branch, `wtree` offers its remote branches interactively. Non-interactive callers must pass `--branch` in that case.

## Worktrees

Use the shared bare repository to add sibling worktrees, and run normal Git commands from the
individual worktree directories:

```bash
git -C .bare worktree list
git -C .bare worktree add -b feature-x ../feature-x main
```

## Remove

A worktree exists to host one branch. When that branch has landed, `wtree remove` retires the whole
thing in one step: it removes the directory, deletes the local branch, repoints the checkout root's
agent configuration, and prunes.

```bash
cd checkout
wtree remove --dry-run feature-x   # report what removal would do, change nothing
wtree remove feature-x
```

Options:

```text
    --base <ref>        Branch the work must have landed on
                        (default: the remote's default branch).
    --keep-branch       Remove the worktree but keep the local branch.
    --force             Remove despite uncommitted, untracked or unlanded work.
                        This discards it.
-n, --dry-run           Report what removal would do and change nothing.
```

"Landed" is decided by content, not by ancestry. Squash and rebase merges leave the branch tip a
non-ancestor of the base, so `git branch --merged` calls almost every finished branch unmerged;
`wtree remove` also compares the branch's squashed patch against the base, and recognises it.

It refuses rather than prompts — the worktree you are standing in, the one holding the remote's
default branch, the last one in the checkout, and any worktree with uncommitted or untracked files
or with commits that have not landed. `--force` overrides the last two and discards that work.
Stashes are never at risk: they live in the shared repository, not in the worktree. The remote
branch is never touched; deleting it stays a deliberate `git push --delete`.

For anything `wtree remove` deliberately refuses, the raw commands are still there:

```bash
git -C .bare worktree remove ../feature-x
git -C .bare worktree prune
```

## Agent Command

Claude Code and OpenCode expose the installed command as:

```text
/wtree clone <repo-url>
```

For that minimal form, the CLI creates a new directory named after the repository in the current directory. The agent skill recognizes an existing wtree checkout by locating and verifying its ancestor `.bare` directory before using worktree commands.

## Agent Configuration At The Checkout Root

Agent configuration lives inside a worktree, but agents read it from the directory they are
**launched** in. The checkout root is the natural place to start an agent, because it is the only
directory that sees every worktree — and it is exactly where none of that configuration resolves. An
agent started there begins without the repository's MCP servers, settings, hooks or instructions,
and nothing it does at runtime can load them.

`wtree clone` therefore links the new worktree's agent configuration into the checkout root:

```text
.mcp.json     CLAUDE.md     AGENTS.md     .claude/     .opencode/
```

Each is linked only when it exists in the worktree, as a relative symlink so the checkout stays
movable. A repository with no agent configuration gets no links. An existing regular file at the
root is never replaced — `wtree` warns and leaves it alone. The links live outside every worktree,
so they never show up in `git status`.

Pass `--no-link` to skip this. Use `wtree link` to add the links to a checkout created before this
behavior existed, or to repoint them at another worktree:

```bash
cd checkout
wtree link            # the only registered worktree
wtree link dev        # a specific worktree
```

`wtree link` runs from the checkout root or from inside any of its worktrees. Restart the agent
afterwards: MCP servers, hooks and permissions are read once at startup.

Removing a worktree is the other half of this. The root's links point *into* a worktree, so deleting
that worktree would leave the root full of dangling links — and a dangling link cannot be repaired by
`wtree link`, which refuses to touch a link it cannot resolve. `wtree remove` therefore takes the
links down as part of the removal and puts them back on the remaining worktree, or, when several are
left and the choice is not obvious, prints the `wtree link` command for each candidate.

## Agent Worktree Context

The installed Claude Code and OpenCode skill activates only inside a verified `wtree clone` checkout. It recognizes the checkout root even when the agent starts there instead of inside `main/` or another worktree, then lists the shared bare repository's registered worktrees before editing code.

When the user says a branch's work is done, the agent proposes `wtree remove --dry-run <worktree>`,
shows what it reports, and waits for confirmation before the real run. It never scans for landed
branches on its own and never passes `--force` unless told to.

For a new feature, the agent first checks project instructions and existing branches for naming conventions. It then suggests a sanitized branch name and sibling worktree directory, such as `feature-export-csv/`, and waits for confirmation before creating it. Project conventions take precedence over the suggested fallback name.

The agent creates confirmed worktrees through `.bare`, bases them on the configured remote's default branch, and performs edits, commits, pulls, and pushes only from the selected sibling worktree. The checkout root and `.bare/` are never treated as source working directories.

When it starts at the checkout root with several worktrees registered, the agent asks which one to work in before reading source. It then reads that worktree's `CLAUDE.md`, `AGENTS.md`, `CONTEXT.md`, `docs/agents/` and `.claude/` itself, because nothing loaded them for it. Configuration that only takes effect at startup — MCP servers, hooks, permissions, plugins — cannot be recovered mid-session, so the agent checks whether it is present, reports plainly when it is not, points at `wtree link`, and keeps working on whatever does not depend on it.
