---
status: Not Started
created: "2026-05-09"
---

# Create smaqit MCP Server (PoC)

## Description

Create smaqit's first MCP (Model Context Protocol) server — a locally-deployed MCP that exposes one low-hanging-fruit smaqit capability as a tool, proving out the integration pattern and architecture. This is explicitly a PoC (Proof of Concept): pick the simplest useful capability, get it working end-to-end, and establish the file structure and build pipeline that future MCP tools can follow.

The MCP server lives under a new `mcp/` directory at the smaqit-extensions repo root. It is bundled into the Go installer binary (embedded via `//go:embed`) so it is distributed as part of `smaqit-extensions init`. The server is standard MCP (not a web-app MCP variant) and runs locally for GitHub Copilot Desktop.

**Reference skill for MCP implementation pattern:**
`https://github.com/anthropics/skills/tree/main/skills/mcp-builder` — read this skill as the canonical implementation guide. The skill is for standard MCP, not web-app MCP — follow it directly.

## Design Decisions (confirmed)

- **Scope (V1):** Single tool — expose task list (`PLANNING.md` reader). Low-hanging fruit, high utility, proves the pattern. No glossary, no research map in V1.
- **Workspace access:** MCP server reads the workspace directly — it receives the workspace path at startup and reads `.smaqit/tasks/PLANNING.md` directly from disk.
- **Distribution:** Bundled in the Go installer binary. The `mcp/` directory is embedded and deployed by `smaqit-extensions init` to the target project alongside agents and skills.
- **Target:** Local GitHub Copilot Desktop only. No remote agent support in V1.
- **Language/runtime:** Follow the `mcp-builder` skill's guidance on runtime choice. Likely Node.js/TypeScript (standard MCP SDK). If the skill recommends a different approach, follow it.
- **Standard MCP:** Use the standard MCP protocol (not the MCP Apps/web-app variant). The interactive dashboard concept from the original idea is deferred — V1 is a clean MCP tool invocable by Copilot.

## V1 Tool: `get-task-list`

**Tool name:** `get-task-list`

**Description (for MCP manifest):** "Returns the current task list from the smaqit project planning file. Reads `.smaqit/tasks/PLANNING.md` and returns structured task data."

**Input schema:**
```json
{
  "workspace_path": {
    "type": "string",
    "description": "Absolute path to the workspace root (where .smaqit/ lives)"
  }
}
```

**Output:** Structured JSON or markdown representation of the tasks table from `PLANNING.md`.

**Error handling:**
- If `PLANNING.md` does not exist at the given path: return informative error (not stack trace)
- If `workspace_path` is not provided: return error asking for workspace path

## Directory Structure

```
mcp/
├── README.md                    — setup instructions, how to configure in Copilot Desktop
├── package.json                 — Node.js project config
├── tsconfig.json                — TypeScript compiler config
├── src/
│   └── index.ts                 — MCP server entry point; tool registration; workspace reader
└── dist/                        — compiled output (generated, not committed)
```

If the mcp-builder skill prescribes a different structure, follow it exactly.

## Go Installer Integration

The `mcp/` directory (excluding `dist/`) must be embedded into the Go binary and deployed by `smaqit-extensions init`:

1. **Embedding:** Add `mcp/` to the `//go:embed` directives in `installer/main.go` alongside `agents/` and `skills/`
2. **Deployment:** `smaqit-extensions init` copies `mcp/src/`, `mcp/package.json`, `mcp/tsconfig.json`, `mcp/README.md` to the target project's `.github/mcp/` directory
3. **Build step:** Add a `mcp:build` target in `installer/Makefile` that compiles the TypeScript to `dist/` before the Go binary is built — so the dist output can optionally be embedded too
4. **Root Makefile:** Add `mcp:sync` or similar target analogous to `make sync`

**Important:** Compiled `dist/` output should either be embedded in the Go binary (if small enough) or documented as a post-install `npm install && npm run build` step in `mcp/README.md`.

## Copilot Desktop Configuration

The `mcp/README.md` must document exactly how to register the MCP server in GitHub Copilot Desktop:

