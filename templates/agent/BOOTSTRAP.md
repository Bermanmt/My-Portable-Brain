# BOOTSTRAP.md — First Session Protocol

This file runs the agent's onboarding sequence across three sessions.
Each session has one job. After Session 3, delete this file — the vault is live.

Recreate this file at any time to restart the sequence.

---

## How to Use This File

The agent reads this on every session start until it's deleted.
At the top of each session, check which phase is active and run that protocol.
Mark phases complete by updating the checkboxes below.

---

## Progress

- [ ] Session 1 — Capture
- [ ] Session 2 — Organize
- [ ] Session 3 — Connect

**Current phase:** Session 1

---

## Session 1 — Capture

**Job:** Get the user comfortable dropping things into the vault without overthinking.

**Protocol:**
1. Greet the user warmly. Introduce yourself by name.
2. Tell them: "Your vault is set up. The only thing you need to do right now is use it."
3. Ask: "What's on your mind? Just list things — problems, ideas, tasks, anything."
4. As they share, drop each item into `00-Inbox/quick-notes.md`. Do it in front of them.
5. Show them the file after. "That's it. Everything lives here until we sort it."
6. Don't explain PARA. Don't show them the folder structure. Don't overwhelm.
7. Close with: "Next time we talk, we'll figure out where these go."
8. Write a session note to `06-Agent/workspace/memory/YYYY-MM-DD.md`
9. Mark Session 1 complete in this file.

**What not to do:**
- Don't give a vault tour
- Don't explain all the folders
- Don't mention systems, areas, or projects yet
- Don't make it feel like homework

---

## Session 2 — Organize

**Job:** Process the inbox together. Make filing feel easy, not like a decision.

**Protocol:**
1. Open `00-Inbox/quick-notes.md`. Read it aloud (summarize what's there).
2. For each item, say what you think it is and where it should go. Keep it casual:
   "This looks like a project. This one's just a reference. This one you might want to act on."
3. Move items only after the user confirms. Never assume.
4. If something's unclear, put it in `00-Inbox/unsorted/` — not everything needs a home today.
5. At the end, show the inbox is lighter. That feeling matters.
6. Mention: "The inbox is the one rule — everything starts here."
7. Write session note to memory.
8. Mark Session 2 complete in this file.

**What not to do:**
- Don't move things without showing the user first
- Don't introduce CRM, goals, or finances yet
- Don't make the user feel behind

---

## Session 3 — Connect

**Job:** Connect one real thing to the planning system. Make the vault feel like *their* system.

**Protocol:**
1. Ask: "Is there something you're working toward right now? A project, a goal, something you want to track?"
2. Whatever they name — create it. If it's a project, set up `01-Projects/[name]/`. If it's a goal, add it to `07-Systems/goals/`.
3. Link it back to a role in `08-CoreSystem/roles.md`. Ask: "Which part of your life does this serve?"
4. Show the thread: roles → goal → project → today's note.
5. Say: "That's the whole system. Everything in the vault connects to something you actually care about."
6. Briefly mention `corrections.md`: "If I ever do something you'd change — tell me. I keep track and I'll ask if I should update how I work."
7. Write session note to memory.
8. **Delete this file.** The vault is live.

**What not to do:**
- Don't try to connect everything at once
- Don't make it feel like a demonstration
- Do make it feel like their system, not a template they inherited

---

## After Deletion

The vault runs on its own. The agent uses the Session Start Protocol in `AGENTS.md`.

The learning loop is now active via `corrections.md`.

If the user ever feels lost, they can ask: "Walk me through how this vault works."
The agent should respond based on what's actually in the vault — not a generic explanation.
