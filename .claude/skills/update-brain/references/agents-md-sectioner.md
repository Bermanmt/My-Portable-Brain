# AGENTS.md Section-Aware Merge

This file explains how to parse, classify, and merge markdown files that have `## ` section structure — primarily `AGENTS.md` and the `subagents/*/AGENT.md` files.

## Why section-aware

A naive three-way merge (using `git merge-file` or `diff3`) produces line-level conflicts that are often unreadable for `AGENTS.md`, because:

- Users frequently add new sections or restructure existing ones.
- Upstream regularly adds new protocols (e.g., Session Start Protocol step 9 for `refresh-all.sh`).
- Most changes are contained within a single section — conflicts at the section level are tractable, conflicts at the line level are not.

Working at the section level lets us:
1. Take upstream's new sections cleanly.
2. Keep the user's customized sections cleanly.
3. Flag only the sections where both sides meaningfully changed the same content.

## Parsing

Split a document into sections by `## ` (level-2) headers. Everything before the first `## ` is the "preamble". Everything after a `## ` header up to (but not including) the next `## ` is that section's body.

```
# Title
Preamble line 1
Preamble line 2

## Section A
Section A body line 1
Section A body line 2

## Section B
Section B body
```

Parsed:
- `preamble` → "# Title\nPreamble line 1\nPreamble line 2\n\n"
- `Section A` → "Section A body line 1\nSection A body line 2\n\n"
- `Section B` → "Section B body\n"

Keep a stable ordering: the order sections appear in each document.

## Three-way comparison

For each section name that appears in any of the three documents (baseline, upstream, user):

| Present in baseline | Present in upstream | Present in user | State |
|---|---|---|---|
| Yes | Yes | Yes | existing |
| No | Yes | No | upstream-new |
| No | No | Yes | user-new |
| Yes | No | Yes | upstream-deleted |
| Yes | Yes | No | user-deleted |
| No | Yes | Yes | parallel-add |
| Yes | No | No | both-deleted |

For `existing` sections, compare the bodies:

| User vs baseline | Upstream vs baseline | Action |
|---|---|---|
| Same | Same | No change |
| Same | Different | Take upstream |
| Different | Same | Keep user |
| Different | Different | Needs resolution (see below) |

For other states:
- `upstream-new` → add it to the user's document at the position it appears upstream (relative to neighboring sections also present in the user's doc).
- `user-new` → keep, do nothing.
- `upstream-deleted` → ask the user. "Upstream removed section `X` but you still have it. Remove from your vault, keep it, or show me why they removed it?"
- `user-deleted` → do nothing. They removed it on purpose.
- `parallel-add` (section exists in both upstream and user but not baseline) → they added the same section name independently. Show both bodies, ask which to keep.
- `both-deleted` → no-op.

## Resolving "both different" sections

When both the user and upstream modified the same section differently, attempt to propose a merge:

### Step 1 — Try simple integration

Examples that can usually be auto-resolved:

- **Additive upstream change**: upstream added a new bullet to a list. If the user's list preserves all the baseline bullets and added their own, integrate upstream's new bullet at the position upstream chose.
- **Rename within the section**: upstream renamed a heading inside the section. Apply the rename; keep user's content changes.
- **Clarification**: upstream rephrased a sentence for clarity without changing meaning. Take upstream's phrasing; keep user's additions elsewhere in the section.

### Step 2 — If integration is clean, propose it

Show the user:

```
Section: "Session Start Protocol"

Both you and upstream changed this section. Proposed merge:

  [show the merged section]

Changes from upstream you'll get:
  • New step 9 references `refresh-all.sh` (upstream addition)
  • Step 12 now says "Task Registry Protocol" not "Task Registry" (upstream rename)

Changes from you that are preserved:
  • Your added bullet at step 11 about "read yesterday's memory"
  • Your custom formatting in step 15

Apply this merge? (y/n/show diff)
```

### Step 3 — If integration is not clean, flag it

When upstream and user both rewrote the same paragraphs in incompatible ways:

```
Section: "Planning Conversation Protocol"

Both you and upstream significantly changed this section. I can't see a clean merge.

Your version: [show]
Upstream version: [show]

What to do?
  (u) Take upstream (you'll lose your edits in this section)
  (m) Keep yours (you won't get upstream's changes)
  (e) Edit manually — I'll open both for you
  (s) Skip this file entirely for now
```

## Presentation rules for diffs

- Show **section-level diffs**, not line-level whenever possible. "Upstream added a new bullet" is more useful than "5 lines added starting at line 142."
- Summarize in natural language first, show the raw diff only if the user asks for it or `(s) show diff` is selected.
- Preserve formatting in proposed merges — match the user's bullet style (`-` vs `*`) and indentation.

## Writing the merged file

Reconstruct the merged document by emitting sections in order:

1. Start with the user's preamble (unless upstream changed it and user didn't — then take upstream).
2. For each section name (using upstream's ordering as the guide, with user-only sections inserted at their original positions):
   - Write the `## Section Name` header
   - Write the resolved body (either unchanged, upstream-new, user-kept, or merged)
   - Preserve blank lines and separators (`---`) from the source of truth for that section

Write the result to the target path in the user's vault.

## Verification

After writing, sanity-check the merged file:

- No unresolved conflict markers (`<<<<<<`, `>>>>>>`, `======`).
- No duplicate section headers (same `## Name` appearing twice).
- File is not empty.
- File parses as valid markdown (no unclosed code blocks).

If any check fails, roll back the write and tell the user.

## Edge cases

**User moved a section.** The section appears in the user's doc at a different position than the baseline. Treat it as: the section at that body content is the "same" section. Preserve the user's chosen position for that section. If upstream also moved it, prefer upstream's new position (this is uncommon).

**User renamed a section header.** Hard to detect automatically. If you find an upstream section that has no match by name in the user's doc but has a close body-similarity match to a user section with a different name, surface it: "Did you rename `X` to `Y`? If yes, I'll merge the upstream changes into your `Y`."

**Deep subsection structure.** Some files use `### ` and `#### ` nesting. For the first version of this skill, merge at the `## ` level only — treat subsections as part of the parent section's body. A future version can go deeper.
