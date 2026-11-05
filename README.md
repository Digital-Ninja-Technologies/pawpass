# PawPass

Every pet's life, in one place. A mobile app for pet owners in Lagos (health passport, trusted vets and groomers, community and lost & found, verified breeders and shelters) plus a web admin console for the PawPass ops team. Built by Digital Ninja Technologies.

- `CLAUDE.md`: project brief, stack, tokens and rules (read this first)
- `docs/PRD.md`: product requirements
- `docs/data-model.md`: database tables
- `docs/build-plan.md`: milestones with Claude Code prompts
- `design/`: source screen designs and photos
- `apps/mobile`: Flutter app
- `apps/admin`: Next.js admin console for the ops team
- `apps/web`: public landing site with a waitlist form
- `packages/shared`: TypeScript tokens, Supabase client and helpers for the admin app
- `supabase/`: migrations and functions (to be created)

## Getting started with Claude Code

```bash
git clone https://github.com/Digital-Ninja-Technologies/pawpass.git
cd pawpass
claude
```

Then paste the first prompt from `docs/build-plan.md`.
