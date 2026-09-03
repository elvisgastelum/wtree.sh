---
name: wtree
description: Use ONLY for `/wtree` requests or when the current directory is inside a verified wtree clone checkout with an ancestor `.bare` repository. Guides worktree selection, loading a worktree's agent configuration, safe multi-worktree feature work, branches, pulls, pushes, and retiring a worktree whose branch has landed.
---

# wtree

`wtree` bootstraps a repository layout with a shared bare Git repository and one or more sibling worktrees:

```text
checkout/
  .bare/                 # shared bare Git repository
  main/                  # initial worktree
  feat/
    export-csv/          # worktree for branch feat/export-csv
  BSV-1/
    export-csv/          # worktree for ticket branch BSV-1/export-csv
```

A worktree directory is the branch name, path separators included. A branch
never becomes a flattened `feat-export-csv/`, so the directory tree reads as the
branch list and every command that names a worktree takes the branch name
verbatim.

## Detect A wtree Checkout

Starting in the current directory, inspect each ancestor for `.bare`. Treat the checkout as wtree-managed only when this verifies it is bare:

```bash
git -C <checkout>/.bare rev-parse --is-bare-repository
```

The result must be `true`. Do not infer the layout only from a worktree's `.git` file. If no verified ancestor exists, this skill does not apply: follow ordinary Git workflows.

## Orient Before Working

At the beginning of every task in a verified checkout:

1. Set `<checkout>` to the ancestor that contains the verified `.bare` directory.
2. Inspect the registered worktrees before choosing a directory:

```bash
git -C <checkout>/.bare worktree list --porcelain
git -C <checkout>/.bare remote -v
```

3. Determine whether the current directory is inside one of those worktrees. The checkout root and `<checkout>/.bare` are not source working directories.
4. Select the worktree to work in:
   - Inside a worktree already: use that one.
   - At the checkout root with exactly one worktree registered: use it and say which one.
   - At the checkout root with several registered: **ask the user which worktree** before reading source or making changes. Do not guess from the branch names.
5. Load that worktree's agent configuration before any other work — see **Load Agent Configuration**.
6. Run project instructions and source-code inspection from the selected worktree, not from the checkout root.

Treat sibling worktrees as concurrent checkouts. A branch can be checked out in only one worktree; never use `git switch` or `git checkout` to take a branch already assigned to another worktree.

## Load Agent Configuration

Agent configuration lives inside each worktree, but agents resolve it from the directory they were **launched** in. An agent started at the checkout root therefore begins with none of it loaded. `wtree clone` links the configuration into the checkout root to prevent this, but a checkout created before that behavior, or one whose links point at a different worktree, still starts blind.

### Read what is readable

Read these from the selected worktree, because nothing loaded them for you. Skip the ones that do not exist:

```text
CLAUDE.md   AGENTS.md   CONTEXT.md   README.md
docs/agents/*
.claude/settings.json
.claude/skills/*/SKILL.md
.claude/agents/*
```

Follow them as project instructions for the rest of the task.

### Detect what cannot be loaded

These take effect only at agent startup and cannot be loaded mid-session: MCP servers from `.mcp.json`, hooks, permission rules, `enabledPlugins`, and `enabledMcpjsonServers` from `.claude/settings.json`.

To check the MCP servers, read the worktree's `.mcp.json` and compare each server name against the tools actually available to you. A server named `kaneo` is loaded only if `mcp__kaneo__*` tools exist. If the file names a server and no such tool exists, it is **not loaded** — no tool call will make it appear.

### Repair it

Run from the checkout root, then restart the agent there:

```bash
wtree link <worktree-dir>
```

This links `.mcp.json`, `CLAUDE.md`, `AGENTS.md`, `.claude/` and `.opencode/` from that worktree into the checkout root, so the next agent started at the root loads them. It links only files that exist and never replaces an existing regular file. Restarting the agent directly inside the worktree works too.

### Report, then continue

State plainly which configuration is missing and give the exact command above. Then keep working on everything that does not depend on it. Stop only when the task genuinely needs the unloaded configuration — never guess at data that lives behind an MCP server you cannot reach, and never present a recollection of it as a current reading.

## Select Or Create Feature Worktrees

When work belongs on an existing branch, locate its registered worktree and work there. Do not create a duplicate worktree for the same branch.

For a new feature, use this process:

1. Inspect project-local agent instructions and any applicable branch-creation guidance before choosing a name.
2. Inspect existing local and remote branches to identify the repository convention:

```bash
git -C <checkout>/.bare branch --all --no-color
git -C <checkout>/.bare log --all --format='%D' -30
```

3. If instructions or established branches define a convention, follow it — a ticket convention (`BSV-1/export-csv`) and a type prefix convention (`feat/export-csv`) both survive the mapping to a directory unchanged. Otherwise derive a short, sanitized descriptive proposal from the requested feature, such as `feat/export-csv`. When a ticket identifier is known, lead with it.
4. Propose both the branch name and the sibling worktree directory to the user. **The directory is the branch name unchanged**: `feat/export-csv` lives in `<checkout>/feat/export-csv/`, and the ticket branch `BSV-1/export-csv` lives in `<checkout>/BSV-1/export-csv/`. Never flatten `/` to `-`, and do not shorten the branch to its basename — that collides as soon as two tickets share a trailing word. The intermediate directory (`feat/`, `BSV-1/`) is created as needed and holds no worktree of its own. Wait for the user's confirmation before creating a new worktree.
5. Fetch the selected remote, resolve its default branch, and create the confirmed branch from that remote-tracking ref. Use the checkout's configured remote name (`origin` unless the clone used another name):

