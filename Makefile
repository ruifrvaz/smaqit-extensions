.PHONY: sync clean

# Sync compiled source files to .github/ for dogfooding.
# Runs the same generator the installer uses (scripts/generate-targets.py) so
# .github/agents/ and .github/skills/ always match exactly what a real
# `smaqit-extensions init` produces for GitHub Copilot — including
# [SMAQIT_SKILLS_DIR] and {{PLACEHOLDER}} resolution. Do not raw-copy from
# agents/ or skills/ directly: agents/*.agent.md is body-only (frontmatter
# lives in .smaqit/definitions/agents/) and some skills carry unresolved
# {{PLACEHOLDER}} tokens until compiled.
sync:
	@echo "Syncing source files to .github/..."
	@python3 scripts/generate-targets.py
	@mkdir -p .github/agents .github/skills
	@cp -f installer/agents-copilot/*.agent.md .github/agents/
	@for skill in smaqit.session-start smaqit.project-diagnose smaqit.session-finish smaqit.session-assess smaqit.session-title smaqit.session-recap smaqit.task-create smaqit.task-list smaqit.task-complete smaqit.task-plan smaqit.task-refresh smaqit.task-start smaqit.test-create smaqit.test-complete smaqit.test-start smaqit.project-init smaqit.project-glossary smaqit.release-analysis smaqit.release-approval smaqit.release-prepare-files smaqit.release-git-local smaqit.release-git-pr smaqit.utils.read-pdf smaqit.utils.triage-issues smaqit.project-research smaqit.project-recap smaqit.project-compendium smaqit.parity-assess; do \
		rm -rf .github/skills/$$skill; \
		cp -rL installer/skills/$$skill .github/skills/$$skill; \
	done
	@echo "✓ Sync complete"
	@echo ""
	@echo "Files synchronized:"
	@echo "  .github/agents/     - $(shell ls -1 .github/agents/*.md 2>/dev/null | wc -l) agents"
	@echo "  .github/skills/     - $(shell ls -1d .github/skills/*/ 2>/dev/null | wc -l) skills"

clean:
	@echo "Cleaning .github/ dogfooding files..."
	@rm -rf .github/agents .github/skills
	@echo "✓ Clean complete"
