import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { runJXA, getCalendarEventsScript, getRecentEmailsScript } from "./apple_helpers.js";

const server = new Server(
  {
    name: "portable-brain-apple-native",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "get_calendar_events",
        description: "Fetch upcoming events from macOS native Apple Calendar app. Automatically uses the user's localized time. Asks the OS for permission on first run. NEVER use this if the OS is not macOS.",
        inputSchema: {
          type: "object",
          properties: {
            days_ahead: {
              type: "number",
              description: "Number of days ahead to look for events (default: 3)",
            },
          },
        },
      },
      {
        name: "get_recent_emails",
        description: "Fetch recent emails from macOS native Apple Mail app inbox. Asks the OS for permission on first run. NEVER use this if the OS is not macOS.",
        inputSchema: {
          type: "object",
          properties: {
            limit: {
              type: "number",
              description: "Number of recent emails to fetch (default: 10, max: 50)",
            },
          },
        },
      },
    ],
  };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  switch (request.params.name) {
    case "get_calendar_events": {
      const days = Number((request.params.arguments as any)?.days_ahead || 3);
      try {
        const script = getCalendarEventsScript(days);
        const events = await runJXA(script);
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(events, null, 2),
            },
          ],
        };
      } catch (error: any) {
        return {
          content: [
            {
              type: "text",
              text: `Error fetching calendar events: ${error.message}`,
            },
          ],
          isError: true,
        };
      }
    }

    case "get_recent_emails": {
      const limit = Math.min(Number((request.params.arguments as any)?.limit || 10), 50);
      try {
        const script = getRecentEmailsScript(limit);
        const emails = await runJXA(script);
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(emails, null, 2),
            },
          ],
        };
      } catch (error: any) {
        return {
          content: [
            {
              type: "text",
              text: `Error fetching emails: ${error.message}`,
            },
          ],
          isError: true,
        };
      }
    }

    default:
      throw new Error("Unknown tool");
  }
});

async function run() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Portable Brain Apple Native MCP Server is running via stdio");
}

run().catch(console.error);
