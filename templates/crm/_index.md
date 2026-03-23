# Relationships

Personal relationship manager — tracks the *people*, not just deals.
Complements professional CRMs (HubSpot, etc.) with personal context, interaction history, and life details that matter.

## Contacts
All contacts in `contacts/` — one file per person.
A contact can be a friend, client, family member, collaborator — or all of the above.

## Pipeline (Professional)
For active deals or professional relationships with a clear stage:
- [[pipeline/leads]] · [[pipeline/active]] · [[pipeline/closed]]

## How It Works

**CRM Agent** (background) keeps contacts current:
- Scans daily notes and processed meeting/email summaries for contact mentions
- Auto-updates interaction logs, preferences, open loops
- Maintains `briefing.md` with: follow-ups due, upcoming dates, recent changes
- Only flags unusual items for approval (new contacts, contradicting info)

**{{AGENT_NAME}}** (user-facing) surfaces context when it matters:
- Morning briefing: follow-ups due today, meetings with known contacts
- Weekly review: upcoming birthdays, stale relationships, project-linked contacts
- On demand: "What should I remember about [person]?" → reads contact file directly

**Rule:** CRM Agent writes. {{AGENT_NAME}} reads. User decides.
