---
tags: [system, tasks]
updated: {{DATE}}
---

# Task Registry

The central index of all discrete, completable tasks.
Enables situational awareness — suggesting tasks based on where you are,
how much time you have, and your energy level.

## Active

<!-- Format: - [ ] Task description @context 📍place ⏱time 🔋energy 📋project 👤person 📅due -->
<!-- Contexts: @errands @home @office @digital @phone @deep-work @waiting -->
<!-- Energy:   🔋low 🔋medium 🔋high -->
<!-- Time:     ⏱15m ⏱30m ⏱1h ⏱2h ⏱half-day -->

- [ ] [Example task] @digital 🔋low ⏱30m 📋[project-name]
- [ ] [Example errand] @errands 📍[store-or-neighborhood] ⏱15m
- [ ] [Example meeting prep] @deep-work 🔋high ⏱1h 📋[project-name] 👤[Contact Name] 📅[YYYY-MM-DD]

## Waiting

<!-- Things waiting on someone else. Use [>] instead of [ ] and add 👤 + date sent -->

- [>] [Example: awaiting reply from vendor] @waiting 👤[Contact Name] 📅sent-[YYYY-MM-DD]

## Completed (last 30 days)

<!-- Keep last 30 days for context; older items rotate out automatically -->

- [x] ✅YYYY-MM-DD [Example completed task] 📋[project-name]

---

## How this works

- **Capture**: tasks added during conversations, meeting notes, inbox sweeps, or manually.
- **Context matters**: the `@context` + `📍place` + `⏱time` + `🔋energy` metadata is what makes the registry useful. A task without context is just a todo; a task with context can be suggested at the right moment.
- **Rotation**: completed items older than 30 days are pruned (manually or by cron).
- **Staleness**: during weekly review, flag anything that's sat in Active for 14+ days with no movement.

## Typical queries the agent should support

- "What can I do in 20 minutes at a low energy?" → filter `⏱<20m 🔋low`
- "I'm heading to [neighborhood], any errands on the way?" → filter `@errands 📍[neighborhood]`
- "What's waiting on [person]?" → filter `@waiting 👤[person]`
- "What's open in [project]?" → filter `📋[project-name]`