```bash
git -C <checkout>/.bare fetch --prune <remote>
git -C <checkout>/.bare symbolic-ref --quiet --short refs/remotes/<remote>/HEAD
git -C <checkout>/.bare worktree add -b <branch> <checkout>/<worktree-dir> <remote-head>
```

If the intended base branch, remote, branch name, or directory conflicts with existing state, explain the conflict and ask the user instead of guessing. Do not use an arbitrary local branch as a fallback base.

## Work In The Selected Worktree

After selecting or creating a worktree, run normal development and Git commands from that worktree:

```bash
git -C <checkout>/<worktree-dir> status --short
git -C <checkout>/<worktree-dir> fetch --prune <remote>
git -C <checkout>/<worktree-dir> pull --ff-only
git -C <checkout>/<worktree-dir> push -u <remote> <branch>
```

- Check `status` before operations that change history or update files.
- Pull only a clean worktree with an established upstream. A newly created feature branch has no upstream until its first `push -u`.
- Fetching and inspecting worktrees may use the shared bare repository; source edits, commits, merges, rebases, pulls, and pushes belong to the selected worktree.
- Push the selected branch explicitly. Do not push another worktree's branch or force-push unless the user explicitly requests it.
- When a branch's work has landed, retire its worktree rather than reusing it — see **Retire A Completed Worktree**.

## Retire A Completed Worktree

A worktree exists to host one branch. Once that branch has landed on the branch it targeted, the
worktree has finished its purpose and is retired: the directory goes, the local branch goes, and the
checkout root's agent configuration is repointed. Do not switch a new branch into a finished
worktree — the layout stays readable only while each directory names the branch it holds.

Raise this only when the user asks to clean up or says the work on a branch is done. Do not scan for
landed branches during **Orient Before Working**, and never retire a worktree the user has not named
and confirmed.

Propose first. Run this from the checkout root or any other worktree, never from inside the one being
removed:

```bash
wtree remove --dry-run <worktree-dir>
```

It reports whether the branch has landed, whether the branch would be deleted, and which
agent-configuration links would move, and it changes nothing. Show the user that report, wait for
confirmation, then run the same command without `--dry-run`:

```bash
wtree remove <worktree-dir>
wtree remove --base <remote>/<branch> <worktree-dir>   # the work targeted another branch
wtree remove --keep-branch <worktree-dir>              # remove the directory, keep the branch
```

### Landed is decided by content

Squash and rebase merges rewrite the commits, so a landed branch's tip is usually **not** an ancestor
of its base. `git branch --merged` calls such a branch unmerged, which makes it the wrong test on its
own. `wtree remove` checks ancestry first and then compares the branch's squashed patch against the
base, so a squash-merged branch is recognized and its branch deleted. Report what the command
decided instead of forming a separate judgment.

The base defaults to the remote's default branch. When the repository integrates somewhere else — a
`dev` that later merges to `main` — pass `--base <remote>/dev`.

### Treat a refusal as information

`wtree remove` refuses rather than prompts. It refuses the worktree you are standing in, the one
holding the remote's default branch, the last one in the checkout, and any worktree with uncommitted
or untracked files or with commits that have not landed. Every refusal names what it found.

Report that to the user. `--force` is the flag that discards the work the refusal was protecting, so
pass it only when the user says to. Never delete the remote branch: `wtree remove` does not, and
`git push <remote> --delete <branch>` is the user's decision rather than a cleanup step.

Stashes are safe either way — they live in the shared repository, not in the worktree, and survive
its removal.

### Repoint the agent configuration

The checkout root's `.mcp.json`, `CLAUDE.md`, `AGENTS.md`, `.claude/` and `.opencode/` are links into
one worktree. When that is the worktree being removed, `wtree remove` repoints them at the remaining
worktree; when several remain and the choice is not obvious, it removes them and names the
candidates. Run the `wtree link <worktree-dir>` command it prints, then restart the agent, because
MCP servers, hooks and permissions load only at startup — see **Load Agent Configuration**.

## Clone

Run the explicit clone command from the parent directory where the checkout should be created:

```bash
wtree clone [--branch <name>] [--worktree-dir <path>] [--bare-dir <path>] [--remote <name>] <repo-url> [<directory>]
```

Without `<directory>`, it creates a child directory named after the repository URL (without a trailing `.git`); provide one to choose the checkout location. Without `--branch`, it uses the remote's default branch. If no default branch is available, it offers the fetched remote branches interactively; supply `--branch` when non-interactive execution is required. The initial worktree directory defaults to the branch name, so `dev/MAIN` creates `dev/MAIN/`; override it with `--worktree-dir` when the first worktree should sit at the checkout root, for example `--worktree-dir MAIN`. Never run `wtree clone` inside an existing repository or worktree.

## Manage Worktrees

Run Git worktree operations through the shared bare repository. Replace `<checkout>` with the directory that contains `.bare` and its sibling worktrees.

```bash
git -C <checkout>/.bare worktree list
git -C <checkout>/.bare worktree add -b <branch> <checkout>/<branch> <start-point>   # <branch> names both
git -C <checkout>/.bare worktree prune
```

Name a nested worktree by its full path in every command: `wtree link feat/export-csv`, `wtree remove feat/export-csv`. `wtree remove` also removes the parent directory (`feat/`) when the removal empties it.

Retire a finished worktree with `wtree remove` — see **Retire A Completed Worktree**. Reach for `git -C <checkout>/.bare worktree remove` only for what `wtree remove` deliberately refuses, such as emptying a checkout of its last worktree, and say why the refusal is being bypassed. Use normal Git commands from the selected worktree for status, commits, fetches, merges, and pushes.
