/** Draft privacy policy and terms. Facts come from docs/launch-checklist.md and the business rules in CLAUDE.md.
 * Have a Nigerian lawyer review both (including NDPA 2023 duties) before the app goes to the stores. */

export const LEGAL_UPDATED = "6 November 2026";

export type LegalSection = { title: string; body: string[]; list?: string[] };

export const PRIVACY: LegalSection[] = [
  {
    title: "Who we are",
    body: [
      "PawPass is a product of Digital Ninja Technologies, based in Lagos, Nigeria. This policy explains what the PawPass app and this website collect, why, and who sees it.",
    ],
  },
  {
    title: "What we collect",
    body: ["We only collect what the app needs to work."],
    list: [
      "Your name, email address and phone number, for your account, bookings and receipts.",
      "Your pets' details and health records, for the Pet Passport.",
      "Photos you choose or take: pet photos, and identity documents if you apply as a partner.",
      "What you write in the community: posts, comments and messages.",
      "Your approximate location, only while the app is open and only if you allow it, to sort emergency vets by distance. We do not store it.",
      "Six anonymous app events (app open, booking started, checkout started, share started, partner started, help opened). They carry no personal data and no advertising identifier.",
    ],
  },
  {
    title: "What we do not collect",
    body: [
      "We never see your card number. Payments are handled by Paystack. We show only the last four digits of a card or bank account. We do not sell your data and we do not run advertising trackers.",
    ],
  },
  {
    title: "Who sees your data",
    body: [],
    list: [
      "Health records are private by default. A vet sees them only through a time limited link or QR code that you create.",
      "A partner you book sees your name, and only that.",
      "Pet photos are shown with a listing you create.",
      "Comments are shown to anyone who can see the post. A message request goes to the pet's owner, who has to accept before you can chat. You can report or block anyone.",
      "Partner identity documents are seen only by PawPass staff who verify partners.",
      "Lost pet alerts never show your phone number. Finders reach you through in app chat.",
      "Paystack processes payments and payouts.",
      "When a pet changes hands, the passport moves to the new owner. The previous owner keeps a read only record.",
    ],
  },
  {
    title: "How long we keep it",
    body: [
      "We keep your data while your account is open. When you delete your account, we remove your personal data at once, except records we must keep for payments, disputes or the law. Those keep your payment details but not your name.",
    ],
  },
  {
    title: "Your choices",
    body: [
      "You can edit your details in Settings, delete your account yourself from Privacy and sharing in the app, and turn off location or notifications in your phone settings. To ask for a copy of your data or a correction, contact us using the details below.",
      "Data is encrypted in transit.",
    ],
  },
  {
    title: "Children",
    body: ["PawPass is for adults. If you think a child has given us their details, tell us and we will delete them."],
  },
  {
    title: "Changes",
    body: ["If we change this policy in a way that matters, we will tell you in the app before it starts."],
  },
];

export const TERMS: LegalSection[] = [
  {
    title: "About these terms",
    body: [
      "By using PawPass you agree to these terms. PawPass is a product of Digital Ninja Technologies, Lagos, Nigeria.",
    ],
  },
  {
    title: "Your account",
    body: [
      "You sign in with a 6 digit code sent to your email. Keep your email secure and give us true details. You must be an adult to use PawPass.",
    ],
  },
  {
    title: "Pet Passport and health records",
    body: [
      "Your pet's passport and records are yours. Records added by a verified vet carry a Vet verified badge. PawPass stores records but does not give veterinary advice. In an emergency, call a vet.",
    ],
  },
  {
    title: "Booking services and payment",
    body: [],
    list: [
      "Vets, groomers, trainers and boarding providers are independent partners, not PawPass staff.",
      "You pay through the app. We hold the payment until you confirm the visit, then we pay the partner.",
      "You can cancel free of charge up to 2 hours before the visit.",
      "PawPass takes a commission from the partner, set out in the partner terms.",
      "If something goes wrong, raise a dispute. The related payout pauses until our team decides: a full refund, a split, or release to the partner.",
    ],
  },
  {
    title: "Buying a puppy or adopting",
    body: [],
    list: [
      "Puppies are sold only by verified breeders and shelters.",
      "The deposit and balance are held in escrow. PawPass charges an escrow fee, shown before you pay.",
      "After handover you have 72 hours to get a vet check. A health problem that a vet confirms in that time qualifies for a full refund.",
      "The passport moves to you when handover is confirmed.",
    ],
  },
  {
    title: "Community and lost pet alerts",
    body: [
      "Be kind and truthful. Do not post anything unlawful, abusive or misleading, and do not sell animals outside the verified listing flow. We can remove content and suspend accounts that break these rules. You can report a post, comment, profile or listing and block an account.",
      "You can comment on posts and reply to comments. You can also ask a pet's owner to chat. The owner decides whether to accept, and can decline without giving a reason. Do not send spam or pressure anyone.",
      "Lost pet alerts reach people near the pet's last known place and close after 14 days. Do not use them for anything else.",
    ],
  },
  {
    title: "Partners",
    body: [
      "Vets, service providers, breeders and shelters cannot go live until PawPass approves them. We aim to decide within 48 hours. We may ask for more information or decline an application. Partners are paid out every Monday.",
    ],
  },
  {
    title: "Our responsibility",
    body: [
      "We work hard to keep PawPass running, but we cannot promise it will never be interrupted. Partners and breeders are responsible for the services and animals they provide. Nothing in these terms limits rights you have under Nigerian law.",
    ],
  },
  {
    title: "Ending your account",
    body: [
      "You can delete your account yourself at any time, from Privacy and sharing in the app. We may refuse for a moment while a booking, payment or handover is unfinished. We may suspend or close an account that breaks these terms.",
    ],
  },
  {
    title: "Changes and law",
    body: [
      "We will tell you in the app before important changes to these terms start. These terms follow the laws of Nigeria.",
    ],
  },
];
