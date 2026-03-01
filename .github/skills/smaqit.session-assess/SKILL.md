---
name: smaqit.session-assess
description: Critical assessment skill for handling ambiguous requirements, conflicting inputs, and insufficient detail in complex planning scenarios. Provides approval gate with iterative refinement to prevent wasted execution on poor-quality inputs. Invoke when user explicitly requests assessment using words "assess" or "assessment" or when requirements are ambiguous, conflicting, or underspecified.
metadata:
  version: "0.2.0"
---

# Session Assess

Perform critical assessment before taking action.

## Steps

1. **Question the premise**
   - Is this request necessary?
   - Does it duplicate existing work?
   - Could it create maintenance burden?
   - Are there hidden assumptions in the framing?

2. **Check existing state**
   - Read relevant files FIRST to understand what already exists
   - Search for similar patterns or implementations
   - Verify the problem actually exists as described
   - Don't guess at current state—empirically verify

3. **Identify trade-offs**
   - What are the downsides of this approach?
   - What alternatives exist?
   - Which option is better and why?
   - What costs (tokens, complexity, maintenance) are involved?

4. **Flag problems upfront**
   - If you see flaws, state them clearly BEFORE proceeding
   - Surface redundancy or conflicts with existing patterns
   - Identify better approaches if they exist
   - Question whether simpler solutions would suffice

5. **Present assessment and ask for direction**
   - Summarize findings with clear rationale
   - Present alternatives with cost-benefit analysis
   - Request confirmation before proceeding
   - Don't assume user's framing is complete/correct

## Scope

Apply this assessment to:
- Simple refactorings (check if they duplicate existing patterns)
- Documentation updates (verify target location and existing content)
- New features (question whether they're needed or if existing solutions suffice)
- "Clean up X" requests (ask "relative to what? what's the duplication source?")
- Configuration changes (verify they don't break conventions or stability)

## Critical Failures to Avoid

- Immediately executing without checking existing files
- Assuming user's framing is complete/correct
- Creating new content before verifying it doesn't already exist
- Treating normal-seeming requests as safe without analysis

## Stop and Explain Risks

Before implementing anything that:
- Modifies user configuration files (dotfiles, shell configs)
- Violates security best practices
- Breaks established conventions without clear justification
- Could affect system stability or user experience negatively
- Duplicates existing functionality in another location
