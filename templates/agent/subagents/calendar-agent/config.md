# Calendar Agent — Configuration

## Calendars (query in order)

List every calendar the agent should include in the daily briefing, in priority order. Priority is used to break ties when the same event appears on multiple calendars (higher priority wins during deduplication).

| Priority | Calendar ID | Label | Type | Notes |
|----------|------------|-------|------|-------|
| 1 | `user@work.example` | [Label — e.g. "Work — primary"] | Work | [Main calendar] |
| 2 | `user@personal.example` | [Label — e.g. "Personal"] | Personal | [Personal events] |
| 3 | `family@group.calendar.google.com` | [Label — e.g. "Family"] | Family | [Family logistics] |
| 4 | `blocks@group.calendar.google.com` | [Label — e.g. "Time blocks"] | Blocks | [Deep work / focus blocks] |

> Remove rows that don't apply. Keep at least one.

## Ignored Calendars

Calendars that exist on the account but should NOT be surfaced in briefings (noise, app-specific calendars, public holidays unless relevant, etc.).

| Calendar ID | Label | Reason |
|------------|-------|--------|
| `holidays@group.v.calendar.google.com` | [e.g. Country holidays] | Noise — only surface if relevant to planning |

## Query Rules

- **Always query all priority 1-N calendars** — merge results into a single timeline
- **Deduplicate** — if the same event appears on multiple calendars (e.g., synced between work and personal), keep the one from the higher-priority calendar
- **Timezone** — always query with `{{USER_TIMEZONE}}` (e.g., `America/New_York`)
- **Today's events** — full detail (time, attendees, description, conference link)
- **This week (remaining)** — summary per day (event count, meeting hours, key events)
- **Next 2 weeks** — only significant events (multi-day, external, deadlines, birthdays)

## Staleness

- Calendar briefing is considered stale after **6 hours** (half a workday)
- On session start, if briefing is stale → refresh via MCP before the morning greeting
