.PHONY: sync clean test smoke-test test-worktree-layout test-parent-task-lifecycle test-project-research-verify-urls

SKILLS := smaqit.session-start smaqit.project-diagnose smaqit.session-finish smaqit.session-assess smaqit.session-title smaqit.session-recap smaqit.task-create smaqit.task-list smaqit.task-complete smaqit.task-plan smaqit.task-refresh smaqit.task-start smaqit.test-create smaqit.test-complete smaqit.test-start smaqit.project-init smaqit.project-glossary smaqit.release-analysis smaqit.release-approval smaqit.release-prepare-files smaqit.release-git-local smaqit.release-git-pr smaqit.utils.read-pdf smaqit.utils.triage-issues smaqit.utils.worktree smaqit.project-research smaqit.project-recap smaqit.project-compendium smaqit.parity-assess

# Sync compiled source files to .github/, .codex/, .agents/, and .claude/ for
# dogfooding. Runs the same generator the installer uses
# (scripts/generate-targets.py) so workspace mirrors always match exactly what
# a real `smaqit-extensions init` produces for GitHub Copilot, Codex, and
# Claude Code — including [SMAQIT_SKILLS_DIR] and {{PLACEHOLDER}} resolution.
# Do not raw-copy from agents/ or skills/ directly: agents/*.agent.md is
# body-only (platform metadata lives in .smaqit/definitions/agents/) and some
# skills carry unresolved {{PLACEHOLDER}} tokens until compiled.
#
# All four mirrors (.github/, .codex/, .agents/, .claude/) must be covered
# here — this target is the only thing that keeps them from silently drifting
# from canonical source. A mirror this target doesn't touch will serve stale
# content indefinitely with no error, since nothing else compares them.
sync:
	@echo "Syncing source files for Copilot, Codex, and Claude Code dogfooding..."
	@python3 scripts/generate-targets.py
	@mkdir -p .github/agents .github/skills .codex/agents .agents/skills .claude/agents .claude/commands .claude/skills
	@cp -f installer/agents-copilot/*.agent.md .github/agents/
	@cp -f installer/agents-codex/*.toml .codex/agents/
	@cp -f installer/agents-claude/*.md .claude/agents/
	@cp -f installer/commands-claude/*.md .claude/commands/
	@for skill in $(SKILLS); do \
		rm -rf .github/skills/$$skill; \
		cp -rL installer/skills/$$skill .github/skills/$$skill; \
		rm -rf .agents/skills/$$skill; \
		cp -rL installer/skills/$$skill .agents/skills/$$skill; \
		rm -rf .claude/skills/$$skill; \
		cp -rL installer/skills-claude/$$skill .claude/skills/$$skill; \
	done
	@echo "✓ Sync complete"
	@echo ""
	@echo "Files synchronized:"
	@echo "  .github/agents/    - $$(find .github/agents -maxdepth 1 -type f -name '*.md' | wc -l) agents"
	@echo "  .github/skills/    - $$(find .github/skills -mindepth 1 -maxdepth 1 -type d | wc -l) skills"
	@echo "  .codex/agents/     - $$(find .codex/agents -maxdepth 1 -type f -name '*.toml' | wc -l) agents"
	@echo "  .agents/skills/    - $$(find .agents/skills -mindepth 1 -maxdepth 1 -type d | wc -l) skills"
	@echo "  .claude/agents/    - $$(find .claude/agents -maxdepth 1 -type f -name '*.md' | wc -l) agents"
	@echo "  .claude/commands/  - $$(find .claude/commands -maxdepth 1 -type f -name '*.md' | wc -l) commands"
	@echo "  .claude/skills/    - $$(find .claude/skills -mindepth 1 -maxdepth 1 -type d | wc -l) skills"

clean:
	@echo "Cleaning dogfooding files..."
	@rm -rf .github/agents .github/skills
	@rm -f .codex/agents/smaqit.release.local.toml .codex/agents/smaqit.release.pr.toml .codex/agents/smaqit.user-testing.toml
	@rm -f .claude/agents/smaqit.release.local.md .claude/agents/smaqit.release.pr.md .claude/agents/smaqit.user-testing.md
	@rm -f .claude/commands/smaqit.release.local.md .claude/commands/smaqit.release.pr.md .claude/commands/smaqit.user-testing.md
	@for skill in $(SKILLS); do rm -rf .agents/skills/$$skill; rm -rf .claude/skills/$$skill; done
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
