import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/app.dart';
import 'package:pawpass/features/adopt/data/in_memory_adopt.dart';
import 'package:pawpass/features/booking/data/in_memory_bookings.dart';
import 'package:pawpass/features/community/data/in_memory_community.dart';
import 'package:pawpass/features/community/domain/models.dart';
import 'package:pawpass/features/health/data/in_memory_health.dart';
import 'package:pawpass/features/partner/data/in_memory_partner.dart';
import 'package:pawpass/features/health/ui/health_widgets.dart';
import 'package:pawpass/features/onboarding/data/in_memory.dart';
import 'package:pawpass/features/onboarding/data/repositories.dart';
import 'package:pawpass/features/onboarding/domain/models.dart';
import 'package:pawpass/ui/ui.dart';

final _today = DateTime.utc(2026, 11, 5, 8); // 9am in Lagos

class _Rig {
  _Rig({this.position = const (lat: 6.4474, lng: 3.4723)}) {
    profiles = InMemoryProfileRepository();
    bookings = InMemoryBookingsRepository(now: () => _today);
    community = InMemoryCommunityRepository(now: () => _today);
    location = FakeLocationService(position);
    links = FakeLinkLauncher();
    photos = NoPhotoPicker();
    services = AppServices(
      auth: InMemoryAuthRepository(signedInAs: 'tolu@example.com'),
      profiles: profiles,
      pets: pets = InMemoryPetRepository(profiles: profiles, now: () => _today),
      photos: photos,
      emailApp: NoEmailApp(),
      health: InMemoryHealthRepository(now: () => _today),
      notifications: InMemoryNotificationsRepository(),
      vets: InMemoryVetsRepository(),
      location: location,
      links: links,
      bookings: bookings,
      payments: InMemoryPaymentsRepository(bookings),
      community: community,
      adopt: InMemoryAdoptRepository(),
      partner: InMemoryPartnerRepository(),
      now: () => _today,
    );
  }

  final ({double lat, double lng})? position;
  late final InMemoryProfileRepository profiles;
  late final InMemoryPetRepository pets;
  late final InMemoryBookingsRepository bookings;
  late final InMemoryCommunityRepository community;
  late final FakeLocationService location;
  late final FakeLinkLauncher links;
  late final NoPhotoPicker photos;
  late final AppServices services;

