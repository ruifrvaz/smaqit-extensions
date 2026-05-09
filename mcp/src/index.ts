import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import * as fs from "node:fs";
import * as path from "node:path";
import { z } from "zod";

const SERVER_NAME = "smaqit-mcp-server";
const SERVER_VERSION = "1.0.0";

const server = new McpServer({
  name: SERVER_NAME,
  version: SERVER_VERSION,
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

interface Task {
  id: string;
  title: string;
  status: string;
  created?: string;
  completed?: string;
}

interface TaskList {
  active: Task[];
  completed: Task[];
  raw: string;
}

/**
 * Parse a markdown table row into an array of trimmed cell strings.
 * Skips separator rows (e.g. |---|---|).
 */
function parseTableRow(line: string): string[] | null {
  const trimmed = line.trim();
  if (!trimmed.startsWith("|") || !trimmed.endsWith("|")) return null;
  const cells = trimmed
    .slice(1, -1)
    .split("|")
    .map((c) => c.trim());
  // Skip separator rows (all cells contain only dashes/spaces)
  if (cells.every((c) => /^[-: ]+$/.test(c))) return null;
  return cells;
}

/**
 * Parse tasks from a PLANNING.md markdown table section.
 * Handles both Active and Completed table formats.
 */
function parseTasksFromSection(
  lines: string[],
  isCompleted: boolean
): Task[] {
  const tasks: Task[] = [];
  let headerParsed = false;
  let headers: string[] = [];

  for (const line of lines) {
    const cells = parseTableRow(line);
    if (!cells) continue;

    if (!headerParsed) {
      headers = cells.map((h) => h.toLowerCase());
      headerParsed = true;
      continue;
    }

    const idIdx = headers.findIndex((h) => h === "id");
    const titleIdx = headers.findIndex((h) => h === "title");
    const statusIdx = headers.findIndex((h) => h === "status");
    const createdIdx = headers.findIndex((h) => h === "created");
    const completedIdx = headers.findIndex(
      (h) => h === "completed" || h === "completed date"
    );

    const task: Task = {
      id: idIdx >= 0 && cells[idIdx] ? cells[idIdx] : "",
      title: titleIdx >= 0 && cells[titleIdx] ? cells[titleIdx] : "",
      status: statusIdx >= 0 && cells[statusIdx]
        ? cells[statusIdx]
        : isCompleted
        ? "Completed"
        : "Not Started",
    };

    if (createdIdx >= 0 && cells[createdIdx]) {
      task.created = cells[createdIdx];
    }
    if (completedIdx >= 0 && cells[completedIdx]) {
      task.completed = cells[completedIdx];
    }

    if (task.id) {
      tasks.push(task);
    }
  }

  return tasks;
}

/**
 * Read and parse PLANNING.md from the given workspace path.
 * Security: resolves and validates the path stays within workspace_path.
 */
function readPlanningFile(workspacePath: string): TaskList {
  // Resolve and validate the workspace path
  const resolvedWorkspace = path.resolve(workspacePath);
  const planningPath = path.resolve(
    resolvedWorkspace,
    ".smaqit",
    "tasks",
    "PLANNING.md"
  );

  // Security: ensure the resolved planning path is within the workspace
  if (!planningPath.startsWith(resolvedWorkspace + path.sep) &&
      planningPath !== resolvedWorkspace) {
    throw new Error(
      `Security error: resolved path "${planningPath}" is outside workspace "${resolvedWorkspace}"`
    );
  }

  if (!fs.existsSync(planningPath)) {
    throw new Error(
      `PLANNING.md not found at "${planningPath}". ` +
      `Ensure workspace_path points to a directory that contains a .smaqit/tasks/PLANNING.md file.`
    );
  }

  const content = fs.readFileSync(planningPath, "utf-8");
  const lines = content.split("\n");

  const activeTasks: Task[] = [];
  const completedTasks: Task[] = [];

  // Parse the file into sections
  let currentSection: "active" | "completed" | null = null;
  let sectionLines: string[] = [];

  for (const line of lines) {
    const lower = line.toLowerCase().trim();

    // Detect section headers
    if (lower.startsWith("## active") || lower === "## active tasks") {
      if (currentSection && sectionLines.length > 0) {
        if (currentSection === "completed") {
          completedTasks.push(...parseTasksFromSection(sectionLines, true));
        } else {
          activeTasks.push(...parseTasksFromSection(sectionLines, false));
        }
      }
      currentSection = "active";
      sectionLines = [];
      continue;
    }

    if (
      lower.startsWith("## completed") ||
      lower === "## completed tasks"
    ) {
      if (currentSection && sectionLines.length > 0) {
        if (currentSection === "completed") {
          completedTasks.push(...parseTasksFromSection(sectionLines, true));
        } else {
          activeTasks.push(...parseTasksFromSection(sectionLines, false));
        }
      }
      currentSection = "completed";
      sectionLines = [];
      continue;
    }

    // Stop collecting if we hit another top-level section (##)
    if (line.startsWith("## ") && currentSection) {
      if (sectionLines.length > 0) {
        if (currentSection === "completed") {
          completedTasks.push(...parseTasksFromSection(sectionLines, true));
        } else {
          activeTasks.push(...parseTasksFromSection(sectionLines, false));
        }
      }
      currentSection = null;
      sectionLines = [];
      continue;
    }

    if (currentSection) {
      sectionLines.push(line);
    }
  }

  // Flush the last section
  if (currentSection && sectionLines.length > 0) {
    if (currentSection === "completed") {
      completedTasks.push(...parseTasksFromSection(sectionLines, true));
    } else {
      activeTasks.push(...parseTasksFromSection(sectionLines, false));
    }
  }

  return {
    active: activeTasks,
    completed: completedTasks,
    raw: content,
  };
}

// ---------------------------------------------------------------------------
// Tool: get-task-list
// ---------------------------------------------------------------------------

server.registerTool(
  "get_task_list",
  {
    title: "Get Task List",
    description:
      "Returns the current task list from the smaqit project planning file. " +
      "Reads `.smaqit/tasks/PLANNING.md` from the given workspace path and returns " +
      "structured task data including active and completed tasks with their IDs, titles, " +
      "statuses, and dates.",
    inputSchema: {
      workspace_path: z
        .string()
        .min(1, "workspace_path must not be empty")
        .describe(
          "Absolute path to the workspace root (where .smaqit/ lives). " +
          "Example: /home/user/my-project"
        ),
    },
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false,
    },
  },
  async ({ workspace_path }) => {
    try {
      const taskList = readPlanningFile(workspace_path);

      const output = {
        workspace_path,
        active_tasks: taskList.active,
        completed_tasks: taskList.completed,
        summary: {
          total_active: taskList.active.length,
          total_completed: taskList.completed.length,
        },
      };

      // Build human-readable markdown
      const lines: string[] = [
        "# smaqit Task List",
        "",
        `**Workspace:** ${workspace_path}`,
        "",
      ];

      lines.push(
        `## Active Tasks (${taskList.active.length})`,
        ""
      );

      if (taskList.active.length === 0) {
        lines.push("_No active tasks._", "");
      } else {
        lines.push("| ID | Title | Status | Created |");
        lines.push("|----|-------|--------|---------|");
        for (const task of taskList.active) {
          lines.push(
            `| ${task.id} | ${task.title} | ${task.status} | ${task.created ?? ""} |`
          );
        }
        lines.push("");
      }

      lines.push(
        `## Completed Tasks (${taskList.completed.length})`,
        ""
      );

      if (taskList.completed.length === 0) {
        lines.push("_No completed tasks._", "");
      } else {
        lines.push("| ID | Title | Status | Created | Completed |");
        lines.push("|----|-------|--------|---------|-----------|");
        for (const task of taskList.completed) {
          lines.push(
            `| ${task.id} | ${task.title} | ${task.status} | ${task.created ?? ""} | ${task.completed ?? ""} |`
          );
        }
        lines.push("");
      }

      const textContent = lines.join("\n");

      return {
        content: [{ type: "text", text: textContent }],
        structuredContent: output,
      };
    } catch (error) {
      const message =
        error instanceof Error ? error.message : String(error);
      return {
        content: [
          {
            type: "text",
            text: `Error: ${message}`,
          },
        ],
        isError: true,
      };
    }
  }
);

// ---------------------------------------------------------------------------
// Start the server
// ---------------------------------------------------------------------------

async function main(): Promise<void> {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error) => {
  console.error("Fatal error starting smaqit MCP server:", error);
  process.exit(1);
});
