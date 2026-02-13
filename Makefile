.PHONY: sync clean

# Sync source files to .github/ for dogfooding
sync:
	@echo "Syncing source files to .github/..."
	@mkdir -p .github/agents .github/prompts .github/skills
	@cp -f agents/*.md .github/agents/
	@cp -f prompts/*.md .github/prompts/
	@for skill in session-start session-finish session-assess session-title task-create task-list task-complete task-start test-start release-analysis release-approval release-prepare-files release-git-local release-git-pr; do \
		mkdir -p .github/skills/$$skill; \
		cp -f skills/$$skill/SKILL.md .github/skills/$$skill/; \
		if [ -d skills/$$skill/references ]; then \
			mkdir -p .github/skills/$$skill/references; \
			cp -fL skills/$$skill/references/* .github/skills/$$skill/references/ 2>/dev/null || true; \
		fi; \
	done
	@echo "✓ Sync complete"
	@echo ""
	@echo "Files synchronized:"
	@echo "  .github/agents/     - $(shell ls -1 .github/agents/*.md 2>/dev/null | wc -l) agents"
	@echo "  .github/prompts/    - $(shell ls -1 .github/prompts/*.md 2>/dev/null | wc -l) prompts"
	@echo "  .github/skills/     - $(shell ls -1d .github/skills/*/ 2>/dev/null | wc -l) skills"

clean:
	@echo "Cleaning .github/ dogfooding files..."
	@rm -rf .github/agents .github/prompts .github/skills
	@echo "✓ Clean complete"
