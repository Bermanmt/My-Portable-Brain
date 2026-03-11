# Decision 001 — No Python or Databases in v1

**Date:** 2026-03-11
**Status:** Accepted

## Decision

V1 ships as pure bash scripts + markdown files. No Python, no SQLite, no vector databases, no pip installs.

## Context

The original README described semantic search (ChromaDB), entity extraction (spaCy), and a full SQLite state layer. These are genuine capabilities worth building. But they require Python 3.11+, several pip packages, and non-trivial setup — before a user has seen a single vault file.

## Reasoning

The core value of this system is the vault structure + agent protocol. A user can get 90% of the value with zero dependencies beyond bash and Claude. Adding a Python stack to v1:

- Raises the barrier to getting started
- Creates install failures on different OS/Python versions
- Delays shipping something real
- Conflates what the system *is* with what it *could eventually do*

V1 should be answerable with: "Does bash work on your machine? That's it."

## Consequences

- No semantic search in v1 (use Obsidian's built-in search instead)
- No automatic classification (agent does this conversationally)
- No confidence scoring (agent uses judgment)
- No SQLite state (corrections.md is plain markdown)

The markdown files are designed to be the source of truth now and always. The database layer, when it comes, will be a performance optimization built on top — not a dependency the system can't run without.

## V2 path

Once v1 is stable and the vault structure is proven, add:
- `brain search` command (Python + embeddings)
- Auto-classification with confidence scores
- SQLite for fast queries across large vaults

These are additive. V1 vaults upgrade automatically.
