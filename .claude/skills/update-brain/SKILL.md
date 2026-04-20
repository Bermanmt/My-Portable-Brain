---
name: update-brain
description: Update an existing Portable Brain vault to the latest version from the repo, merging upstream changes while preserving the user's customizations. Triggers when the user asks to update their brain, upgrade their vault, check for updates, pull the latest version, or sync their brain with the repo. Also use when the user asks "what's new?" or "am I on the latest version?" about their vault.
---

# Update Brain — Safe Vault Upgrade with Conflict Resolution

You are upgrading a user's existing Portable Brain vault to the latest version from the upstream repo, preserving their customizations.

Your job: detect the user's current version, fetch the latest, compute a merge plan, get approval, apply changes with a rollback point, and log the result.

## Ground Rules

- **Never write to the vault without an approved plan.** Every change goes through the plan → approve → apply loop.
- **Never touch runtime state.** Memory files, handoffs, briefings, CRM contacts, and goals notes are the user's data, not templates. See `references/merge-strategies.md` for the full "never touch" list.
- **Always create a git rollback point** before any write (when the vault has git).
- **Prefer merging over replacing** for any file the user is likely to have customized (AGENTS.md, subagent AGENT.md, conventions.md).
- **Be transparent.** Show diffs. Explain what's changing and why. The user is trusting you with their second brain.

## Update Flow

### Phase 1 — Detect current version

Read `06-Agent/state/version.md`. It should contain a single line like `v0.6.0`.

**If the file doesn't exist** (user installed before v0.6):
- Ask: "I can't tell which version of the Portable Brain you installed. Do you know? The latest versions are v0.6, v0.5, v0.4, v0.3, v0.1."
- If they know: write `06-Agent/state/version.md` with that version, proceed.
- If they don't: fall back to a conservative strategy — assume `HEAD^` (one commit before latest) as baseline. Tell them: "I'll treat your vault as one version behind the latest and merge carefully. If something looks wrong in the plan, we'll adjust."

### Phase 2 — Fetch the latest

Clone the repo to a temp directory:

```bash
REPO_URL="https://github.com/Bermanmt/My-Portable-Brain.git"
CLONE_DIR="/tmp/portable-brain-update-$$"
git clone --quiet "$REPO_URL" "$CLONE_DIR"
```

Read the latest version:

```bash
LATEST=$(cat "$CLONE_DIR/VERSION" 2>/dev/null || git -C "$CLONE_DIR" describe --tags --abbrev=0)
```

If `LATEST` equals the user's current version: tell them they're up to date, clean up, end. Show what's coming in the next release if `CHANGELOG.md` has a `[X.Y.Z] — planned` section.

### Phase 3 — Get the baseline

For 3-way merge, you need the templates as they existed at the user's installed version. Check out that tag in the clone:

```bash
git -C "$CLONE_DIR" worktree add "/tmp/portable-brain-baseline-$$" "$CURRENT_VERSION"
BASELINE_DIR="/tmp/portable-brain-baseline-$$"
```

Now you have:
- **Baseline** — `$BASELINE_DIR/templates/` (what onboard.sh stamped into the vault at install time)
- **Upstream** — `$CLONE_DIR/templates/` (latest)
- **User** — the vault at its current state

### Phase 4 — Compute the plan

For each file in the merge scope (see `references/merge-strategies.md` for the full map):

1. Classify the file: `system-code` | `section-merge` | `user-data` | `additive-only` | `runtime-state` | `skip-heredoc-generated`.
2. Diff baseline vs upstream → `upstream_changed` (boolean).
3. Diff baseline vs user → `user_changed` (boolean).
4. Decide the action:

| upstream_changed | user_changed | Classification | Default action |
|---|---|---|---|
| No | * | * | Skip (no-op) |
| Yes | No | any | Take upstream automatically |
| Yes | Yes | `system-code` | Show diff, default "take upstream" with "keep mine" override |
| Yes | Yes | `section-merge` | Propose merged version, ask for approval (see below) |
| Yes | Yes | `user-data` | Never auto-apply — show upstream and ask user to cherry-pick |

