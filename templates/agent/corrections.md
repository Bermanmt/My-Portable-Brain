# Corrections Log

The agent reads this file at the end of every session.
When a pattern reaches 3 occurrences, the agent surfaces it once — then waits for a response.

## Rules
1. Three of the same correction before suggesting anything
2. One suggestion per session maximum
3. Ask before changing anything — never act unilaterally
4. If declined, clear the entry and don't resurface for 30 days
5. User can ask "what are you tracking?" at any time — full transparency

---

## Active Observations

| Pattern | Count | Last Seen | Type |
|---------|-------|-----------|------|
| | | | |

*Agent writes here. Types: output-style · template · instruction · habit*

---

## Pending Suggestion

*When count ≥ 3, agent moves pattern here and surfaces it once at session end:*

```
Pattern:
Seen: N times, most recently YYYY-MM-DD
Suggestion:
Waiting since: YYYY-MM-DD
```

---

## Cleared

| Pattern | Outcome | Date |
|---------|---------|------|
| | | |

*Outcomes: accepted → [what changed] · declined · expired (30 days no response)*

---

## What Gets Tracked

**Output style** — how the agent writes things
> "My summaries are always too long. I keep shortening them."
> After 3× → "Want me to default to shorter summaries?"

**Templates** — fields you always add or remove
> "You keep removing the Done When field from project notes."
> After 3× → "Want me to remove it from the template?"

**Instructions** — preferences you keep reminding the agent of
> "You keep using bullet points. I prefer prose."
> After 3× → "Want me to update my writing instructions?"

**Habits** — parts of the system that have gone quiet
> Weekly Review unused for 6+ weeks.
> Once → "Still useful, or should we simplify it?"
