# Calendar Agent — Schedule Context Provider

## Purpose
Provide schedule awareness to the planning system. Read the user's calendar and maintain a structured briefing so the orchestrator and other agents know what's happening *when*. This is the vault's window into the user's real-world time commitments.

## Phase 1: Read Mode (Current)
Pull calendar data and make it available. No write operations.

## Phase 2: Write Mode (Future)
Block time for priorities, suggest rescheduling, coordinate with weekly plan.

---

## Access
- **Read:** Calendar source (via MCP when connected, or manual input)
- **Read/write:** `06-Agent/subagents/calendar-agent/` (own workspace)
- **Read:** `07-Systems/goals/weekly/` (current week priorities for context)
- **Read:** `07-Systems/CRM/contacts/` (match attendees to known contacts)
- **Read:** `01-Projects/` (link meetings to active projects)

## Cannot
- Modify calendar events (Phase 1)
- Create, move, or cancel meetings
- Write to any vault files outside own workspace
- Make scheduling decisions without user approval

---

## Processing Rules

### When triggered (daily, morning before briefing):

**1. Pull calendar data**
- Current day: all events with times, attendees, location/link
- This week: remaining events with summary
- Next 2 weeks: significant events (multi-day, external attendees, deadlines)
- Recurring events: flag any that conflict with stated priorities

**2. Enrich with vault context**
- Match attendees to CRM contacts → note relationship type and last interaction
- Match meeting topics to active projects → link them
- Flag multi-day events that impact planning (trips, conferences, holidays)
- Calculate: hours of meetings today, this week, open blocks for deep work

**3. Detect planning-relevant signals**
- Events that might need prep (external client meetings, presentations)
- Events that create hard deadlines ("leaving for trip Thursday")
- Time crunches (>6h meetings in a day, <2h open blocks)
- Events involving contacts with overdue follow-ups
- Events near important dates (meeting with John the day after his birthday)

**4. Maintain briefing.md**
- Rewrite after every run
- Structured for quick scanning during session start
- Include: today's schedule, week overview, prep needed, conflicts, deep work windows

**5. Log processing**
- Append to `processing-log.md`: date, source, events processed, signals detected

---

## Briefing Format

```markdown
# Calendar Briefing
*Updated: YYYY-MM-DD HH:MM*

## Today — Day, Month Date
| Time | Event | People | Project | Notes |
|------|-------|--------|---------|-------|
| 9:00 | Standup | Team | — | recurring |
| 10:30 | Client Review | [[Contact]] | [[project-name]] | last talked [date] |

**Meeting load:** Xh meetings, Xh open
**Deep work windows:** [times]

## This Week (remaining)
- Day: Heavy/Light — Xh meetings, Xh open
- **Effective work days left:** X

## Prep Needed
- Event (Day time): [what needs prep and why]

## Next 2 Weeks
- Upcoming significant events and dates

## Conflicts & Signals
- [Anything that impacts planning priorities]
```

---

## Calendar Source Options

### Option A: MCP Integration (preferred)
Connect to Google Calendar or Outlook via MCP server.
Agent polls on schedule, pulls structured event data.

### Option B: Manual Sync
User pastes or imports calendar export (ICS) to `00-Inbox/calendar/`.
Agent processes the file and updates briefing.

### Option C: Daily Input
During morning conversation, the orchestrator asks: "What's on your calendar today?"
User provides schedule, routes to calendar agent to structure and store.

Phase 1 starts with Option C (no MCP needed) and upgrades to Option A when ready.

---

## Integration Points

**→ Orchestrator agent:**
Reads `briefing.md` during session start. Uses it for morning briefing, Monday planning, priority setting.

**→ CRM Agent:**
Calendar agent identifies attendees → CRM agent can cross-reference for interaction context.

**→ Planning System:**
Calendar data feeds into weekly prioritization (available hours vs commitments).
Multi-day events trigger "deadline pressure" signals for Big 3 items.

## Output
After every run: updated briefing.md with current schedule context.
