---
created: 2026-02-05T23:47
title: Set up pre-commit hook to block pushes to main
area: tooling
files: []
---

## Problem

Currently there's no protection against pushing directly to main branch. To establish better development habits with pull requests and code review, we need a local safeguard that prevents accidental pushes to main.

## Solution

Set up a git pre-push hook that:
1. Checks if the target branch is `main` (or `master`)
2. Blocks the push with a helpful error message
3. Suggests creating a feature branch and PR instead

Could use `.git/hooks/pre-push` script or a tool like Husky for cross-platform support.
