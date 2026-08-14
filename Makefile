.PHONY: sync clean test smoke-test test-worktree-layout test-parent-task-lifecycle test-project-research-verify-urls

SKILLS := smaqit.session-start smaqit.project-diagnose smaqit.session-finish smaqit.session-assess smaqit.session-title smaqit.session-recap smaqit.task-create smaqit.task-list smaqit.task-complete smaqit.task-plan smaqit.task-refresh smaqit.task-start smaqit.test-create smaqit.test-complete smaqit.test-start smaqit.project-init smaqit.project-glossary smaqit.release-analysis smaqit.release-approval smaqit.release-prepare-files smaqit.release-git-local smaqit.release-git-pr smaqit.utils.read-pdf smaqit.utils.triage-issues smaqit.utils.worktree smaqit.project-research smaqit.project-recap smaqit.project-compendium smaqit.parity-assess

# Generate the ephemeral embed staging trees used by the Go binary.
# Agents and skills are now installed globally (not committed to this repo) —
# this target only regenerates installer/ staging for the next build.
sync:
	@echo "Regenerating installer embed staging..."
	@python3 scripts/generate-targets.py
	@echo "✓ Sync complete"

clean:
	@echo "Cleaning installer staging artifacts..."
	@rm -rf installer/skills/ installer/skills-claude/
	@rm -rf installer/agents-copilot/ installer/agents-claude/ installer/agents-codex/
	@rm -rf installer/commands-claude/ installer/templates/ installer/dist/
	@echo "✓ Clean complete"

test-worktree-layout:
	@bash tests/skills/test-worktree-layout.sh

test-parent-task-lifecycle:
	@bash tests/skills/test-parent-task-lifecycle.sh

test-project-research-verify-urls:
	@bash tests/skills/test-project-research-verify-urls.sh

test: test-worktree-layout test-parent-task-lifecycle test-project-research-verify-urls

smoke-test: test
	@$(MAKE) -C installer smoke-test
