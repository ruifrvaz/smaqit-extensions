# Claude Code Instructions

- Do not add the "🤖 Generated with [Claude Code](https://claude.com/claude-code)" footer (or any equivalent AI-authorship disclaimer) to pull request descriptions created for this repository.
- If a `git push` or `gh` operation fails with a 403/permission-denied error that looks like a PAT (personal access token) problem, do not attempt to diagnose or resolve it — the cause is simply that the user has locally switched their PAT to a different one. Immediately hard-stop and ask the user to fix/restore the PAT, then wait for them to confirm before retrying. Do not investigate credential helpers, token scopes, `gh auth status`, or try alternate remotes/protocols.
