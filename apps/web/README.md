# apps/web

Public landing page for PawPass, built to match `design/landing/Main.dc.html` (and `Mobile.dc.html`):
hero with a dog, cat or both picker, city marquee, pain point cards, feature tabs, a tappable lost and found
collar tag, set up steps, partner section, FAQ and a download section.

```bash
cp .env.example .env.local
pnpm --filter @pawpass/web dev
```

## Store links and the "Get the app" pop up

- "Get the app" in the header opens a pop up with the download buttons (the download section and the hero use
  the same buttons). The app is not in the stores yet, so the iPhone and Android buttons show "Coming soon" and
  are not links. When the apps are live, set `NEXT_PUBLIC_APP_STORE_URL` and `NEXT_PUBLIC_PLAY_STORE_URL` (both)
  and the buttons link out and the "not in the stores yet" notes disappear.
- There is no email form. The `waitlist_signups` table and its policies still exist in Supabase, unused by this site.
- The design has a QR code. A real one needs the final store link, so it is left out until then.

## Notes

- Photos in `public/photos` are the placeholder stock photos from `design/assets`. Replace them with your own before launch.
- Fonts are bundled (`app/fonts`), so nothing is fetched from Google.
- `/privacy` and `/terms` are drafts (text in `lib/legal.ts`). Have a lawyer review them before launch. Set `NEXT_PUBLIC_CONTACT_EMAIL` to show a support email. There is no separate Contact page.
- Copy content lives in `lib/content.ts`, and `lib/content.test.ts` checks it against the copy rules (no em dashes, no hyphenated "72-hour" style phrases).

## Onboarding preview

The download section has a phone (`components/OnboardingDemo.tsx`) that plays the nine real onboarding screens
from `design/screens` (Welcome to Passport ready) by itself and loops: it types the email, name and area,
fills the code, ticks the options and taps each button. It is a recording, not a form: nothing is sent or
stored and there is nothing to tap inside the phone. It only runs while on screen and the tab is in front, has a
"Pause preview" button (with previous and next step buttons while paused), and does not autoplay when the
visitor prefers reduced motion. Timings live in `SCENES` at the top of the file (units of 100 ms).

## "Tap to explore" scroll story

On screens at least 960px wide and 740px tall (and not for visitors who prefer reduced motion),
`components/FeatureTabs.tsx` pins the section under the header and walks through the four features as you
scroll: the tab, the phone screen and a progress rail follow the scroll, each feature's three points appear
one by one, and after the last one the section is released and scrolls away. Clicking a tab (or arrow keys)
scrolls to that feature. On smaller or shorter screens, and with reduced motion, it is the plain tab picker.
The scroll length per feature is `70vh` in `.fx-on` in `globals.css`; the pin offset (`96px`) must match `STICK`.