  Future<void> seed() async {
    await profiles.save(firstName: 'Tolu', lastName: 'Adeyemi', area: 'Lekki');
    profiles.markOnboarded(_today);
    final bingo = await pets.createPassport(
      pet: PetInput(
        name: 'Bingo',
        species: Species.dog,
        breed: 'Boerboel',
        sex: PetSex.male,
        dateOfBirth: DateTime(2024, 8, 14),
      ),
      records: const [],
      channels: {ReminderChannel.push},
    );
    final mimi = await pets.createPassport(
      pet: PetInput(
        name: 'Mimi',
        species: Species.cat,
        breed: 'Tabby',
        sex: PetSex.female,
        dateOfBirth: DateTime(2025, 11, 5),
      ),
      records: const [],
      channels: {ReminderChannel.push},
    );
    community.knowMyPets([bingo, mimi]);
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Rig rig, {
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  await rig.seed();
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
      child: PawPassApp(services: rig.services),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text, {bool last = false}) async {
  expect(
    find.text(text),
    findsWidgets,
    reason: 'Could not find "$text" on screen',
  );
  final f = last ? find.text(text).last : find.text(text).first;
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Finder _icon(String label) => find.byWidgetPredicate(
  (w) => w is RoundIconButton && w.semanticLabel.startsWith(label),
);

Future<void> _tapIcon(WidgetTester tester, String label) async {
  await tester.tap(_icon(label).first);
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byType(PawBackButton).first);
  await tester.pumpAndSettle();
}

Future<void> _toCommunity(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(PawTabBar),
      matching: find.text('Community'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    120,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  group('Community feed', () {
    testWidgets(
      'shows posts with who, where and how long ago, and a lost pet near you',
      (tester) async {
        await _pump(tester, _Rig());
        await _toCommunity(tester);
        expect(find.text('Community'), findsWidgets);
        expect(find.text('LOST NEAR YOU'), findsOneWidget);
        expect(find.textContaining('Bruno · Jack Russell dog'), findsOneWidget);
        expect(find.text("I've seen Bruno"), findsOneWidget);
        expect(find.text('Luna · Persian cat'), findsOneWidget);
        expect(find.text('Kemi · Yaba · 1h'), findsOneWidget);
        expect(
          find.textContaining('Luna has claimed the new sofa'),
          findsOneWidget,
        );
        expect(find.text('Rex & Tiger · German Shepherd dog'), findsOneWidget);
        expect(find.text('Chidi · Ikeja · 3h'), findsOneWidget);
      },
    );

    testWidgets('Near me shows posts from your area only', (tester) async {
      await _pump(tester, _Rig());
      await _toCommunity(tester);
      await _tap(tester, 'Near me');
      expect(find.textContaining('good groomer around Lekki'), findsOneWidget);
      expect(find.textContaining('Luna has claimed'), findsNothing);
    });

    testWidgets('liking is immediate and counts', (tester) async {
      await _pump(tester, _Rig());
      await _toCommunity(tester);
      expect(find.bySemanticsLabel('Like, 2 likes'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Like, 2 likes'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Unlike, 3 likes'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Unlike, 3 likes'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Like, 2 likes'), findsOneWidget);
    });

    testWidgets('following a pet from its post', (tester) async {
      await _pump(tester, _Rig());
      await _toCommunity(tester);
      await tester.tap(find.bySemanticsLabel('Follow Luna'));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Following Luna, tap to unfollow'),
        findsOneWidget,
      );
    });

    testWidgets('a load failure offers to try again', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      rig.community.failNextFeed = const AppFailure(
        'No connection. Check your internet and try again.',
      );
      await _toCommunity(tester);
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );
      await _tap(tester, 'Try again');
      expect(find.text('Luna · Persian cat'), findsOneWidget);
    });

    testWidgets('reporting a post, and blocking its author', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _toCommunity(tester);
      await tester.tap(find.byTooltip('More about this post').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report this post'));
      await tester.pumpAndSettle();
      expect(find.text('Report this'), findsOneWidget);
      expect(
        find.text(
          'Reports are anonymous. Our team reviews them within 24 hours.',
        ),
        findsOneWidget,
      );
      expect(find.text('Scam or fake seller'), findsOneWidget);
      PawButton send() => tester.widget<PawButton>(find.byType(PawButton).last);
      expect(send().onPressed, isNull, reason: 'a reason is needed first');
      await _tap(tester, 'Scam or fake seller');
      await _tap(tester, 'Also block this account');
      await _tap(tester, 'Send report');
      expect(find.text('Thank you. We will look into it.'), findsOneWidget);
      expect(rig.community.reports.single.reason, ReportReason.scam);
      expect(rig.community.reports.single.block, isTrue);
      expect(
        find.textContaining('Luna has claimed'),
        findsNothing,
        reason: 'the blocked author is gone',
      );
    });
  });

  group('New post', () {
    testWidgets('Post waits for words or a photo, then shows at the top', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _toCommunity(tester);
      await _tapIcon(tester, 'New post');
      expect(find.text('Posting as'.toUpperCase()), findsOneWidget);
      expect(find.text('Bingo'), findsOneWidget);
      PawButton post() =>
          tester.widget<PawButton>(find.widgetWithText(PawButton, 'Post'));
      expect(post().onPressed, isNull);
      await tester.enterText(
        find.byType(TextField),
        'Sunday walk at Lekki Conservation Centre.',
      );
      await tester.pump();
      expect(post().onPressed, isNotNull);
      expect(find.text('Show area (Lekki) on post'), findsOneWidget);
      await _tap(tester, 'Post');
      expect(
        find.textContaining('Sunday walk at Lekki Conservation Centre.'),
        findsOneWidget,
      );
      expect(find.text('Bingo · Boerboel dog'), findsOneWidget);
      expect(find.text('Tolu · Lekki · just now'), findsOneWidget);
    });

    testWidgets('a rule broken is explained and the text stays', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _toCommunity(tester);
      await _tapIcon(tester, 'New post');
      await tester.enterText(find.byType(TextField), 'Just for followers');
      await _tap(tester, 'Me');
      await _tap(tester, 'Followers');
      await _tap(tester, 'Post');
      expect(
        find.text('Followers see posts about a pet. Choose a pet to post as.'),
        findsOneWidget,
      );
      expect(find.text('Just for followers'), findsOneWidget);
    });