For files that exist upstream but not in the user's vault: **add** them (unless classified `skip-heredoc-generated`).

For files that exist in the user's vault but have been deleted upstream: **leave them alone** but flag in the plan output.

### Phase 5 — Propose merged versions for section-merge files

This is the skill's killer feature. For AGENTS.md and subagent AGENT.md files where both sides changed:

1. Follow `references/agents-md-sectioner.md` to split each version into sections by `## ` headers.
2. For each section, determine the three-way state (unchanged / user-changed / upstream-changed / both-changed).
3. For "both-changed" sections, **propose a merged version** that integrates upstream's new content with the user's customizations. Examples:
   - Upstream added a new bullet to the Safety Rules list — insert it in the user's customized list at the right position.
   - Upstream renamed a section — use the new name, keep user's content.
   - Upstream rewrote the section entirely — show the user both versions side-by-side and ask.
4. If you're confident in the merge, show the user the proposed merged section and ask "merge this way, keep yours, or take upstream's?"
5. If you're not confident, explicitly flag it: "Both sides changed Section X significantly. I don't see a clean merge — please pick one."

### Phase 6 — Show the plan

Before any write, present a summary:

```
Update plan: v0.5.0 → v0.6.0

Additive (6 new files — no conflict)
  + 06-Agent/cron/jobs/daily-closing.sh
  + 06-Agent/cron/jobs/inbox-sweep.sh
  + 06-Agent/cron/jobs/weekly-review.sh
  + 06-Agent/cron/jobs/rebuild-context.sh
  + 06-Agent/cron/jobs/vault-lint.sh
  + 06-Agent/cron/jobs/weekly-tag.sh

Replacements (3 system files — you haven't edited these)
  ↑ 06-Agent/cron/jobs/daily-briefing.sh
  ↑ 06-Agent/cron/jobs/pattern-check.sh
  ↑ 06-Agent/cron/jobs/vault-health.sh

Merges (2 files — proposed, please review)
  ⇄ 06-Agent/workspace/AGENTS.md
     • Section "Planning Conversation Protocol" — you changed, upstream unchanged → keeping yours
     • Section "Task Registry Protocol" — new upstream, you don't have it → adding
     • Section "Session Start Protocol" — both changed, proposed merge ready to show
  ⇄ 06-Agent/subagents/crm-manager/AGENT.md
     • Section "Contact Detection" — both changed → proposed merge ready to show

Skipped (not updated by design)
  · 06-Agent/workspace/SOUL.md (user customization)
  · 06-Agent/workspace/USER.md (user data)
  · 06-Agent/subagents/calendar-agent/config.md (user calendars)

Ready to apply? I'll create a git snapshot first so you can roll back.
  (y) Yes, create snapshot and apply
  (r) Review the merge proposals first
  (n) Cancel
```

If the user picks `(r)`, walk through each merge proposal one by one, getting explicit approval per file before moving on.

### Phase 7 — Create the rollback point

If the vault has git:

```bash
cd "$VAULT_ROOT"
git add -A
git commit -m "pre-update snapshot — before upgrading to v$LATEST" --allow-empty
```

Record the commit SHA — include it in the final output so the user can revert.

If the vault has no git:
- Tell the user: "Your vault doesn't have git initialized, so I can't create a rollback point. You can still cancel now, or I can proceed without rollback capability."
- Wait for explicit approval before proceeding.

### Phase 8 — Apply the changes

Apply in this order to minimize the chance of a half-finished state:

1. **Additive files first** — new files only add surface area, can't break anything.
2. **Replacements next** — overwrite system files with upstream versions.
3. **Merged files last** — write the approved merged content.

After each write, verify: file exists, has non-zero size, no unresolved `{{TOKEN}}` markers.

