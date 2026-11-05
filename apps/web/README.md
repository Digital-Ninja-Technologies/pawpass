# apps/web

Public landing site for PawPass: what the app is, how money and records are protected, lost and found,
a partners section, an FAQ and a waitlist form. A single static page; only the waitlist form runs on the server.

```bash
cp .env.example .env.local
pnpm --filter @pawpass/web dev
```

- The waitlist form writes to `waitlist_signups` with the publishable key. The table allows inserts only
  (visitors cannot read it), emails are unique case insensitively, and a hidden honeypot field catches simple bots.
  Staff can read the list through the database.
- Photos in `public/photos` are the placeholder stock photos from `design/assets`. Replace them with your own
  photography before launch.
- Fonts are bundled (`app/fonts`), so nothing is fetched from Google at build or run time.
- Legal pages (privacy policy, terms) are not written yet and are not linked.
