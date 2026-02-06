---
created: 2026-02-06T10:42
title: Add changelog workflow with dates
area: planning
files:
  - assets/src/Main.elm:1460-1481
  - CHANGELOG.md
---

## Problem

The changelog currently exists only in the app's about screen (Main.elm) with no dates on entries. There's no source-controlled CHANGELOG.md file, and no workflow to ensure changelogs are updated when significant features are added.

This makes it hard to:
1. Track when features were released
2. Keep changelog in sync between code and app
3. Remember to update changelog during development

## Solution

1. Create a CHANGELOG.md in repo root with dated entries
2. Update Main.elm to show dates with each version entry
3. Add to GSD workflow (or pre-commit/PR checklist) a reminder to update changelog when shipping significant features
4. Consider keeping changelog data in one place (e.g., JSON or Elm module) that feeds both the file and the UI
