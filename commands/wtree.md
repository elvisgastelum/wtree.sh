---
description: Clone a repository into a wtree-managed worktree layout. Use as /wtree clone <repo-url> [directory] [wtree options].
---

Handle this request with the `wtree` CLI. The supported command is:

```text
wtree clone [--branch <name>] [--worktree-dir <path>] [--bare-dir <path>] [--remote <name>] <repo-url> [<directory>]
```

The request arguments are: `$ARGUMENTS`

Require `clone` as the first argument and a repository URL. Accept one optional destination directory after the repository URL. Treat other arguments as options for `wtree clone`.

Run `wtree clone` from the parent directory. For a bare `/wtree clone <repo-url>` request, it creates a new directory in the current directory named after the repository URL (remove a trailing `.git`). A supplied destination directory determines the checkout location. Do not overwrite an existing directory.

After cloning, report the checkout directory, the initial worktree directory, and that the shared bare Git repository is `<checkout>/.bare`. Do not use `wtree clone` inside an existing repository.