    testWidgets('a failure keeps the form', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _toCommunity(tester);
      await _tapIcon(tester, 'New post');
      await tester.enterText(find.byType(TextField), 'Hello');
      rig.community.failNextCreatePost = const AppFailure(
        'No connection. Check your internet and try again.',
      );
      await _tap(tester, 'Post');
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('photos: up to four, removable', (tester) async {
      final rig = _Rig();
      rig.photos.next = PickedPhoto(Uint8List.fromList(List.filled(8, 1)));
      await _pump(tester, rig);
      await _toCommunity(tester);
      await _tapIcon(tester, 'New post');
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('add-photo')));
        await tester.pumpAndSettle();
      }
      expect(
        find.byKey(const Key('add-photo')),
        findsNothing,
        reason: 'four is the limit',
      );
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is RoundIconButton && w.semanticLabel == 'Remove photo 1',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add-photo')), findsOneWidget);
      PawButton post() =>
          tester.widget<PawButton>(find.widgetWithText(PawButton, 'Post'));
      expect(post().onPressed, isNotNull, reason: 'a photo alone is enough');
    });

    testWidgets('Cancel goes back', (tester) async {
      await _pump(tester, _Rig());
      await _toCommunity(tester);
      await _tapIcon(tester, 'New post');
      await _tap(tester, 'Cancel');
      expect(find.text('Luna · Persian cat'), findsOneWidget);
    });
  });

  group('Pet profile', () {
    testWidgets(
      'shows identity, counts and the privacy note, and can be followed',
      (tester) async {
        await _pump(tester, _Rig());
        await _toCommunity(tester);
        await _tap(tester, 'Luna · Persian cat');
        expect(find.text("Luna's profile"), findsOneWidget);
        expect(
          find.text('Persian cat · 3 yrs · Yaba · with Kemi'),
          findsOneWidget,
        );
        expect(find.text('1.2k'), findsOneWidget);
        expect(find.text('86'), findsOneWidget);
        expect(
          find.text(
            'Health records stay private. Only the owner can share them.',
          ),
          findsOneWidget,
        );
        await _tap(tester, 'Follow');
        expect(find.text('Following'), findsWidgets);
        expect(find.text('1.2k'), findsOneWidget);
        await _back(tester);
        expect(find.text('Community'), findsWidgets);
      },
    );

    testWidgets('your own pet has no Follow button', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _toCommunity(tester);
      await _tapIcon(tester, 'New post');
      await tester.enterText(find.byType(TextField), 'Mine');
      await _tap(tester, 'Post');
      await _tap(tester, 'Bingo · Boerboel dog');
      expect(find.text("Bingo's profile"), findsOneWidget);
      expect(find.text('Follow'), findsNothing);
    });
  });

  group('Lost and found', () {
    testWidgets('the Lost & found tab lists alerts and offers to report one', (
      tester,
    ) async {
      await _pump(tester, _Rig());
      await _toCommunity(tester);
      await _tap(tester, 'Lost & found');
      expect(find.text('Report a lost pet'), findsOneWidget);
      expect(find.textContaining('Bruno · Jack Russell dog'), findsOneWidget);
      expect(
        find.textContaining(
          'Last seen 2 hrs ago · Admiralty Way, Lekki Phase 1',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('1.2 km away'), findsOneWidget);
    });

    testWidgets('reporting a lost pet needs a place, then raises the alert', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _toCommunity(tester);
      await _tap(tester, 'Lost & found');
      await _tap(tester, 'Report a lost pet');
      expect(find.text('Report a lost pet'), findsWidgets);
      PawButton send() => tester.widget<PawButton>(
        find.widgetWithText(PawButton, 'Send lost-pet alert'),
      );
      expect(send().onPressed, isNull);
      await tester.enterText(
        find.byType(TextField).first,
        'Admiralty Way, Lekki Phase 1',
      );
      await _tap(tester, 'Use my current location');
      expect(find.text('Location set · tap to update'), findsOneWidget);
      expect(send().onPressed, isNotNull);
      await _reveal(tester, '10 km');
      await _tap(tester, '10 km');
      await _tap(tester, 'Send lost-pet alert');
      expect(find.text('Bingo is missing'), findsOneWidget);
      expect(
        find.textContaining('Your alert is live. 12 people nearby were told.'),
        findsOneWidget,
      );
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Mark Bingo as found'), findsOneWidget);
    });

    testWidgets('without location the form explains what to do', (
      tester,
    ) async {
      final rig = _Rig(position: null);
      await _pump(tester, rig);
      await _toCommunity(tester);
      await _tap(tester, 'Lost & found');
      await _tap(tester, 'Report a lost pet');
      await _tap(tester, 'Use my current location');
      expect(
        find.textContaining('We could not get your location'),
        findsOneWidget,
      );
      PawButton send() => tester.widget<PawButton>(
        find.widgetWithText(PawButton, 'Send lost-pet alert'),
      );
      expect(send().onPressed, isNull);
    });

    testWidgets('as the owner: mark found closes the alert', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _toCommunity(tester);
      await _tap(tester, 'Lost & found');
      await _tap(tester, 'Report a lost pet');
      await tester.enterText(find.byType(TextField).first, 'Lekki');
      await _tap(tester, 'Use my current location');
      await _tap(tester, 'Send lost-pet alert');
      await _tap(tester, 'Mark Bingo as found');
      expect(
        find.text('So glad you found them. The alert is closed.'),
        findsOneWidget,
      );
      expect(find.textContaining('Bingo · Boerboel'), findsNothing);
    });

    testWidgets(
      'as a finder: the alert, a sighting, and a message to the owner',
      (tester) async {
        final rig = _Rig();
        await _pump(tester, rig);
        await _toCommunity(tester);
        await _tap(tester, 'Lost & found');
        await _tap(tester, 'Bruno · Jack Russell dog', last: false);
        expect(find.textContaining('LOST · 2 HRS AGO'), findsOneWidget);
        expect(find.text('Have you seen Bruno?'), findsOneWidget);
        expect(find.text('Admiralty Way, Lekki Phase 1'), findsOneWidget);
        expect(find.textContaining('"Friendly but nervous.'), findsOneWidget);
        expect(find.text('SIGHTINGS (1)'), findsOneWidget);
        expect(
          find.text('Others have shared sightings with the owner.'),
          findsOneWidget,
        );

        await _tap(tester, "I've seen Bruno · share location");
        expect(
          find.text('Thank you. The owner has been told.'),
          findsOneWidget,
        );
        expect(find.text('SIGHTINGS (2)'), findsOneWidget);
        expect(find.text('You shared a sighting'), findsOneWidget);

        await _tap(tester, 'Message owner');
        expect(find.text('Ngozi'), findsOneWidget);
        expect(find.text('About: Lost alert · Bruno'), findsOneWidget);
        expect(
          find.text(
            'Phone numbers stay hidden. Chat here, and share a location pin if it helps.',
          ),
          findsOneWidget,
        );
        await tester.enterText(
          find.byType(TextField),
          'Hi! I think I just saw Bruno near the Chevron roundabout.',
        );
        await _tapIcon(tester, 'Send message');
        expect(
          find.text(
            'Hi! I think I just saw Bruno near the Chevron roundabout.',
          ),
          findsOneWidget,
        );
        await _tapIcon(tester, 'Share my location');
        expect(find.text('Shared location'), findsOneWidget);
        await _tap(tester, 'Open in Maps');
        expect(rig.links.opened.last.host, 'www.google.com');

        // The owner writes back and it appears without leaving the screen.
        rig.community.receive(
          (await rig.community.threads()).first.id,
          'Thank you so much! I am 5 minutes away.',
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Thank you so much! I am 5 minutes away.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('a sighting without location says what to do instead', (
      tester,
    ) async {
      final rig = _Rig(position: null);
      await _pump(tester, rig);
      await _toCommunity(tester);
      await _tap(tester, 'Lost & found');
      await _tap(tester, 'Bruno · Jack Russell dog');
      await _tap(tester, "I've seen Bruno · share location");
      expect(
        find.textContaining('Turn on location to share where you saw them'),
        findsOneWidget,
      );
    });

    testWidgets('an alert can be reported', (tester) async {
      await _pump(tester, _Rig());
      await _toCommunity(tester);
      await _tap(tester, 'Lost & found');
      await _tap(tester, 'Bruno · Jack Russell dog');
      await _tap(tester, 'Report this alert');
      expect(find.text('Report this'), findsOneWidget);
    });
  });

  group('Messages', () {
    testWidgets(
      'the inbox lists conversations with unread dots, and opens them',
      (tester) async {
        final rig = _Rig();
        await _pump(tester, rig);
        final conv = await rig.community.openAlertChat('alert-bruno');
        rig.community.receive(conv, 'Are you still nearby?');
        await _toCommunity(tester);
        expect(find.bySemanticsLabel('Messages, 1 new'), findsOneWidget);
        await _tapIcon(tester, 'Messages');
        expect(find.text('Ngozi'), findsOneWidget);
        expect(find.text('Lost alert · Bruno'), findsOneWidget);
        expect(find.byKey(const Key('unread-dot')), findsOneWidget);
        expect(find.text('Are you still nearby?'), findsOneWidget);
        await _tap(tester, 'Ngozi');
        expect(
          find.textContaining('Phone numbers stay hidden'),
          findsOneWidget,
        );
        expect(find.text('Are you still nearby?'), findsOneWidget);
        await _back(tester);
        expect(find.text('Ngozi'), findsOneWidget);
        expect(
          find.byKey(const Key('unread-dot')),
          findsNothing,
          reason: 'read now',
        );
      },
    );

    testWidgets('an empty inbox explains itself', (tester) async {
      await _pump(tester, _Rig());
      await _toCommunity(tester);
      await _tapIcon(tester, 'Messages');
      expect(find.text('No messages yet'), findsOneWidget);
    });
  });

  group('every screen fits a small phone with large text', () {
    testWidgets(
      'Community, New post, Pet profile, Report, Lost form, Alert, Chat, Messages',
      (tester) async {
        final rig = _Rig();
        rig.photos.next = PickedPhoto(Uint8List.fromList(List.filled(8, 1)));
        await _pump(tester, rig, size: const Size(320, 568), scale: 1.3);
        await _toCommunity(tester);
        expect(tester.takeException(), isNull);
        await _tap(tester, 'Lost & found');
        expect(tester.takeException(), isNull);
        await _tap(tester, 'Report a lost pet');
        expect(tester.takeException(), isNull);
        await _reveal(tester, 'Send lost-pet alert');
        expect(tester.takeException(), isNull);
        await _back(tester);
        await _tap(tester, 'Bruno · Jack Russell dog');
        expect(tester.takeException(), isNull);
        await _tap(tester, 'Message owner');
        expect(tester.takeException(), isNull);
        await tester.enterText(
          find.byType(TextField),
          'Hello, I think I saw him.',
        );
        await _tapIcon(tester, 'Send message');
        expect(tester.takeException(), isNull);
        await _back(tester);
        await _back(tester);
        await _tap(tester, 'For you');
        await _tapIcon(tester, 'Messages');
        expect(tester.takeException(), isNull);
        await _back(tester);
        await _tapIcon(tester, 'New post');
        await tester.tap(find.byKey(const Key('add-photo')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _tap(tester, 'Cancel');
        await _tap(tester, 'Luna · Persian cat');
        expect(tester.takeException(), isNull);
        await _back(tester);
        await tester.tap(find.byTooltip('More about this post').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Report this post'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _reveal(tester, 'Animal cruelty or neglect');
        expect(tester.takeException(), isNull);
      },
    );
  });
}
