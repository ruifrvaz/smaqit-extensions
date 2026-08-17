# Task Planning

Central task tracking and planning for smaqit-extensions.

## Active Tasks

| ID | Title | Status | Created |
|----|-------|--------|---------|
| 034 | Preserve Foreign Content When Regenerating the `.code-workspace` File | In Progress | 2026-08-18 |
| 028 | Benchmark Glossary Skill Invocation | Not Started | 2026-08-14 |
| 002 | Fix Changelog Extraction for Cumulative Releases | Not Started | 2026-02-13 |
| 007 | Create smaqit MCP Server (PoC) | Not Started | 2026-05-09 |
| 010 | Publish smaqit-extensions as Copilot Marketplace Plugin | Not Started | 2026-05-09 |

## Completed Tasks

| ID | Title | Status | Created | Completed |
|----|-------|--------|---------|-----------|
| 033 | Fix `update` Writing Project-Scoped Agent/Skill Mirrors Despite Documenting Itself as Global-Only | Completed | 2026-08-15 | 2026-08-17 |
| 031 | Fix Release-Analysis Boundary Detection for PR-Gated Releases | Completed | 2026-08-15 | 2026-08-17 |
| 032 | Reject Legacy Task Files and Signal the Breaking Change as v2.0.0 | Completed | 2026-08-15 | 2026-08-15 |
| 030 | Task File YAML Frontmatter Migration | Completed | 2026-08-15 | 2026-08-15 |
| 029 | Relax Session-Finish Push Confirmation Gate | Completed | 2026-08-14 | 2026-08-15 |
| 027 | PR-Gated Task Completion & Per-Task Releases | Completed | 2026-08-14 | 2026-08-14 |
| 025 | Reduce Triage Issue Payloads | Completed | 2026-08-13 | 2026-08-14 |
| 001 | Fix Post-Merge Tag Workflow Trigger Issue | Completed | 2026-02-13 | 2026-02-13 |
| 003 | Create smaqit.read-pdf Skill | Completed | 2026-05-02 | 2026-05-02 |
| 004 | Create smaqit.project-glossary Skill | Completed | 2026-05-02 | 2026-05-02 |
| 005 | Create smaqit.compendium Skill | Completed | 2026-05-09 | 2026-05-09 |
| 006 | Create smaqit.project-recap Skill | Completed | 2026-05-09 | 2026-05-09 |
| 008 | Refine smaqit.project-research Skill | Completed | 2026-05-09 | 2026-05-09 |
| 009 | Add smaqit-extensions update Self-Update Command | Completed | 2026-05-09 | 2026-05-09 |
| 011 | Add Findings Section to Task Workflow | Completed | 2026-05-09 | 2026-05-09 |
| 012 | Add Claude Code Support (Dual-Target Install) | Completed | 2026-07-16 | 2026-07-16 |
| 013 | Platform-Aware Agent Frontmatter and Skill Content | Completed | 2026-07-16 | 2026-07-16 |
| 014 | Generic Tool Language for Memory, Transcript, and Question-Asking Steps | Completed | 2026-07-16 | 2026-07-16 |
| 015 | Synchronize Project Instructions in Project Init | Completed | 2026-07-22 | 2026-07-23 |
| 016 | Add In-Progress Task Gate to Session Finish | Completed | 2026-07-23 | 2026-07-23 |
| 018 | Converge Worktree-Aware Task Lifecycle | Completed | 2026-07-26 | 2026-07-26 |
| 019 | Repair Worktree Visibility and Sparse Checkout | Completed | 2026-07-27 | 2026-07-29 |
| 020 | Add Parent-Owned Subtask Worktree Lifecycle | Completed | 2026-07-29 | 2026-07-29 |
| 021 | Ship Release Automation Workflow Bootstrap for Consumer Projects | Completed | 2026-07-31 | 2026-07-31 |
| 022 | Isolate Task State to Main Worktree | Completed | 2026-08-06 | 2026-08-06 |
| 017 | Repair Skill Contract and Scope Inconsistencies | Completed | 2026-07-24 | 2026-08-06 |
| 023 | Global User-Level Installation with Agent-Specific Adapters | Completed | 2026-08-10 | 2026-08-10 |
| 024 | Fix Worktree Script Repo-Root Resolution for Global Install | Completed | 2026-08-11 | 2026-08-11 |
| 026 | Session-Finish Main Branch Finalization | Completed | 2026-08-14 | 2026-08-14 |

## Notes

Tasks are stored in individual files: `.smaqit/tasks/NNN_task_title.md`

Status values: `Not Started`, `In Progress`, `PR Open` (owner tasks only — implementation committed, release PR awaiting or undergoing review; the task file's `pr: NNN` frontmatter key names it), `Completed`, `Abandoned`, `Blocked`. See `smaqit.task-complete`'s `references/RULES.md` for the full status lifecycle and phase model.

Task file header fields (`status`, `mode`, `parent`, `pr`, `created`, `started`, `completed`) are stored as YAML frontmatter, not bold-markdown lines. `## Issue Triage Context`'s own `Mode: Auto | Skip` field is unrelated and stays bold-markdown, unchanged.
