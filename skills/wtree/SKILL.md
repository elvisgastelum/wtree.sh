---
name: wtree
description: Use when `/wtree` is invoked or when the current checkout has an ancestor containing a `.bare` directory, indicating a wtree-managed Git worktree repository.
---

# wtree

`wtree` bootstraps a repository layout with a shared bare Git repository and one or more sibling worktrees:

```text
checkout/
  .bare/       # shared bare Git repository
  main/        # initial worktree
  feature-x/   # additional worktree
```

## Detect A wtree Checkout

Starting in the current directory, inspect each ancestor for `.bare`. Treat the checkout as wtree-managed only when this verifies it is bare:

```bash
git -C <checkout>/.bare rev-parse --is-bare-repository
```

The result must be `true`. Do not infer the layout only from a worktree's `.git` file.

## Clone

Use the explicit clone command only from an empty target directory:

```bash
wtree clone [--branch <name>] [--bare-dir <path>] [--remote <name>] <repo-url>
```

Without `--branch`, it interactively offers `main`, `master`, or `dev`. Supply `--branch` when non-interactive execution is required. Never run `wtree clone` inside an existing repository or worktree.

## Manage Worktrees

Run Git worktree operations through the shared bare repository. Replace `<checkout>` with the directory that contains `.bare` and its sibling worktrees.

```bash
git -C <checkout>/.bare worktree list
git -C <checkout>/.bare worktree add -b <branch> <checkout>/<branch> <start-point>
git -C <checkout>/.bare worktree remove <checkout>/<branch>
git -C <checkout>/.bare worktree prune
```

Before removing a worktree, ensure it has no work that must be kept. Use normal Git commands from the selected worktree for status, commits, fetches, merges, and pushes.
