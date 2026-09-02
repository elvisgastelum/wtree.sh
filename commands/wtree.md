---
description: Clone a repository into a wtree-managed worktree layout. Use as /wtree clone <repo-url> [wtree options].
---

Handle this request with the `wtree` CLI. The supported command is:

```text
wtree clone [--branch <name>] [--bare-dir <path>] [--remote <name>] <repo-url>
```

The request arguments are: `$ARGUMENTS`

Require `clone` as the first argument and a repository URL as its final argument. Treat any other arguments as options for `wtree clone`.

Run `wtree clone` from an empty directory only. For a bare `/wtree clone <repo-url>` request, create a new directory in the current directory named after the repository URL (remove a trailing `.git`) and run the command there. Do not overwrite an existing directory. If the request includes a destination or is ambiguous, ask the user where to create the checkout.

After cloning, report the checkout directory, the initial worktree directory, and that the shared bare Git repository is `<checkout>/.bare`. Do not use `wtree clone` inside an existing repository.
