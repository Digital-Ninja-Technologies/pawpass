/// The help centre, written once here. Plain, friendly British English; no em dashes.
/// Figures such as "2 hours" and "72 hours" match the default business rules (admin Settings).
library;

enum HelpTopic {
  passport('Pet Passport'),
  booking('Booking care'),
  payments('Payments and escrow'),
  buying('Buying or adopting'),
  lost('Lost pets and QR tags'),
  partners('Partners');

  const HelpTopic(this.label);
  final String label;
}

class HelpStep {
  const HelpStep(this.title, this.text);
  final String title;
  final String text;
}

class HelpDoc {
  const HelpDoc({
    required this.id,
    required this.topic,
    required this.title,
    required this.summary,
    required this.intro,
    this.steps = const [],
    this.callout,
    this.minutes = 2,
    this.popular = false,
    this.related = const [],
  });

  final String id;
  final HelpTopic topic;
  final String title;
  final String summary;
  final String intro;
  final List<HelpStep> steps;

  /// A box under the article for the thing people most often get wrong.
  final String? callout;
  final int minutes;
  final bool popular;

  /// Ids of other articles worth reading next.
  final List<String> related;

  String get searchText =>
      '$title $summary $intro ${steps.map((s) => '${s.title} ${s.text}').join(' ')}'
          .toLowerCase();
}

