# Config Schema — brain-config.json

This is the JSON contract that `onboard.sh --config` expects. The skill writes this file, then the bash script reads it via `python3` to populate all vault templates.

## Full Schema

```json
{
  "user": {
    "name": "string (REQUIRED)",
    "timezone": "string (default: America/New_York)",
    "location": "string (optional)",
    "hours": "string (default: 9am–6pm weekdays)",
    "role": "string (optional)",
    "stack": "string (optional)",
    "comms": "string (default: Direct and concise, no fluff)",
    "always_know": "string (optional)",
    "roles": ["array of strings (optional)"]
  },
  "agent": {
    "name": "string (default: Sage)",
    "emoji": "string (default: 🧠)",
    "personality": "string (default: Direct and sharp, no fluff, honest about uncertainty)",
    "tone": "string (default: Casual, like a smart friend who happens to be an expert)",
    "never": "string (default: Never flatter. Never add commitments without asking. Never be vague.)"
  },
  "system": {
    "year_themes": "string (optional)",
    "year_misogi": "string (optional)",
    "work_principle": "string (default: Fewer things, done completely)"
  },
  "project": {
    "name": "string (optional — omit entire block if no project)",
    "what": "string (optional)",
    "done_when": "string (optional)"
  }
}
```

## Field Reference

### user (required block)

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| `name` | string | **Yes** | — | The only hard requirement. Used everywhere. |
| `timezone` | string | No | America/New_York | IANA timezone format (e.g., America/Costa_Rica, Europe/Berlin) |
| `location` | string | No | (empty) | City, country. Used in agent context. |
| `hours` | string | No | 9am–6pm weekdays | Working hours. Used for scheduling awareness. |
| `role` | string | No | (empty) | Job title or description. |
| `stack` | string | No | (empty) | Tools/tech they use. Comma-separated. |
| `comms` | string | No | Direct and concise, no fluff | How they like to receive information. |
| `always_know` | string | No | (empty) | Standing context for the agent. |
| `roles` | array | No | ["(fill in your roles)"] | Life roles. Each becomes a line in roles.md. |

### agent (optional block — all have defaults)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `name` | string | Sage | Agent's display name. |
| `emoji` | string | 🧠 | Shown next to agent name. |
| `personality` | string | Direct and sharp, no fluff, honest about uncertainty | Goes into SOUL.md personality section. |
| `tone` | string | Casual, like a smart friend who happens to be an expert | Goes into SOUL.md tone section. |
| `never` | string | Never flatter. Never add commitments without asking. Never be vague. | Agent constraints in SOUL.md. |

### system (optional block)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `year_themes` | string | (empty) | Comma-separated or sentence. Goes into yearly note. |
| `year_misogi` | string | (empty) | One transformational goal. Goes into yearly note. |
| `work_principle` | string | Fewer things, done completely | Core work principle. Goes into CoreSystem. |

### project (optional block — omit entirely if no project)

| Field | Type | Notes |
|-------|------|-------|
| `name` | string | Project display name. Used to create folder slug. |
| `what` | string | One-line description of the project. |
| `done_when` | string | Definition of done. |

## Example — Minimal (only required field)

```json
{
  "user": {
    "name": "Alex"
  }
}
```

Everything else gets defaults. This produces a working vault.

## Example — Full

```json
{
  "user": {
    "name": "María López",
    "timezone": "America/Costa_Rica",
    "location": "San José, Costa Rica",
    "hours": "8am–5pm weekdays",
    "role": "Freelance UX Designer",
    "stack": "Figma, Webflow, Notion",
    "comms": "Casual and visual, show me examples over long explanations",
    "always_know": "I have ADHD — keep things short and actionable. I work best in 25-minute sprints.",
    "roles": ["Designer", "Business Owner", "Mom", "Runner"]
  },
  "agent": {
    "name": "Luna",
    "emoji": "🌙",
    "personality": "Warm but no-nonsense. Keeps me on track without nagging. Uses humor when things get heavy.",
    "tone": "Casual, like a smart friend who also happens to be ridiculously organized",
    "never": "Never add tasks without asking. Never be vague about deadlines. Never lecture me about productivity."
  },
  "system": {
    "year_themes": "Simplify, ship more, sleep better",
    "year_misogi": "Launch my own product line by September",
    "work_principle": "One thing at a time, done well"
  },
  "project": {
    "name": "Portfolio Redesign",
    "what": "Rebuild my portfolio site in Webflow with case studies",
    "done_when": "Live site getting at least 2 client inquiries per month"
  }
}
```

## How the Bash Script Reads This

The `_json_val()` function in `onboard.sh` uses `python3` to read JSON values by dot-path:
- `_json_val "user.name"` → returns the name string
- `_json_val "user.roles"` → returns array items, one per line
- Missing/null values → returns empty string (defaults applied after)

The script sources these into bash variables (`USER_NAME`, `AGENT_NAME`, etc.) and uses `stamp_template()` to replace `{{PLACEHOLDER}}` tokens in template files.
