.PHONY: sync clean smoke-test test-worktree-layout

SKILLS := smaqit.session-start smaqit.project-diagnose smaqit.session-finish smaqit.session-assess smaqit.session-title smaqit.session-recap smaqit.task-create smaqit.task-list smaqit.task-complete smaqit.task-plan smaqit.task-refresh smaqit.task-start smaqit.test-create smaqit.test-complete smaqit.test-start smaqit.project-init smaqit.project-glossary smaqit.release-analysis smaqit.release-approval smaqit.release-prepare-files smaqit.release-git-local smaqit.release-git-pr smaqit.utils.read-pdf smaqit.utils.triage-issues smaqit.utils.worktree smaqit.project-research smaqit.project-recap smaqit.project-compendium smaqit.parity-assess

# Sync compiled source files to .github/, .codex/, and .agents/ for dogfooding.
# Runs the same generator the installer uses (scripts/generate-targets.py) so
# workspace mirrors always match exactly what a real `smaqit-extensions init`
# produces for GitHub Copilot and Codex — including [SMAQIT_SKILLS_DIR] and
# {{PLACEHOLDER}} resolution. Do not raw-copy from agents/ or skills/ directly:
# agents/*.agent.md is body-only (platform metadata lives in
# .smaqit/definitions/agents/) and some skills carry unresolved
# {{PLACEHOLDER}} tokens until compiled.
sync:
	@echo "Syncing source files for Copilot and Codex dogfooding..."
	@python3 scripts/generate-targets.py
	@mkdir -p .github/agents .github/skills .codex/agents .agents/skills
	@cp -f installer/agents-copilot/*.agent.md .github/agents/
	@cp -f installer/agents-codex/*.toml .codex/agents/
	@for skill in $(SKILLS); do \
		rm -rf .github/skills/$$skill; \
		cp -rL installer/skills/$$skill .github/skills/$$skill; \
		rm -rf .agents/skills/$$skill; \
		cp -rL installer/skills-codex/$$skill .agents/skills/$$skill; \
	done
	@echo "✓ Sync complete"
	@echo ""
	@echo "Files synchronized:"
	@echo "  .github/agents/    - $$(find .github/agents -maxdepth 1 -type f -name '*.md' | wc -l) agents"
	@echo "  .github/skills/    - $$(find .github/skills -mindepth 1 -maxdepth 1 -type d | wc -l) skills"
	@echo "  .codex/agents/     - $$(find .codex/agents -maxdepth 1 -type f -name '*.toml' | wc -l) agents"
	@echo "  .agents/skills/    - $$(find .agents/skills -mindepth 1 -maxdepth 1 -type d | wc -l) skills"

clean:
	@echo "Cleaning dogfooding files..."
	@rm -rf .github/agents .github/skills
	@rm -f .codex/agents/smaqit.release.local.toml .codex/agents/smaqit.release.pr.toml .codex/agents/smaqit.user-testing.toml
	@for skill in $(SKILLS); do rm -rf .agents/skills/$$skill; done
	@echo "✓ Clean complete"

test-worktree-layout:
	@bash tests/skills/test-worktree-layout.sh

smoke-test: test-worktree-layout
	@$(MAKE) -C installer smoke-test
