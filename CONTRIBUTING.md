# Contributing

Thanks for wanting to help. This is a v0.x project — contributions that fix real problems or make the system meaningfully better are very welcome.

---

## What's useful right now

- **Bug reports** — something in the scripts breaks or behaves unexpectedly
- **Vault structure feedback** — you used it and something didn't work as documented
- **AGENTS.md / BOOTSTRAP.md improvements** — better agent instructions based on real usage
- **LEARN.md content** — clearer explanations for Tier 1 contextual help files
- **Linux / Windows WSL testing** — primarily tested on macOS right now

## What to hold off on

- Python / database features — planned for v0.2+, API not designed yet
- New tiers or systems — stabilizing v0.1 first
- UI or web dashboard — out of scope for this project

---

## How to contribute

1. Fork the repo
2. Create a branch: `git checkout -b fix/what-you-changed`
3. Make your change
4. Test it: `bash start.sh --dry-run`
5. Open a PR with a clear description of what changed and why

For non-trivial changes, open an issue first to discuss the approach.

---

## Reporting issues

Please include:
- OS and bash version (`bash --version`)
- The command you ran
- What you expected vs what happened
- Any error output

---

## Style

**Bash:** follow the style in `lib/onboard.sh` — named functions, colored output, consistent indentation, `set -e` at the top.

**Markdown:** readable in raw form, not just when rendered. No excessive formatting.

**Comments:** explain *why*, not *what*.

---

## Architecture decisions

Before making significant changes, read `docs/decisions/`. If your change involves a design decision, add a doc explaining context, reasoning, and consequences. This is how the project stays coherent over time.
