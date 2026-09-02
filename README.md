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

Run `wtree clone` in an empty directory. It creates `.bare` and the first worktree, named after the selected branch.

```bash
mkdir example && cd example
wtree clone git@github.com:owner/repository.git
```

Specify a branch to skip the interactive branch selector:

```bash
wtree clone --branch main https://github.com/owner/repository.git
```

Options:

```text
-b, --branch <name>     First worktree branch.
    --bare-dir <path>   Bare repository directory (default: .bare).
-r, --remote <name>     Remote name (default: origin).
-h, --help              Show help.
-V, --version           Show the version.
```

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

For that minimal form, the agent creates a new directory named after the repository in the current directory, then runs `wtree clone` inside it. The agent skill recognizes an existing wtree checkout by locating and verifying its ancestor `.bare` directory before using worktree commands.
