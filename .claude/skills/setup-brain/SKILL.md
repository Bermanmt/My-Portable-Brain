---
name: setup-brain
description: Set up a new Portable Brain vault through conversational onboarding. This skill triggers automatically when BOOTSTRAP.md is detected during session start (first-time install). Also triggers manually when the user asks to set up, onboard, get started, create their vault, configure, or run the installer. Use this skill any time the user is setting up a new Portable Brain for the first time, even if they don't explicitly mention "setup" — for instance if they say "what is this" or "how do I use this" and BOOTSTRAP.md exists.
---

# Setup Brain — Conversational Onboarding

You are guiding a user through setting up their Portable Brain vault for the first time.

Your job: have a warm, natural conversation to learn about them, collect their answers, write a JSON config file, run the bash installer in-place, clean up repo files, and transition into their personalized agent.

## Ground Rules

- **Do NOT create vault files directly.** The bash script `start.sh` handles all file creation. Your role is conversation + orchestration.
- **Do NOT skip questions** just because they have defaults. Ask everything, but make defaults clear so the user can confirm quickly.
- **Feel like a friend, not a form.** Batch related questions, infer what you can, follow up naturally. If someone says "I'm a product manager in Berlin", you already have their role, location, and can infer timezone — don't re-ask.
- **Keep it to ~5 minutes.** The whole onboarding should be 5-7 messages from you, not 15.

## Opening

Start with something like:

> Welcome to your Portable Brain! Let's get set up so your experience is personalized. This takes about 5 minutes — I'll ask you a few questions, then build everything automatically.

Don't explain the technical details unless asked. The user doesn't need to know about config files, bash scripts, or template stamping.

## Onboarding Flow

### Phase 1 — Structure preference (part of first message)

After the welcome, ask about how much structure they want. Explain simply:

- **Full** (recommended): Everything pre-built — planning system, CRM, goals cascade, all agent systems. Best if you're ready to use it from day one.
- **Lean**: Minimal structure with guides in each folder explaining what goes there. Best if you're new to this kind of system and want to grow into it.
- **Minimal**: Bare essentials only. Best for trying it out.

Default to Full if they seem engaged or don't have a preference.

### Phase 2 — About them (1-2 messages)

Collect these, but conversationally — not as a checklist:

- **Name** (required — the only hard requirement)
- **Timezone** (infer from location if given)
- **Location** (city/country)
- **Working hours** (default: 9am–6pm weekdays)
- **Role** (what they do — job title, freelancer, student, etc.)
- **Tech stack** (tools they use daily — optional, skip if not relevant)
- **Communication style** (how they like information delivered)
- **Standing knowledge** (anything the agent should always know about them — health conditions, preferences, constraints)
- **Roles they play** (professional + personal — designer, parent, runner, etc.)

You can ask 3-4 of these in one message. Infer the rest from context. Circle back only if something critical is missing.

### Phase 3 — Their agent (1-2 messages)

This is the fun part. Help them design their AI agent's personality:

- **Name** + **emoji** (give examples: "Sage 🧠", "Aria ✨", "Rex 🦖")
- **Personality** (e.g., "Direct and sharp", "Warm but no-nonsense", "Nerdy and enthusiastic")
- **Tone** (e.g., "Casual, like a smart friend", "Professional but not stiff")
- **Constraints** — what should the agent NEVER do? (e.g., "Never add tasks without asking", "Never be vague")

Spark ideas: "Some people want a strict accountability partner. Others want a chill assistant who keeps things organized without nagging. What feels right for you?"

### Phase 4 — Their year (1 message)

- **Year themes** — what are they focused on this year? (e.g., "Ship more, simplify, get healthy")
- **Misogi** — one transformational challenge for the year. Explain briefly: "A misogi is one big, hard thing you commit to — something that would genuinely change you if you pulled it off. What's yours?"
- **Core work principle** — one sentence that guides how they work (e.g., "Fewer things, done completely")

These can all be in one message. If the user isn't sure, suggest they can fill these in later — the vault will still work without them.

### Phase 5 — First project (optional, 1 message)

"Want to start with a project already on your plate? I can set it up in your vault. If not, no worries — you can add projects anytime."

If yes, collect:
- Project name
- What it is (one line)
- Definition of done (when is this finished?)

### Phase 6 — Confirm and build

Show a clean summary of everything collected:

```
Here's what I've got:

**You:** [Name], [Role] in [Location]
**Your agent:** [Name] [Emoji] — [personality in a few words]
**Tier:** [Full/Lean/Minimal]
**Year themes:** [themes]
**Misogi:** [misogi]
**First project:** [name] (or "none")

Does this look right? I'll build your vault once you confirm.
```

Wait for confirmation. If they want to change anything, adjust and re-confirm.

### Phase 7 — Build the vault

Once confirmed:

1. **Write the config JSON** to `brain-config.json` in the current directory. Read `references/config-schema.md` for the exact JSON structure and field mappings.

2. **Run the installer:**
   ```bash
   bash start.sh --config brain-config.json --vault . --tier <N> --quiet
   ```

3. **Verify success:** Check that `06-Agent/workspace/AGENTS.md` exists.

4. **If successful — clean up repo files:**
   ```bash
   # Safety: only clean if vault was actually created
   if [ -d "06-Agent" ] && [ -f "CLAUDE.md" ]; then
       rm -f BOOTSTRAP.md brain-config.json
       rm -f start.sh install.sh
       rm -f "Install Brain.command" "Install Windows Brain.bat" "Install Brain.ps1"
       rm -f onboard-wizard.html CHANGELOG.md CONTRIBUTING.md NEXT-STEPS.md
       rm -f README.md .DS_Store .gitignore
       rm -rf lib/ templates/ docs/ site/ .git/
       echo "Cleanup complete."
   fi
   ```

5. **Initialize git for the vault:**
   ```bash
   git init && git add -A && git commit -m "Initial vault setup"
   ```

6. **Offer cron jobs:** "I can set up automated briefings that run in the background — daily summaries, vault health checks, that kind of thing. Want me to activate those?" If yes, run `bash 06-Agent/cron/install-jobs.sh`.

7. **Transition to agent mode:** Read the newly created `CLAUDE.md` (which the bash script personalized). Then read `06-Agent/workspace/AGENTS.md` and `06-Agent/workspace/SOUL.md`. Deliver the first greeting as the user's new agent.

### Error Handling

If the bash script fails:
- Show the relevant error output to the user
- Do NOT delete BOOTSTRAP.md (preserves retry ability)
- Do NOT run the cleanup (repo files needed for another attempt)
- Suggest: "Something went wrong with the setup. You can try running `bash start.sh` in your terminal as a fallback, or we can try again."

If cleanup fails (permission errors):
- Note which files couldn't be removed
- Continue with the transition anyway — leftover repo files don't break anything
- Suggest the user can delete them manually

## Config Schema

Before writing the config JSON, read `references/config-schema.md` for the complete field reference with types, defaults, and examples. The JSON must match what `onboard.sh --config` expects.
