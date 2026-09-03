---
description: Run a wtree CLI command. Use as /wtree clone <repo-url> [directory] or /wtree remove <worktree-dir>.
---

Handle this request with the `wtree` CLI. The supported commands are:

```text
wtree clone [--branch <name>] [--worktree-dir <path>] [--bare-dir <path>] [--remote <name>] <repo-url> [<directory>]
wtree remove [--base <ref>] [--keep-branch] [--force] [--dry-run] <worktree-dir>
```

The request arguments are: `$ARGUMENTS`

Require `clone` or `remove` as the first argument. Reject any other first argument.

For `clone`, require a repository URL, accept one optional destination directory after it, and treat other arguments as options for `wtree clone`.

Run `wtree clone` from the parent directory. For a bare `/wtree clone <repo-url>` request, it creates a new directory in the current directory named after the repository URL (remove a trailing `.git`). A supplied destination directory determines the checkout location. Do not overwrite an existing directory.

After cloning, report the checkout directory, the initial worktree directory, and that the shared bare Git repository is `<checkout>/.bare`. Do not use `wtree clone` inside an existing repository.

A worktree directory is its branch name, path separators included: the branch `feat/export-csv` produces `<checkout>/feat/export-csv/`, not `feat-export-csv/`. Pass that whole path wherever a `<worktree-dir>` is expected.

For `remove`, require a worktree directory. Run `wtree remove --dry-run <worktree-dir>` first from the checkout root, show the user exactly what it reports, and wait for confirmation before running it again without `--dry-run`. Report a refusal with what it named rather than working around it; add `--force` only when the user says to, because it discards the work the refusal protects. See the **Retire A Completed Worktree** section of the wtree skill.