```json
{
  "mcpServers": {
    "smaqit": {
      "command": "node",
      "args": [".github/mcp/dist/index.js"],
      "env": {
        "WORKSPACE_PATH": "${workspaceFolder}"
      }
    }
  }
}
```

Or the equivalent configuration format if the mcp-builder skill uses a different pattern.

## Implementation Steps

1. **Read the mcp-builder skill** at `https://github.com/anthropics/skills/tree/main/skills/mcp-builder` — follow it as the canonical guide. Understand its scaffolding pattern, file structure, tool registration, and testing approach.

2. **Scaffold `mcp/` directory** — create the file structure as prescribed by mcp-builder. Do not invent a structure; follow the reference.

3. **Implement `get-task-list` tool** in `mcp/src/index.ts`:
   - Accept `workspace_path` parameter
   - Read `{workspace_path}/.smaqit/tasks/PLANNING.md`
   - Parse the markdown task table(s) into structured output
   - Return the task list as tool result
   - Handle errors gracefully

4. **Write `mcp/README.md`** — setup instructions, Copilot Desktop configuration, how to build and run locally.

5. **Update `installer/main.go`** — add `mcp/` embed and deployment logic in `init` command.

6. **Update `installer/Makefile`** — add `mcp:build` target (npm install + tsc).

7. **Update root `Makefile`** — add any needed targets for mcp development.

8. **Test end-to-end** — build the MCP server locally, configure in Copilot Desktop (or test with MCP Inspector if available), verify `get-task-list` returns expected output for the smaqit-extensions project itself.

9. **Update `README.md`** — add MCP section documenting the server, its tools, and setup.

10. **Update `CHANGELOG.md`** — add entry for MCP server addition.

## Acceptance Criteria

- [ ] `mcp/` directory exists with structure prescribed by mcp-builder skill
- [ ] `mcp/src/index.ts` implements `get-task-list` tool with `workspace_path` input parameter
- [ ] `get-task-list` reads `.smaqit/tasks/PLANNING.md` from `workspace_path` and returns structured task data
- [ ] `get-task-list` returns informative error (not crash) when PLANNING.md is absent or workspace_path is invalid
- [ ] `mcp/package.json` is valid, includes correct MCP SDK dependency, has `build` script
- [ ] `mcp/README.md` documents setup, Copilot Desktop configuration, and local build steps
- [ ] `installer/main.go` updated to embed and deploy `mcp/` as part of `smaqit-extensions init`
- [ ] TypeScript compiles without errors
- [ ] MCP server starts without errors when run via `node dist/index.js`
- [ ] Tool is discoverable by an MCP client (Copilot Desktop or MCP Inspector)
- [ ] `README.md` updated with MCP section
- [ ] PLANNING.md updated to mark this task Completed

## Files to Create / Modify

| File | Action |
|------|--------|
| `mcp/README.md` | Create |
| `mcp/package.json` | Create |
| `mcp/tsconfig.json` | Create |
| `mcp/src/index.ts` | Create |
| `installer/main.go` | Modify — add mcp/ embed + deploy |
| `installer/Makefile` | Modify — add mcp:build target |
| `Makefile` | Modify — add mcp targets |
| `README.md` | Modify — add MCP section |
| `CHANGELOG.md` | Modify — add entry |
| `.smaqit/tasks/PLANNING.md` | Modify — mark completed |

## Notes

- This is a PoC. Resist scope creep — one tool only (get-task-list). The architecture established here is the template for future MCP tools.
- The mcp-builder skill is the authoritative implementation guide. If it conflicts with this task file, the skill takes precedence on technical implementation decisions.
- Security: the MCP server reads only from paths under the provided `workspace_path`. Do not implement any write operations or directory traversal. Input paths must be validated to stay within workspace_path.
- No authentication required for V1 — local only, Copilot Desktop provides the security boundary.
- If the Go embed approach for mcp/ is complex (due to compiled JS artifacts), an acceptable fallback is: document that users run `npm install && npm run build` after `smaqit-extensions init`, with the source files deployed but compilation deferred to the user.
