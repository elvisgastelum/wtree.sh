# wtree

`wtree` creates Git repositories that share a bare repository and use sibling worktrees for branches.

```text
checkout/
  .bare/       # shared bare Git repository
  main/        # initial worktree
  feature-x/   # additional worktree
```

## Install

Install from this repository:

```bash
make install
```

It makes `scripts/wtree` executable, links it as `~/.local/bin/wtree`, and adds `~/.local/bin` to the active shell profile only when it is not already configured. It also installs linked global integrations for Claude Code and OpenCode:

- `~/.claude/skills/wtree`
- `~/.claude/commands/wtree.md`
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
-h, --help              Show help.
-V, --version           Show the version.
```

For a default branch named `dev/MAIN`, the initial worktree is `MAIN/`. Use `--worktree-dir` to override that name:

```bash
wtree clone --branch dev/MAIN --worktree-dir dev-main <repo-url>
```

If the remote has no default branch, `wtree` offers its remote branches interactively. Non-interactive callers must pass `--branch` in that case.

## Worktrees

Use the shared bare repository to add and remove sibling worktrees:

```bash
git -C .bare worktree list
git -C .bare worktree add -b feature-x ../feature-x main
git -C .bare worktree remove ../feature-x
git -C .bare worktree prune
```

Run normal Git commands from the individual worktree directories.

## Agent Command

Claude Code and OpenCode expose the installed command as:

```text
/wtree clone <repo-url>
```

For that minimal form, the CLI creates a new directory named after the repository in the current directory. The agent skill recognizes an existing wtree checkout by locating and verifying its ancestor `.bare` directory before using worktree commands.