const helpDocs = <HelpDoc>[
  HelpDoc(
    id: 'escrow',
    topic: HelpTopic.payments,
    title: 'How escrow protects you',
    summary: 'Why your money is held until you confirm',
    popular: true,
    intro:
        'When you pay for a visit or a puppy, OurPawPass holds the money. The partner is paid only after you say it went well.',
    steps: [
      HelpStep(
        'You pay',
        'Card, bank transfer or USSD. The money goes to OurPawPass, not the partner.',
      ),
      HelpStep(
        'The visit happens',
        'Go to your booking, or collect your puppy as agreed.',
      ),
      HelpStep(
        'You confirm',
        'Tap Confirm visit. If you do not, we ask you again after a day.',
      ),
      HelpStep('The partner is paid', 'Payouts run every Monday.'),
    ],
    callout:
        'Something wrong? Report a problem before you confirm. The payout waits until our team decides.',
    related: ['refunds', 'dispute'],
  ),
  HelpDoc(
    id: 'refunds',
    topic: HelpTopic.payments,
    title: 'Cancelling and refunds',
    summary: 'Free up to 2 hours before a visit',
    popular: true,
    intro:
        'You can cancel a booking for free up to 2 hours before it starts. If a provider or seller cancels, you are refunded in full.',
    steps: [
      HelpStep(
        'Cancel in time',
        'Open My bookings, choose the booking, then Cancel. Your payment is refunded in full.',
      ),
      HelpStep(
        'Cancel late',
        'Closer than 2 hours to the visit, the partner may keep part of the payment. We show you before you confirm.',
      ),
      HelpStep(
        'Getting the money back',
        'A refund goes to the card or bank you paid with. It can take a few days to show.',
      ),
    ],
    related: ['escrow', 'dispute'],
  ),
  HelpDoc(
    id: 'dispute',
    topic: HelpTopic.payments,
    title: 'Reporting a problem with a booking',
    summary: 'How disputes are decided',
    intro:
        'If a visit did not go as agreed, report it from My bookings before you confirm. Nobody is paid while we look into it.',
    steps: [
      HelpStep(
        'Tell us what happened',
        'Pick a reason, add a few words and photos if you have them.',
      ),
      HelpStep(
        'We pause the payout',
        'The partner is not paid until our team has decided.',
      ),
      HelpStep(
        'We decide',
        'A full refund, a split between you and the partner, or release of the payment to the partner. We tell you both.',
      ),
    ],
    related: ['escrow', 'refunds'],
  ),
  HelpDoc(
    id: 'vet-check',
    topic: HelpTopic.buying,
    title: 'The 72 hour vet check after a puppy sale',
    summary: 'What qualifies for a full refund',
    popular: true,
    intro:
        'After you collect a puppy, you have 72 hours to get a vet to check them. The seller is paid after that window, if there is no problem.',
    steps: [
      HelpStep('Collect your puppy', 'The seller confirms the handover in the app.'),
      HelpStep(
        'See a vet within 72 hours',
        'A vet found through OurPawPass can add the result to the passport with a Vet verified badge.',
      ),
      HelpStep(
        'Report a health problem',
        'A health problem confirmed by a vet in that time qualifies for a full refund.',
      ),
    ],
    callout:
        'Report the problem inside the 72 hours. After that, the seller is paid.',
    related: ['buying', 'escrow'],
  ),
  HelpDoc(
    id: 'buying',
    topic: HelpTopic.buying,
    title: 'Buying a puppy safely',
    summary: 'Deposit, balance and the passport',
    intro:
        'Puppies are sold only by verified breeders and shelters. Your money stays in escrow until the check window has passed.',
    steps: [
      HelpStep(
        'Pay the deposit',
        'A third of the price, plus a small protection fee. It is held in escrow.',
      ),
      HelpStep('Collect and pay the balance', 'You pay the rest when you meet your puppy.'),
      HelpStep(
        'Accept the passport',
        'The passport moves to you. The previous owner keeps a read only record.',
      ),
    ],
    related: ['vet-check', 'adopting'],
  ),
  HelpDoc(
    id: 'adopting',
    topic: HelpTopic.buying,
    title: 'Adopting from a shelter',
    summary: 'Applications, home visits and handover',
    intro:
        'Shelters check that a home is right before they approve an adoption. You apply in the app and the shelter replies there.',
    steps: [
      HelpStep(
        'Apply',
        'Tell the shelter about your home, other pets and who is at home in the day.',
      ),
      HelpStep(
        'Home visit',
        'The shelter may ask to visit, and will message you in the app to arrange it.',
      ),
      HelpStep(
        'Handover',
        'When you collect your pet, the passport is transferred to you.',
      ),
    ],
    related: ['buying'],
  ),
  HelpDoc(
    id: 'passport',
    topic: HelpTopic.passport,
    title: 'What is a Pet Passport?',
    summary: 'Identity, health records and history in one place',
    intro:
        'Every pet gets one Pet Passport. It holds their identity, vaccines and treatments, vet visits, origin and ownership history.',
    steps: [
      HelpStep('Add records', 'Photograph or type in vaccines and treatments. We set reminders for the next ones.'),
      HelpStep('Records from vets', 'A record added by a verified vet gets a Vet verified badge.'),
      HelpStep('Keep it private', 'Records are private by default. Only you see them unless you share.'),
    ],
    related: ['sharing'],
  ),
  HelpDoc(
    id: 'sharing',
    topic: HelpTopic.passport,
    title: "Sharing your pet's passport safely",
    summary: 'Links and QR codes that expire',
    popular: true,
    intro:
        "Open your pet's passport and choose Share with vet. You get a link and a QR code that stop working after the time you choose.",
    steps: [
      HelpStep('Choose what a vet sees', 'Health records, origin and parents, and whether the vet may add records.'),
      HelpStep('Choose how long', 'From 1 hour to 7 days. After that the link stops working.'),
      HelpStep('Stop early', 'Open Privacy and sharing, then Stop sharing. The link stops working at once.'),
    ],
    related: ['passport'],
  ),
  HelpDoc(
    id: 'booking',
    topic: HelpTopic.booking,
    title: 'Booking a vet, groomer, trainer or boarding',
    summary: 'Pick a time, pay, and the passport is shared',
    intro:
        'Choose a verified provider, pick a free time and pay. Your payment is held until you confirm the visit.',
    steps: [
      HelpStep('Pick a time', 'Only free times are shown. If someone books it first, we show you what is free now.'),
      HelpStep('Pay', 'Card, bank transfer or USSD on Paystack.'),
      HelpStep('Go to the visit', 'After the visit, confirm it. Then the provider is paid.'),
    ],
    related: ['escrow', 'refunds'],
  ),
  HelpDoc(
    id: 'lost',
    topic: HelpTopic.lost,
    title: 'What to do if your pet is lost',
    summary: 'Alerts, chat and Lost mode',
    popular: true,
    intro:
        'Report your pet as lost from Community. People near where your pet was last seen are told, without your phone number.',
    steps: [
      HelpStep('Report them lost', 'Add a photo, where and when, and anything that helps.'),
      HelpStep('People nearby are told', 'The alert reaches people within 5 km by default, and closes after 14 days.'),
      HelpStep('Chat safely', 'Finders message you in the app. Your number stays hidden.'),
    ],
    callout: 'If your pet has a QR tag, it switches to Lost mode when you report them.',
    related: ['qr-tags'],
  ),
  HelpDoc(
    id: 'qr-tags',
    topic: HelpTopic.lost,
    title: 'How QR tags work',
    summary: 'A collar tag anyone can scan',
    intro:
        'A QR tag goes on your pet\'s collar. Anyone who scans it can message you through OurPawPass, and your number stays hidden.',
    steps: [
      HelpStep('Order a tag', 'Open Me, then QR tags. Pick your pet, a colour and where to deliver it.'),
      HelpStep('We ship it', 'Delivery in Lagos takes 2 to 4 days. We tell you when it is on its way.'),
      HelpStep('Put it on the collar', 'If your pet is ever lost, report them and the tag switches to Lost mode.'),
    ],
    related: ['lost'],
  ),
  HelpDoc(
    id: 'become-partner',
    topic: HelpTopic.partners,
    title: 'Becoming a partner',
    summary: 'Verify your business in about ten minutes',
    intro:
        'Vets, groomers, trainers, boarding, breeders and shelters can apply in the app. You cannot go live until we approve you.',
    steps: [
      HelpStep('Apply', 'Open Me, then Become a partner. Tell us about your business.'),
      HelpStep('Upload your documents', 'We check your business and, for vets, your licence.'),
      HelpStep('We review', 'We aim to decide within 48 hours. We may ask for more information.'),
    ],
    related: ['payouts'],
  ),
  HelpDoc(
    id: 'payouts',
    topic: HelpTopic.partners,
    title: 'When partners are paid',
    summary: 'Payouts run every Monday',
    intro:
        'Partners are paid every Monday for visits that owners have confirmed, minus the OurPawPass commission.',
    steps: [
      HelpStep('Owner confirms', 'The money moves from held to ready.'),
      HelpStep('Monday payout', 'Ready money is sent to your bank account.'),
      HelpStep('Disputes', 'If an owner reports a problem, that payment waits until our team decides.'),
    ],
    related: ['become-partner'],
  ),
];

HelpDoc? helpDocById(String id) {
  for (final d in helpDocs) {
    if (d.id == id) {
      return d;
    }
  }
  return null;
}

/// The articles that match a search, best matches first (a title match beats a body match). An empty search
/// matches nothing here; callers show the topic list instead.
List<HelpDoc> searchHelp(String query, {Iterable<HelpDoc> docs = helpDocs}) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) {
    return const [];
  }
  final scored = <(HelpDoc, int)>[];
  for (final d in docs) {
    final title = d.title.toLowerCase();
    final text = d.searchText;
    if (!words.every(text.contains)) {
      continue;
    }
    final score = words.where(title.contains).length * 2 + 1;
    scored.add((d, score));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final s in scored) s.$1];
}

List<HelpDoc> helpForTopic(HelpTopic t) => [
  for (final d in helpDocs)
    if (d.topic == t) d,
];
