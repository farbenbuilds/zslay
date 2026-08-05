---
name: github-git
description: Rules for Git and GitHub workflows before pushing code.
---

# GitHub Git Workflow Rules

When pushing code to GitHub for this project, you must follow these rules:

1. **Commit Messages:** Follow conventional commits format (e.g., `feat:`, `fix:`, `chore:`, `refactor:`). Keep the message concise and clear.
2. **Pre-push checks:** Ensure that the code compiles (`zig build`) and tests pass (`zig build test`) before pushing.
3. **No emojis:** Do not use emojis in commit messages or branch names.
4. **Branch naming:** Use standard naming conventions (e.g., `feature/`, `bugfix/`).
5. **Clean History:** Avoid cluttering the git history. Rebase and squash if necessary before creating a pull request.
