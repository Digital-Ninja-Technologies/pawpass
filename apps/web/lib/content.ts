export type PetId = "dog" | "cat" | "both";

export const PET_OPTIONS: { id: PetId; label: string }[] = [
  { id: "dog", label: "A dog" },
  { id: "cat", label: "A cat" },
  { id: "both", label: "Both!" },
];

export const PET_INFO: Record<PetId, { name: string; breed: string; when: string; text: string }> =
  {
    dog: {
      name: "Bingo",
      breed: "Boerboel · 2 yrs",
      when: "DUE IN 7 DAYS",
      text: "Bingo's rabies booster",
    },
    cat: {
      name: "Mimi",
      breed: "Tabby cat · 1 yr",
      when: "DUE FRIDAY",
      text: "Mimi's flea treatment",
    },
    both: {
      name: "Bingo & Mimi",
      breed: "1 dog · 1 cat",
      when: "THIS WEEK",
      text: "2 reminders for your crew",
    },
  };

export const CITIES = [
  "Lagos",
  "Abuja",
  "Port Harcourt",
  "Ibadan",
  "Enugu",
  "Benin City",
  "Kano",
  "Abeokuta",
  "Uyo",
  "Kaduna",
];

export type TabId = "health" | "book" | "community" | "trust";

export const TABS: { id: TabId; label: string; title: string; body: string; points: string[] }[] = [
  {
    id: "health",
    label: "Health",
    title: "A passport for every pet",
    body: "All their vaccines, treatments and vet visits in one place, with reminders that actually arrive on time.",
    points: [
      "Snap the paper card, we read the dates",
      "Reminders by push, email or WhatsApp",
      "Share records with any vet by QR code",
    ],
  },
  {
    id: "book",
    label: "Book care",
    title: "Trusted vets and groomers nearby",
    body: "Book verified clinics, groomers, trainers and boarding in Lagos and cities across Nigeria. Pay in the app, safely.",
    points: [
      "Real time slots, no back and forth calls",
      "Your money is held until the visit is done",
      "Emergency vets open now, one tap away",
    ],
  },
  {
    id: "community",
    label: "Community",
    title: "Your pet, the neighbourhood star",
    body: "Share photos, follow pet friends nearby and help reunite lost pets with their families.",
    points: [
      "Lost pet alerts within 5 km",
      "Chat with finders, no phone number shared",
      "Pet profiles for show offs",
    ],
  },
  {
    id: "trust",
    label: "Find a pet",
    title: "Buy or adopt without the fear",
    body: "Every breeder and shelter is verified, and every pet comes with a passport that moves to you.",
    points: [
      "Verified breeders and rescues",
      "Escrow payment with a 72 hour vet check",
      "Adopt from shelters near you for free",
    ],
  },
];

export const FAQS: { q: string; a: string }[] = [
  {
    q: "Is OurPawPass free?",
    a: "Yes. Records, reminders, community and lost pet alerts are free. You only pay for services you book, like a vet visit or grooming.",
  },
  {
    q: "Is my money safe when I book or buy a puppy?",
    a: "Your payment is held by OurPawPass and only released when you confirm the visit, or after the 72 hour vet check for a puppy. If something goes wrong, report it and we step in.",
  },
  {
    q: "Who can see my pet's health records?",
    a: "Only you, unless you choose to share. Sharing with a vet uses a link or QR code that expires, and you pick what they can see.",
  },
  {
    q: "Is OurPawPass only for Lagos?",
    a: "No. OurPawPass is for pet owners wherever you are. Health records, reminders, the community and lost pet alerts work in any city. We started in Lagos and are adding vets, groomers, breeders and shelters in Abuja, Port Harcourt, Ibadan and more.",
  },
  {
    q: "Does it work for cats and other pets?",
    a: "Yes. Dogs and cats get suggested vaccine schedules, and you can add any pet and set your own reminders.",
  },
];
