.PHONY: sync clean plugin\:validate

# Sync source files to .github/ for dogfooding
sync:
	@echo "Syncing source files to .github/..."
	@mkdir -p .github/agents .github/skills
	@cp -f agents/*.md .github/agents/
	@for skill in smaqit.session-start smaqit.session-finish smaqit.session-assess smaqit.session-title smaqit.session-recap smaqit.task-create smaqit.task-list smaqit.task-complete smaqit.task-start smaqit.test-start smaqit.project-init smaqit.project-glossary smaqit.release-analysis smaqit.release-approval smaqit.release-prepare-files smaqit.release-git-local smaqit.release-git-pr smaqit.utils.read-pdf smaqit.utils.triage-issues smaqit.project-research; do \
		mkdir -p .github/skills/$$skill; \
		cp -f skills/$$skill/SKILL.md .github/skills/$$skill/; \
		if [ -d skills/$$skill/references ]; then \
			mkdir -p .github/skills/$$skill/references; \
			cp -fL skills/$$skill/references/* .github/skills/$$skill/references/ 2>/dev/null || true; \
		fi; \
		if [ -d skills/$$skill/scripts ]; then \
			mkdir -p .github/skills/$$skill/scripts; \
			cp -f skills/$$skill/scripts/* .github/skills/$$skill/scripts/ 2>/dev/null || true; \
		fi; \
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

plugin\:validate:
	@echo "Validating plugin.json version against CHANGELOG..."
	@PLUGIN_VERSION=$$(grep '"version"' plugin.json | head -1 | sed 's/.*"version": "\([^"]*\)".*/\1/'); \
	CHANGELOG_VERSION=$$(grep -m1 '## \[[0-9]' CHANGELOG.md | sed 's/## \[\([0-9.]*\)\].*/\1/'); \
	if [ "$$PLUGIN_VERSION" = "$$CHANGELOG_VERSION" ]; then \
		echo "✓ plugin.json version ($$PLUGIN_VERSION) matches CHANGELOG ($$CHANGELOG_VERSION)"; \
	else \
		echo "✗ Version mismatch: plugin.json=$$PLUGIN_VERSION, CHANGELOG=$$CHANGELOG_VERSION"; \
		exit 1; \
	fi
