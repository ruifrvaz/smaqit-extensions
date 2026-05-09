# smaqit MCP Server

A local MCP (Model Context Protocol) server for GitHub Copilot Desktop that exposes smaqit task tracking data as structured tools.

## Tools

### `get_task_list`

Returns the current task list from the smaqit project planning file.

**Input:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `workspace_path` | `string` | Absolute path to the workspace root (where `.smaqit/` lives) |

**Output:** Structured task data (active tasks, completed tasks) parsed from `.smaqit/tasks/PLANNING.md`.

**Example invocation (via Copilot):**
> "What are the current tasks in my project?"  
> Copilot calls `get_task_list` with your workspace path and returns a formatted task list.

## Setup

### 1. Build the MCP server

```bash
cd .github/mcp
npm install
npm run build
```

### 2. Configure GitHub Copilot Desktop

Add the following to your Copilot Desktop MCP configuration (`.copilot/mcp.json` or the MCP settings in VS Code):

```json
{
  "mcpServers": {
    "smaqit": {
      "command": "node",
      "args": ["${workspaceFolder}/.github/mcp/dist/index.js"],
      "env": {}
    }
  }
}
```

> **Note:** The `workspace_path` parameter is passed by Copilot at tool-call time — you don't need to hard-code it in the configuration.

### 3. Verify the server starts

```bash
node .github/mcp/dist/index.js
```

The server uses stdio transport and will wait for MCP client connections. Press `Ctrl+C` to exit.

### 4. Test with MCP Inspector (optional)

```bash
npx @modelcontextprotocol/inspector node .github/mcp/dist/index.js
```

Then call `get_task_list` with your project's workspace path.

## Local Development

```bash
# Install dependencies
npm install

# Watch mode (recompiles on change)
npm run dev

# Build once
npm run build

# Run directly
node dist/index.js
```

## Requirements

- Node.js >= 18
- A smaqit project with `.smaqit/tasks/PLANNING.md`

## Security

- The server only reads files from paths under the provided `workspace_path`.
- No write operations are performed.
- No network access is required — this is a fully local server.
- Path traversal is rejected: resolved paths outside `workspace_path` return an error.
