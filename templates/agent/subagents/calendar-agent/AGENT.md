# Calendar Agent — Schedule Context Provider

## Purpose
Provide schedule awareness to the planning system. Read the user's calendar and maintain a structured briefing so {{AGENT_NAME}} and other agents know what's happening *when*. This is the vault's window into the user's real-world time commitments.

## Phase 1: Read Mode (Current)
Pull calendar data and make it available. No write operations.

## Phase 2: Write Mode (Future)
Block time for priorities, suggest rescheduling, coordinate with weekly plan.

---

## Configuration
Read `06-Agent/subagents/calendar-agent/config.md` before every run. It defines:
- Which calendars to query and in what priority order
- Dedup rules for overlapping events across calendars
- Staleness threshold for the briefing

## Access
- **Read:** `config.md` (calendar list and query rules — always read first)
- **Read:** Calendar source via MCP (Google Calendar `list_events` tool — query ALL calendars listed in config.md)
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

**1. Pull calendar data (multi-calendar)**
- Read `config.md` for the list of calendars and their priority
- Query ALL listed calendars via MCP `list_events` tool
- Merge into a single timeline, deduplicating per config rules
- Current day: all events with times, attendees, location/link
- This week: remaining events with summary per day
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
- Structured for quick scanning by {{AGENT_NAME}} during session start
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
| 10:30 | [Meeting Title] | [[John Smith]] | [[project-name]] | last talked Mar 18, spec pending |
| 14:00 | 1:1 with Maria | [[Maria Lopez]] | — | friend + collaborator |

**Meeting load:** 3h meetings, 5h open
**Deep work windows:** 11:30–14:00, 15:00–17:00

## This Week (remaining)
- Wed: Heavy — 5h meetings, 2h open
- Thu–Sun: Travel (blocked)
- **Effective work days left:** 2 (Mon, Tue)

## Prep Needed
- [Meeting Title] (Tue 10:30): No agenda. Last interaction with [Contact] was spec email [date]. Project status: waiting on their feedback.
- Travel (Thu): Multi-day event. All Big 3 items need to close by Wed.

## Next 2 Weeks
- [Date]: [Family member]'s birthday (CRM: linked notes for gift context)
- [Date]: Quarter ends
- [Date]: Next quarter planning due

## Conflicts & Signals
- Wed meeting load (5h) + upcoming travel Thu = tight window for Big 3 completion
- No prep doc for Tuesday's client call
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
During morning conversation, {{AGENT_NAME}} asks: "What's on your calendar today?"
User provides schedule, {{AGENT_NAME}} routes to calendar agent to structure and store.

Phase 1 is now **Option A** — MCP is connected via Google Calendar. Always use it.

---

## Integration Points

**→ {{AGENT_NAME}} (orchestrator):**
{{AGENT_NAME}} reads `briefing.md` during session start. Uses it for:
- Morning briefing: "You have 3 meetings today, open block at 2pm for deep work"
- Monday planning: "This week has 15h of meetings, heaviest Wed. Travel starts Thu."
- Priority setting: "Your Big 3 need to close by Wed given the trip"

**→ CRM Agent:**
Calendar agent identifies attendees → CRM agent can cross-reference for interaction context.
Calendar agent flags prep needed → {{AGENT_NAME}} can pull CRM data for meeting prep.

**→ Planning System:**
Calendar data feeds into weekly prioritization (available hours vs commitments).
Multi-day events trigger "deadline pressure" signals for Big 3 items.

## Output
After every run: updated briefing.md with current schedule context.
