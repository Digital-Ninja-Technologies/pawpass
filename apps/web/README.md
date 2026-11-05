# apps/web

Public landing page for PawPass, built to match `design/landing/Main.dc.html` (and `Mobile.dc.html`):
hero with a dog, cat or both picker, city marquee, pain point cards, feature tabs, a tappable lost and found
collar tag, set up steps, partner section, FAQ and a download section.

```bash
cp .env.example .env.local
pnpm --filter @pawpass/web dev
```

## Store links and the email form

- The app is not in the stores yet, so the iPhone and Android buttons lead to the email form. When the apps are
  live, set `NEXT_PUBLIC_APP_STORE_URL` and `NEXT_PUBLIC_PLAY_STORE_URL` (both) and the buttons link out and the
  "not in the stores yet" note disappears.
- The email form writes to `waitlist_signups` with the publishable key. The table allows inserts only (visitors
  cannot read it), emails are unique ignoring case, and a hidden honeypot field catches simple bots.
- The design has a QR code. A real one needs the final store link, so it is left out until then.

## Notes

- Photos in `public/photos` are the placeholder stock photos from `design/assets`. Replace them with your own before launch.
- Fonts are bundled (`app/fonts`), so nothing is fetched from Google.
- Privacy, Terms and Contact pages do not exist yet, so the footer does not link to them.
- Copy content lives in `lib/content.ts`, and `lib/waitlist.test.ts` checks it against the copy rules (no em dashes, no hyphenated "72-hour" style phrases).
