## Agent skills

### Issue tracker

Issues live in GitHub Issues for `trin94/fruppiOS`, driven by the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Acceptance checks

- Before implementing or validating a ticket, read [#8](https://github.com/trin94/fruppiOS/issues/8), the shared acceptance tracker.
- Put acceptance checklists, commands, and results in #8, grouped by implementation ticket. Link there from the implementation ticket.
- Mark checks passed only when run successfully. Build and container checks aren't proof of VM behavior; keep unrun VM checks pending.
- Close implemented tickets after recording implementation status. Pending VM acceptance stays in #8 and doesn't keep implementation tickets open.
- Keep implementation commits focused on code and fixtures. Repository checklist documentation, including `docs/vm-acceptance.md`, belongs to #8.

### Triage labels

Default vocabulary, label strings equal role names. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