### Phase 9 — Update version + log

Write the new version to `06-Agent/state/version.md`:

```
v0.6.0
```

Append to `06-Agent/state/update-log.md` (create if missing):

```markdown
## 2026-04-20 → v0.6.0
- From: v0.5.0
- Applied: 6 additions, 3 replacements, 2 merges
- Snapshot: <git SHA>
- Skipped: SOUL.md, USER.md, calendar-agent/config.md
- Notes: <anything unusual>
```

### Phase 10 — Self-install, clean up, summarize

**Self-install** — before removing the clone, copy the skill into the user's vault so future updates work without needing the repo cloned in the user's skill path.

```bash
mkdir -p "$VAULT_ROOT/.claude/skills"
# Copy if missing, or if the version in the clone is newer than the vault's copy
if [ ! -d "$VAULT_ROOT/.claude/skills/update-brain" ] || \
   [ "$CLONE_DIR/.claude/skills/update-brain/SKILL.md" -nt "$VAULT_ROOT/.claude/skills/update-brain/SKILL.md" ]; then
    rm -rf "$VAULT_ROOT/.claude/skills/update-brain"
    cp -R "$CLONE_DIR/.claude/skills/update-brain" "$VAULT_ROOT/.claude/skills/update-brain"
fi
# Also copy the setup-brain skill for completeness — users may want to re-run onboarding
if [ ! -d "$VAULT_ROOT/.claude/skills/setup-brain" ] && [ -d "$CLONE_DIR/.claude/skills/setup-brain" ]; then
    cp -R "$CLONE_DIR/.claude/skills/setup-brain" "$VAULT_ROOT/.claude/skills/setup-brain"
fi
```

Note for the user on first install: "I've copied the update-brain skill into your vault at `.claude/skills/update-brain/` — that way future updates work from your vault directly, no repo clone needed in your Claude path."

**Clean up** the temp clone:

```bash
git -C "$CLONE_DIR" worktree remove "$BASELINE_DIR" 2>/dev/null
rm -rf "$CLONE_DIR"
```

**Summarize** — tell the user what changed in their vault, what to try first (e.g., "Run `brain refresh` to see the new daily-closing job in action"), and how to roll back if anything feels off:

```
If you want to undo this update:
  cd <vault>
  git reset --hard <snapshot SHA>
```

## Error Handling

**Clone failed** (network / auth): tell the user, suggest running `git clone` manually to test connectivity. Don't proceed.

**Baseline checkout failed** (tag doesn't exist): fall back to `HEAD^` as baseline. Warn the user the merge will be less precise.

**Merge conflict the user rejects**: skip that file, continue with the rest. Include in the final summary: "You chose to skip X — the upstream version is available at `$CLONE_DIR/templates/...` if you want to look later."

**Apply step fails mid-update**: stop immediately. Tell the user the state they're in. Offer: "Roll back to the pre-update snapshot, or leave the partial update in place?" Don't try to auto-recover.

**Rollback requested**: `git reset --hard <snapshot SHA>` and confirm.

## What This Skill Does NOT Do (Yet)

- **Update `SOUL.md`, `IDENTITY.md`, `USER.md`, `TOOLS.md`, `conventions.md`, or `08-CoreSystem/` files.** These are generated by `lib/onboard.sh` heredocs, not from `templates/`. Until onboard.sh is refactored (v0.7.0 planned), the templates for these files diverge from what users actually have. Don't attempt to merge them — you'd be diffing against the wrong baseline. Document this limitation in the plan output under "Skipped (not updated by design)".
- **Partial updates.** You apply the whole plan or none of it.
- **Downgrade or pin to specific version.** Only forward updates to the latest are supported.

## Reference Files

- `references/merge-strategies.md` — file-path mapping, classification per file, never-touch list
- `references/agents-md-sectioner.md` — how to parse AGENTS.md into sections and propose three-way merges
