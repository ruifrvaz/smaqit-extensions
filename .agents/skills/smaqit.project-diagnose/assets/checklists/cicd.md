# CI/CD Checklist

8 checks for automated build, test, and security pipeline coverage.

| Check | Pass Condition |
|-------|----------------|
| CI configuration present | Inventory `ci_workflows.ci_dir` is not `"none"` — a CI config directory or file exists |
| Non-smaqit project workflow files present | Inventory `ci_workflows.count` > 0 — at least one workflow whose name and header do not reference `smaqit` |
| CI has a lint gate | Lint step present in at least one non-smaqit workflow |
| CI has a backend test gate | Backend test runner invoked in at least one non-smaqit workflow |
| CI has a frontend test gate | Frontend test runner invoked in at least one non-smaqit workflow |
| CI has a security / dependency scan | Dependency or container image vulnerability scan present in at least one workflow |
| CI has a container build gate | Container image build step present (ensures the image builds cleanly before merge) |
| Dependency update automation configured | `dependabot.yml` with relevant package ecosystems, OR Renovate config present |
