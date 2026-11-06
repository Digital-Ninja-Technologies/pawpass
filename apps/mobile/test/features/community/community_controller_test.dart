import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/features/community/data/in_memory_community.dart';
import 'package:pawpass/features/community/domain/models.dart';
import 'package:pawpass/features/community/state/chat_controller.dart';
import 'package:pawpass/features/community/state/community_controller.dart';
import 'package:pawpass/features/community/state/lost_controller.dart';
import 'package:pawpass/features/health/data/in_memory_health.dart';
import 'package:pawpass/features/onboarding/data/in_memory.dart';
import 'package:pawpass/features/onboarding/data/repositories.dart';
import 'package:pawpass/features/onboarding/domain/models.dart';
import 'package:pawpass/features/onboarding/state/session_controller.dart';

final _today = DateTime.utc(2026, 11, 5, 8);

class _Rig {
  _Rig({({double lat, double lng})? at = (lat: 6.4474, lng: 3.4723)}) {
    services = inMemoryServices(
      now: () => _today,
      signedInAs: 'tolu@example.com',
    );
    repo = services.community as InMemoryCommunityRepository;
    (services.location as FakeLocationService).position = at;
    session = SessionController(services);
    community = CommunityController(services, session);
    lost = LostController(services, session);
    chat = ChatController(services, session);
  }

  late final AppServices services;
  late final InMemoryCommunityRepository repo;
  late final SessionController session;
  late final CommunityController community;
  late final LostController lost;
  late final ChatController chat;
}

