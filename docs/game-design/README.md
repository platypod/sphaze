# Game design

The design documentation, split by lifecycle. Each file holds one kind of
content, and content *moves* between them as its status changes — the rules
of movement are the contract:

| File | Holds | Moves |
|---|---|---|
| [philosophy.md](philosophy.md) | Design pillars — what this game is trying to be | Changes rarely; when a decision changes a pillar, update it and record why in [design-decisions-records.md](design-decisions-records.md) |
| [story-line.md](story-line.md) | The **current state** of the story: live candidates, preferences, open decisions | When a story decision lands, the winner folds into the story (and its pillar consequences into philosophy.md); losers move to design-decisions-records.md with the why |
| [ideas-backlog.md](ideas-backlog.md) | Not-yet-implemented ideas, checked against philosophy.md before entering | When implemented, **delete the entry** — the implementation plus `../PROJECT_LOG.md` is the record from then on |
| [design-decisions-records.md](design-decisions-records.md) | Decision records: what was decided, what was rejected, and why | Append-only; entries never leave |

Related, outside this folder: [`../PROJECT_LOG.md`](../PROJECT_LOG.md) is the
chronological history (what happened, when); the records file here is the
decision-shaped view of the same events (what was chosen, against what, why).
An idea that cuts against a pillar is a reason to discuss it explicitly
(with hooman) rather than add it silently — same rule as always.
