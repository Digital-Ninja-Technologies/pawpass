import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/app.dart';
import 'package:pawpass/features/adopt/data/in_memory_adopt.dart';
import 'package:pawpass/features/booking/data/in_memory_bookings.dart';
import 'package:pawpass/features/community/data/in_memory_community.dart';
import 'package:pawpass/features/community/ui/post_actions.dart';
import 'package:pawpass/features/health/data/in_memory_health.dart';
import 'package:pawpass/features/partner/data/in_memory_partner.dart';
import 'package:pawpass/features/health/ui/health_widgets.dart';
import 'package:pawpass/features/onboarding/data/in_memory.dart';
import 'package:pawpass/features/onboarding/data/repositories.dart';
import 'package:pawpass/features/onboarding/domain/models.dart';
import 'package:pawpass/ui/ui.dart';

final _today = DateTime.utc(2026, 11, 5, 8); // 9am in Lagos

class _Rig {
  _Rig() {
    profiles = InMemoryProfileRepository();
    bookings = InMemoryBookingsRepository(now: () => _today);
    community = InMemoryCommunityRepository(now: () => _today);
    location = FakeLocationService((lat: 6.4474, lng: 3.4723));
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

Future<void> _openMessages(WidgetTester tester) async {
  await _toCommunity(tester);
  await _tapIcon(tester, 'Messages');
}

void main() {
  group('Comments', () {
    testWidgets('a post shows how to comment, and opens its comments', (
      tester,
    ) async {
      final rig = _Rig();
      rig.community.receiveComment('post-luna', 'She is gorgeous!', who: 'Femi');
      await _pump(tester, rig);
      await _toCommunity(tester);
      expect(find.bySemanticsLabel('Comments, 1. Open to read and reply'), findsOneWidget);
      expect(find.bySemanticsLabel('Comment on this post'), findsWidgets);
      await tester.tap(find.bySemanticsLabel('Comments, 1. Open to read and reply'));
      await tester.pumpAndSettle();
      expect(find.text('1 comment'), findsOneWidget);
      expect(find.text('She is gorgeous!'), findsOneWidget);
      expect(find.textContaining('Femi'), findsWidgets);
    });

    testWidgets('comment, reply, like and remove; the feed count follows', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _toCommunity(tester);
      await tester.tap(find.bySemanticsLabel('Comment on this post').first);
      await tester.pumpAndSettle();
      expect(find.text('No comments'), findsOneWidget);
      expect(find.text('Be the first to comment.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, '').last, 'Lovely photo');
      await tester.tap(find.bySemanticsLabel('Post comment'));
      await tester.pumpAndSettle();
      expect(find.text('1 comment'), findsOneWidget);
      expect(find.text('Lovely photo'), findsOneWidget);
      expect(find.textContaining('(you)'), findsOneWidget);

      // Reply
      await _tap(tester, 'Reply');
      expect(find.text('Replying to Tolu'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, '').last, 'Thank you');
      await tester.tap(find.bySemanticsLabel('Post reply'));
      await tester.pumpAndSettle();
      expect(find.text('2 comments'), findsOneWidget);
      expect(find.text('Thank you'), findsOneWidget);

      // Like the comment
      final likes = find.byType(LikeButtonLite);
      await tester.ensureVisible(likes.last);
      await tester.pump();
      await tester.tap(likes.last);
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);

      // Remove the top comment: the reply goes with it.
      await tester.tap(find.byTooltip('More about this comment').first);
      await tester.pumpAndSettle();
      await _tap(tester, 'Remove comment');
      await _tap(tester, 'Remove');
      expect(find.text('Lovely photo'), findsNothing);
      expect(find.text('Thank you'), findsNothing);
      expect(find.text('No comments'), findsOneWidget);

      // Back on the feed the count matches.
      await _back(tester);
      expect(find.bySemanticsLabel('Comment on this post'), findsWidgets);
    });

    testWidgets('an empty or too long comment is not sent, and a failure keeps the text', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _toCommunity(tester);
      await tester.tap(find.bySemanticsLabel('Comment on this post').first);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Post comment'));
      await tester.pumpAndSettle();
      expect(find.text('Write a comment first.'), findsOneWidget);
      expect(rig.community.postCommentCount('post-luna'), 0);

      rig.community.failNextComment = const AppFailure('No connection.');
      await tester.enterText(find.widgetWithText(TextField, '').last, 'Hello there');
      await tester.tap(find.bySemanticsLabel('Post comment'));
      await tester.pumpAndSettle();
      expect(find.text('No connection.'), findsOneWidget);
      expect(find.text('Hello there'), findsOneWidget, reason: 'the text stays');
    });

    testWidgets('someone else\'s comment can be reported, not removed', (
      tester,
    ) async {
      final rig = _Rig();
      rig.community.receiveComment('post-luna', 'Buy my stuff', who: 'Spammer');
      await _pump(tester, rig);
      await _toCommunity(tester);
      await tester.tap(find.bySemanticsLabel('Comments, 1. Open to read and reply'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More about this comment').first);
      await tester.pumpAndSettle();
      expect(find.text('Remove comment'), findsNothing);
      await _tap(tester, 'Report this comment');
      expect(find.text('Report this'), findsOneWidget);
    });

    testWidgets('a blocked person\'s comments are hidden', (tester) async {
      final rig = _Rig();
      rig.community.receiveComment('post-luna', 'Rude words', who: 'Bully');
      rig.community.blocked.add('u-bully');
      await _pump(tester, rig);
      await _toCommunity(tester);
      await tester.tap(find.bySemanticsLabel('Comment on this post').first);
      await tester.pumpAndSettle();
      expect(find.text('Rude words'), findsNothing);
    });
  });

  group('Share', () {
    testWidgets('share on WhatsApp opens a message with the app link, and copy works', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _toCommunity(tester);
      await tester.tap(find.bySemanticsLabel('Share this post').first);
      await tester.pumpAndSettle();
      expect(find.text('Share this post'), findsOneWidget);
      await _tap(tester, 'Share on WhatsApp');
      final uri = rig.links.opened.single;
      expect(uri.host, 'wa.me');
      expect(uri.queryParameters['text'], contains('Luna'));
      expect(uri.queryParameters['text'], contains('Get the app'));
      expect(uri.queryParameters['text'], isNot(contains('health')));

      await tester.tap(find.bySemanticsLabel('Share this post').first);
      await tester.pumpAndSettle();
      await _tap(tester, 'Copy');
      expect(rig.links.copied.single, contains('on OurPawPass'));
    });
  });

  group('Message requests', () {
    testWidgets('ask an owner to chat from their post, then wait for them to accept', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _toCommunity(tester);
      await tester.tap(find.byTooltip('More about this post').first);
      await tester.pumpAndSettle();
      await _tap(tester, 'Message Kemi');
      expect(find.text('Message Kemi'), findsOneWidget);
      expect(find.textContaining('has to accept before you can chat'), findsOneWidget);
      // Nothing to send until something is written.
      final send = find.widgetWithText(PawButton, 'Send request');
      expect(tester.widget<PawButton>(send).onPressed, isNull);
      await tester.enterText(find.widgetWithText(TextField, '').last, 'Hi Kemi, where did you get Luna?');
      await tester.pump();
      await tester.tap(send);
      await tester.pumpAndSettle();

      // We are in the chat: our message is there, but we cannot send more yet.
      expect(find.text('Hi Kemi, where did you get Luna?'), findsOneWidget);
      expect(find.text('About Luna'), findsOneWidget);
      expect(find.textContaining('About: About'), findsNothing);
      expect(find.textContaining('Waiting for Kemi to accept'), findsOneWidget);
      expect(find.bySemanticsLabel('Send message'), findsNothing);

      // Kemi accepts: the composer appears.
      final conv = rig.community.lastConversationId;
      rig.community.answerFromOther(conv, accept: true);
      await _back(tester);
      await _tapIcon(tester, 'Messages');
      await tester.tap(find.text('Kemi').first);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Send message'), findsOneWidget);
      expect(find.textContaining('Waiting for Kemi'), findsNothing);
    });

    testWidgets('from a pet profile, and a second tap reuses the same chat', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      final first = await rig.community.requestChat('pet-luna', 'Hello');
      final again = await rig.community.requestChat('pet-luna', 'Hello again');
      expect(again, first);
      await _toCommunity(tester);
      await tester.tap(find.text('Luna · Persian cat').first);
      await tester.pumpAndSettle();
      expect(find.text('Message Kemi'), findsOneWidget);
    });

    testWidgets('a request sent to you can be accepted, and then you can reply', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      final conv = rig.community.incomingRequest('Amaka', 'Is Bingo for adoption?');
      await _openMessages(tester);
      expect(find.text('MESSAGE REQUESTS'), findsOneWidget);
      expect(find.text('Amaka wants to message you'), findsOneWidget);
      expect(find.text('Is Bingo for adoption?'), findsOneWidget);
      await tester.tap(find.widgetWithText(PawButton, 'Accept'));
      await tester.pumpAndSettle();
      expect(find.text('MESSAGE REQUESTS'), findsNothing);
      expect(find.text('Amaka'), findsOneWidget);
      await _tap(tester, 'Amaka');
      expect(find.bySemanticsLabel('Send message'), findsOneWidget);
      expect(conv, isNotEmpty);
    });

    testWidgets('you cannot reply before accepting, and declining removes it', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      rig.community.incomingRequest('Amaka', 'Is Bingo for adoption?');
      await _openMessages(tester);
      await _tap(tester, 'Amaka wants to message you');
      expect(find.textContaining('They cannot send more until you accept'), findsOneWidget);
      expect(find.bySemanticsLabel('Send message'), findsNothing);
      await tester.tap(find.widgetWithText(PawButton, 'Decline'));
      await tester.pumpAndSettle();
      // Back in the inbox, the request is gone.
      expect(find.text('Amaka wants to message you'), findsNothing);
      expect(find.text('No messages yet'), findsOneWidget);
    });

    testWidgets('a declined request cannot be sent again', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      final conv = await rig.community.requestChat('pet-luna', 'Hello');
      rig.community.answerFromOther(conv, accept: false);
      expect(
        () => rig.community.requestChat('pet-luna', 'Please?'),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => rig.community.sendMessage(conv, body: 'hi'),
        throwsA(isA<AppFailure>()),
      );
    });

    testWidgets('you cannot message your own pet, or use an empty first message', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      final bingo = (await rig.pets.myPets()).first;
      expect(
        () => rig.community.requestChat(bingo.id, 'Hello'),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => rig.community.requestChat('pet-luna', '   '),
        throwsA(isA<AppFailure>()),
      );
    });
  });
}