void main() {
  group('feed', () {
    test('for you shows everything visible, newest first', () async {
      final r = _Rig();
      await r.community.load();
      expect(r.community.posts.map((p) => p.id), [
        'post-luna',
        'post-rex',
        'post-near',
      ]);
      expect(r.community.posts.first.authorName, 'Kemi');
      expect(r.community.posts.first.petName, 'Luna');
      expect(r.community.posts.first.likeCount, 2);
    });

    test('near me is posts from your own area', () async {
      final r = _Rig();
      await r.community.setScope(FeedScope.near);
      expect(r.community.posts.map((p) => p.id), ['post-near']);
    });

    test('a load failure is kept and can be retried', () async {
      final r = _Rig();
      r.repo.failNextFeed = const AppFailure('No connection.');
      await r.community.load();
      expect(r.community.error, 'No connection.');
      await r.community.load();
      expect(r.community.error, isNull);
      expect(r.community.posts, isNotEmpty);
    });

    test('liking shows at once and counts', () async {
      final r = _Rig();
      await r.community.load();
      final luna = r.community.posts.first;
      final f = r.community.toggleLike(luna);
      expect(r.community.posts.first.likedByMe, isTrue, reason: 'optimistic');
      expect(r.community.posts.first.likeCount, 3);
      await f;
      expect(r.community.posts.first.likeCount, 3);
      await r.community.toggleLike(r.community.posts.first);
      expect(r.community.posts.first.likedByMe, isFalse);
      expect(r.community.posts.first.likeCount, 2);
    });

    test('a like on a post that has gone is put back with a message', () async {
      final r = _Rig();
      await r.community.load();
      final gone = FeedPost(
        id: 'missing',
        authorUserId: 'x',
        authorName: 'X',
        body: '',
        createdAt: _today,
        likeCount: 1,
      );
      r.community.posts = [gone];
      await r.community.toggleLike(gone);
      expect(r.community.posts.single.likedByMe, isFalse);
      expect(r.community.posts.single.likeCount, 1);
      expect(r.community.actionError, contains('could not find'));
    });

    test('following a pet updates every post of that pet', () async {
      final r = _Rig();
      await r.community.load();
      await r.community.toggleFollow('pet-luna', currentlyFollowing: false);
      expect(
        r.community.posts.firstWhere((p) => p.petId == 'pet-luna').followingPet,
        isTrue,
      );
      await r.community.toggleFollow('pet-luna', currentlyFollowing: true);
      expect(
        r.community.posts.firstWhere((p) => p.petId == 'pet-luna').followingPet,
        isFalse,
      );
    });

    test('you cannot follow your own pet', () async {
      final r = _Rig();
      r.repo.knowMyPets([
        Pet(id: 'mine', name: 'Bingo', species: Species.dog, sex: PetSex.male),
      ]);
      await r.community.toggleFollow('mine', currentlyFollowing: false);
      expect(r.community.actionError, 'You cannot follow your own pet.');
    });
  });

  group('posting', () {
    test('a post appears at the top of the feed', () async {
      final r = _Rig();
      await r.community.load();
      expect(
        await r.community.createPost(
          petId: null,
          body: 'Sunday walk',
          visibility: PostVisibility.everyone,
          showArea: true,
        ),
        isTrue,
      );
      expect(r.community.posts.first.body, 'Sunday walk');
      expect(r.community.posts.first.isMine, isTrue);
      expect(r.community.posts.first.area, 'Lekki');
    });

    test('the area can be left off', () async {
      final r = _Rig();
      await r.community.createPost(
        petId: null,
        body: 'No area',
        visibility: PostVisibility.everyone,
        showArea: false,
      );
      expect(
        r.community.posts.firstWhere((p) => p.body == 'No area').area,
        isNull,
      );
    });

    test('rules are explained, not hidden', () async {
      final r = _Rig();
      Future<String?> try_({
        String body = 'x',
        String? pet,
        PostVisibility v = PostVisibility.everyone,
        bool area = true,
        int photos = 0,
      }) async {
        await r.community.createPost(
          petId: pet,
          body: body,
          visibility: v,
          showArea: area,
          photos: [for (var i = 0; i < photos; i++) PickedPhoto(Uint8List(2))],
        );
        return r.community.postError;
      }

      expect(await try_(body: '  '), 'Write something or add a photo');
      expect(
        await try_(body: 'a' * 501),
        'A post can be at most 500 characters',
      );
      expect(await try_(photos: 5), 'A post can have at most 4 photos');
      expect(await try_(v: PostVisibility.followers), contains('Choose a pet'));
      expect(
        await try_(v: PostVisibility.nearby, area: false),
        contains('Show area'),
      );
      expect(
        await try_(body: '', photos: 1),
        isNull,
        reason: 'a photo alone is a post',
      );
    });

    test('a failed post keeps the form and says why', () async {
      final r = _Rig();
      r.repo.failNextCreatePost = const AppFailure('No connection.');
      expect(
        await r.community.createPost(
          petId: null,
          body: 'x',
          visibility: PostVisibility.everyone,
          showArea: true,
        ),
        isFalse,
      );
      expect(r.community.postError, 'No connection.');
      expect(r.community.posting, isFalse);
    });
  });

  group('profiles and reports', () {
    test('a pet profile has counts and posts', () async {
      final r = _Rig();
      await r.community.loadProfile('pet-luna');
      final p = r.community.profile!;
      expect(p.name, 'Luna');
      expect(p.ownerName, 'Kemi');
      expect(p.followers, 1200);
      expect(p.isFollowing, isFalse);
      expect(r.community.profilePosts.single.id, 'post-luna');
      await r.community.toggleFollow('pet-luna', currentlyFollowing: false);
      expect(r.community.profile!.isFollowing, isTrue);
      expect(r.community.profile!.followers, 1201);
    });

    test('an unknown profile says so', () async {
      final r = _Rig();
      await r.community.loadProfile('nope');
      expect(r.community.profile, isNull);
      expect(r.community.profileError, contains('could not find'));
    });

    test(
      'reporting with "also block" removes that person from the feed',
      () async {
        final r = _Rig();
        await r.community.load();
        expect(
          await r.community.report(
            ReportTarget.post,
            'post-rex',
            ReportReason.scam,
            block: true,
          ),
          isTrue,
        );
        expect(
          r.community.posts.any((p) => p.authorUserId == 'u-chidi'),
          isFalse,
        );
        expect(r.repo.reports.single.reason, ReportReason.scam);
      },
    );

    test('reporting without blocking keeps the feed', () async {
      final r = _Rig();
      await r.community.load();
      await r.community.report(
        ReportTarget.post,
        'post-rex',
        ReportReason.spam,
      );
      expect(r.community.posts.any((p) => p.id == 'post-rex'), isTrue);
    });

    test('a failed report can be sent again', () async {
      final r = _Rig();
      r.repo.failNextReport = const AppFailure('No connection.');
      expect(
        await r.community.report(
          ReportTarget.post,
          'post-rex',
          ReportReason.spam,
        ),
        isFalse,
      );
      expect(r.community.reportError, 'No connection.');
      expect(
        await r.community.report(
          ReportTarget.post,
          'post-rex',
          ReportReason.spam,
        ),
        isTrue,
      );
    });

    test('signing out forgets the feed', () async {
      final r = _Rig();
      await r.community.load();
      r.community.reset();
      expect(r.community.posts, isEmpty);
      expect(r.community.loaded, isFalse);
    });
  });

  group('lost pets', () {
    test(
      'lists active alerts and tells the server where the phone is',
      () async {
        final r = _Rig();
        await r.lost.load();
        expect(r.lost.alerts.single.petName, 'Bruno');
        expect(r.lost.alerts.single.sightings, 1);
        expect(r.repo.sharedLocations.single.lat, 6.4474);
      },
    );

    test('without location the list still loads', () async {
      final r = _Rig(at: null);
      await r.lost.load();
      expect(r.lost.alerts, hasLength(1));
      expect(r.repo.sharedLocations, isEmpty);
    });

    test('a finder shares a sighting from where they stand', () async {
      final r = _Rig();
      await r.lost.loadDetail('alert-bruno');
      expect(
        r.lost.detail!.sightings,
        isEmpty,
        reason: 'others\' sightings are not shown',
      );
      expect(r.lost.detail!.sightingCount, 1);
      expect(await r.lost.shareSighting('alert-bruno'), isTrue);
      expect(r.lost.detail!.sightingCount, 2);
      expect(r.lost.detail!.sightings.single.mine, isTrue);
      expect(r.lost.notice, 'Thank you. The owner has been told.');
    });

    test('a sighting needs location, and says what to do instead', () async {
      final r = _Rig(at: null);
      await r.lost.loadDetail('alert-bruno');
      expect(await r.lost.shareSighting('alert-bruno'), isFalse);
      expect(r.lost.actionError, contains('Turn on location'));
    });

    test('raising an alert needs a place first', () async {
      final r = _Rig();
      final id = await r.lost.raise(
        petId: 'x',
        address: 'a',
        seenAt: _today,
        description: '',
        radiusM: 5000,
      );
      expect(id, isNull);
      expect(r.lost.sendError, 'Choose where your pet was last seen.');
    });

    test('raising an alert tells how many people were notified, and lists it first', () async {
      final r = _Rig();
      r.repo.knowMyPets([
        Pet(id: 'bingo', name: 'Bingo', species: Species.dog, sex: PetSex.male),
      ]);
      await r.lost.useMyLocation();
      final id = await r.lost.raise(
        petId: 'bingo',
        address: 'Admiralty Way',
        seenAt: _today.subtract(const Duration(hours: 2)),
        description: 'Red collar',
        radiusM: 5000,
      );
      expect(id, isNotNull);
      expect(r.lost.lastNotified, 12);
      expect(r.lost.alerts.first.petName, 'Bingo');
      expect(r.lost.alerts.first.isMine, isTrue);
      expect(r.lost.spot, isNull, reason: 'the form is ready for next time');
    });

    test('one active alert per pet', () async {
      final r = _Rig();
      r.repo.knowMyPets([
        Pet(id: 'bingo', name: 'Bingo', species: Species.dog, sex: PetSex.male),
      ]);
      await r.lost.useMyLocation();
      await r.lost.raise(
        petId: 'bingo',
        address: 'a',
        seenAt: _today,
        description: '',
        radiusM: 5000,
      );
      await r.lost.useMyLocation();
      expect(
        await r.lost.raise(
          petId: 'bingo',
          address: 'a',
          seenAt: _today,
          description: '',
          radiusM: 5000,
        ),
        isNull,
      );
      expect(r.lost.sendError, 'Bingo already has an active alert');
    });

    test('only 2, 5 or 10 km, and only the last two weeks', () async {
      final r = _Rig();
      r.repo.knowMyPets([
        Pet(id: 'bingo', name: 'Bingo', species: Species.dog, sex: PetSex.male),
      ]);
      await r.lost.useMyLocation();
      await r.lost.raise(
        petId: 'bingo',
        address: 'a',
        seenAt: _today,
        description: '',
        radiusM: 3000,
      );
      expect(r.lost.sendError, 'Choose 2, 5 or 10 km');
      await r.lost.raise(
        petId: 'bingo',
        address: 'a',
        seenAt: _today.subtract(const Duration(days: 20)),
        description: '',
        radiusM: 5000,
      );
      expect(r.lost.sendError, contains('last 14 days'));
    });

    test('marking a pet found closes the alert', () async {
      final r = _Rig();
      r.repo.knowMyPets([
        Pet(id: 'bingo', name: 'Bingo', species: Species.dog, sex: PetSex.male),
      ]);
      await r.lost.useMyLocation();
      final id = (await r.lost.raise(
        petId: 'bingo',
        address: 'a',
        seenAt: _today,
        description: '',
        radiusM: 2000,
      ))!;
      expect(await r.lost.close(id, found: true), isTrue);
      expect(r.lost.alerts.any((a) => a.alertId == id), isFalse);
    });
  });

  group('chat', () {
    test('opening an alert chat twice gives the same conversation', () async {
      final r = _Rig();
      final a = await r.lost.openChat('alert-bruno');
      final b = await r.lost.openChat('alert-bruno');
      expect(a, isNotNull);
      expect(a, b);
    });

    test('you cannot chat on your own alert', () async {
      final r = _Rig();
      r.repo.knowMyPets([
        Pet(id: 'bingo', name: 'Bingo', species: Species.dog, sex: PetSex.male),
      ]);
      await r.lost.useMyLocation();
      final id = (await r.lost.raise(
        petId: 'bingo',
        address: 'a',
        seenAt: _today,
        description: '',
        radiusM: 2000,
      ))!;
      expect(await r.lost.openChat(id), isNull);
      expect(r.lost.actionError, 'This is your own alert');
    });

    test('messages, a shared location, and live replies', () async {
      final r = _Rig();
      final conv = (await r.lost.openChat('alert-bruno'))!;
      await r.chat.open(conv);
      expect(r.chat.header!.otherName, 'Ngozi');
      expect(r.chat.header!.contextLabel, 'Lost alert · Bruno');
      expect(await r.chat.send('  Hi! I think I saw Bruno.  '), isTrue);
      expect(r.chat.messages.single.body, 'Hi! I think I saw Bruno.');
      expect(r.chat.messages.single.mine, isTrue);
      expect(await r.chat.shareLocation(), isTrue);
      expect(r.chat.messages.last.isLocation, isTrue);
      expect(r.chat.messages.last.lat, 6.4474);

      r.repo.receive(conv, 'Thank you! I am 5 minutes away.');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(r.chat.messages.last.body, 'Thank you! I am 5 minutes away.');
      expect(r.chat.messages.last.mine, isFalse);
    });

    test('empty messages are not sent', () async {
      final r = _Rig();
      await r.chat.open((await r.lost.openChat('alert-bruno'))!);
      expect(await r.chat.send('   '), isFalse);
      expect(r.chat.messages, isEmpty);
    });

    test('sharing location without it says what to do', () async {
      final r = _Rig(at: null);
      await r.chat.open((await r.lost.openChat('alert-bruno'))!);
      expect(await r.chat.shareLocation(), isFalse);
      expect(r.chat.sendError, contains('Turn on location'));
    });

    test('a failed send keeps the text for another go', () async {
      final r = _Rig();
      await r.chat.open((await r.lost.openChat('alert-bruno'))!);
      r.repo.failNextSend = const AppFailure('Your message was not sent.');
      expect(await r.chat.send('hello'), isFalse);
      expect(r.chat.sendError, 'Your message was not sent.');
      expect(await r.chat.send('hello'), isTrue);
      expect(r.chat.sendError, isNull);
    });

    test('the inbox counts unread and clears them when opened', () async {
      final r = _Rig();
      final conv = (await r.lost.openChat('alert-bruno'))!;
      r.repo.receive(conv, 'Are you still nearby?');
      await r.chat.loadThreads();
      expect(r.chat.unread, 1);
      expect(r.chat.threads.single.lastBody, 'Are you still nearby?');
      await r.chat.open(conv);
      await r.chat.close();
      await r.chat.loadThreads();
      expect(r.chat.unread, 0);
    });

    test(
      'blocking the owner hides the conversation and stops messages',
      () async {
        final r = _Rig();
        final conv = (await r.lost.openChat('alert-bruno'))!;
        await r.chat.open(conv);
        r.repo.blocked.add('u-ngozi');
        expect(await r.chat.send('hello'), isFalse);
        expect(r.chat.sendError, 'You can no longer message this person');
        await r.chat.loadThreads();
        expect(r.chat.threads, isEmpty);
      },
    );
  });
}
