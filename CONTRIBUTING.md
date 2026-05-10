# Contributing to G10 MoMo SMS Analytics

## Branch Naming
- `feature/your-feature-name` — new functionality
- `fix/bug-description` — bug fixes
- `docs/what-you-updated` — documentation changes
- `chore/task-description` — tooling, config, or housekeeping

## Commit Messages
Use short, imperative-mood subjects (max ~72 chars):

```
Add SQLite schema for transactions table
Fix amount parsing for negative values
Update README with Scrum board link
```

If the change needs context, add a blank line and a body explaining the *why*.

## Workflow
1. Pull the latest `main` and create a branch from it.
2. Make your changes with clear, focused commits.
3. Push your branch and open a pull request against `main`.
4. Fill in the PR description: what changed, why, and how to test.
5. Get at least one teammate to review.
6. Merge only after approval. Prefer "Squash and merge" for small PRs.

## Pull Request Checklist
- [ ] Branch is up to date with `main`
- [ ] Commits follow the naming convention above
- [ ] No secrets, `.env` files, or large binaries committed
- [ ] Tests pass locally (`pytest backend/tests/`) when applicable
- [ ] README or docs updated if behavior changed

## Local Setup
See [README.md](README.md#getting-started) for clone, virtualenv, and run instructions.
Copy `.env.example` to `.env` before running the ETL.
