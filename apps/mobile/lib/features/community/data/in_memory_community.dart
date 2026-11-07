import 'dart:async';

import '../../onboarding/domain/models.dart';
import '../domain/models.dart';
import 'community_repository.dart';

class _Post {
  _Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
    required this.visibility,
    this.petId,
    this.area,
    this.media = const [],
  });
  final String id;
  final String authorId;
  final String authorName;
  final String body;
  final DateTime createdAt;
  final PostVisibility visibility;
  final String? petId;
  final String? area;
  final List<String> media;
  final likes = <String>{};
  final comments = <_Comment>[];
}

class _Comment {
  _Comment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
    this.parentId,
  });
  final String id;
  final String authorId;
  final String authorName;
  final String body;
  final DateTime createdAt;
  final String? parentId;
  final likes = <String>{};
  var status = 'published';
}

class _Pet {
  _Pet(
    this.id,
    this.name,
    this.species,
    this.breed,
    this.ownerId,
    this.ownerName,
    this.area,
    this.ageMonths,
  );
  final String id;
  final String name;
  final String species;
  final String? breed;
  final String ownerId;
  final String ownerName;
  final String? area;
  final int? ageMonths;
}

class _Alert {
  _Alert({
    required this.id,
    required this.pet,
    required this.lastSeenAt,
    required this.address,
    required this.description,
    required this.radiusM,
  });
  final String id;
  final _Pet pet;
  final DateTime lastSeenAt;
  final String address;
  final String description;
  final int radiusM;
  String status = 'active';
  final sightings = <Sighting>[];
  var foreignSightings = 0;
}

class _Thread {
  _Thread(
    this.id,
    this.alert,
    this.otherName,
    this.createdAt, {
    required this.otherId,
    this.directPetId,
    this.directPetName,
    this.requestId,
    this.requestStatus,
    this.iRequested = false,
  });
  final String id;

  /// The lost alert this chat is about, or null for a chat that started from the community.
  final _Alert? alert;
  final String otherName;
  final String otherId;
  final String? directPetId;
  final String? directPetName;
  final String? requestId;
  String? requestStatus;
  final bool iRequested;
  final DateTime createdAt;
  final messages = <ChatMessage>[];
  final controller = StreamController<void>.broadcast();
  var lastRead = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

/// Stand in for the server: the same rules (visibility, one alert per pet, five sightings a day, blocked people)
/// so tests and the demo build behave like the real thing. The signed in person is Tolu.
class InMemoryCommunityRepository implements CommunityRepository {
  InMemoryCommunityRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now {
    final t = _now().toUtc();
    final luna = _Pet(
      'pet-luna',
      'Luna',
      'cat',
      'Persian',
      'u-kemi',
      'Kemi',
      'Yaba',
      36,
    );
    final rex = _Pet(
      'pet-rex',
      'Rex & Tiger',
      'dog',
      'German Shepherd',
      'u-chidi',
      'Chidi',
      'Ikeja',
      48,
    );
    final bruno = _Pet(
      'pet-bruno',
      'Bruno',
      'dog',
      'Jack Russell',
      'u-ngozi',
      'Ngozi',
      'Lekki',
      30,
    );
    for (final p in [luna, rex, bruno]) {
      _pets[p.id] = p;
    }
    _posts.addAll([
      _Post(
        id: 'post-luna',
        authorId: 'u-kemi',
        authorName: 'Kemi',
        petId: luna.id,
        body: 'Luna has claimed the new sofa. Grooming day tomorrow, wish her luck.',
        createdAt: t.subtract(const Duration(hours: 1)),
        visibility: PostVisibility.everyone,
        area: 'Yaba',
      )..likes.addAll({'x1', 'x2'}),
      _Post(
        id: 'post-rex',
        authorId: 'u-chidi',
        authorName: 'Chidi',
        petId: rex.id,
        body: 'Morning run done. Rex and Tiger are asleep before breakfast.',
        createdAt: t.subtract(const Duration(hours: 3)),
        visibility: PostVisibility.everyone,
        area: 'Ikeja',
      ),
      _Post(
        id: 'post-near',
        authorId: 'u-ada',
        authorName: 'Ada',
        body: 'Anyone know a good groomer around Lekki?',
        createdAt: t.subtract(const Duration(hours: 5)),
        visibility: PostVisibility.nearby,
        area: 'Lekki',
      ),
    ]);
    final alert = _Alert(
      id: 'alert-bruno',
      pet: bruno,
      lastSeenAt: t.subtract(const Duration(hours: 2)),
      address: 'Admiralty Way, Lekki Phase 1',
      description: 'Friendly but nervous. He may run if chased, so please call him gently and message me.',
      radiusM: 5000,
    )..foreignSightings = 1;
    _alerts.add(alert);
  }

  final DateTime Function() _now;
  static const meId = 'u-tolu';
  static const meName = 'Tolu';
  final _pets = <String, _Pet>{};
  final _posts = <_Post>[];
  final _alerts = <_Alert>[];
  final _threads = <_Thread>[];
  final _following = <String>{};
  final blocked = <String>{};
  var _seq = 0;

  /// Where tests and the demo say this person is.
  String myArea = 'Lekki';

  /// Pets that belong to the signed in person (the real server knows this from the database).
  void knowMyPets(Iterable<Pet> pets, {String ownerName = meName}) {
    for (final p in pets) {
      _pets[p.id] = _Pet(
        p.id,
        p.name,
        p.species.value,
        p.breed,
        meId,
        ownerName,
        myArea,
        24,
      );
    }
  }

  /// Set to make the next call of that name fail.
  AppFailure? failNextFeed;
  AppFailure? failNextCreatePost;
  AppFailure? failNextLost;
  AppFailure? failNextSend;
  AppFailure? failNextReport;
  AppFailure? failNextComment;
  AppFailure? failNextRequest;

  final reports =
      <({ReportTarget target, String id, ReportReason reason, bool block})>[];
  final sharedLocations = <({double lat, double lng})>[];

  DateTime get _t => _now().toUtc();

  T _fail<T>(AppFailure? f, void Function() clear) {
    clear();
    throw f!;
  }

  bool _visible(_Post p) {
    if (blocked.contains(p.authorId)) return false;
    if (p.authorId == meId) return true;
    return switch (p.visibility) {
      PostVisibility.everyone => true,
      PostVisibility.nearby => p.area != null && p.area == myArea,
      PostVisibility.followers =>
        p.petId != null && _following.contains(p.petId),
    };
  }

  FeedPost _card(_Post p) {
    final pet = _pets[p.petId];
    return FeedPost(
      id: p.id,
      authorUserId: p.authorId,
      authorName: p.authorName,
      body: p.body,
      createdAt: p.createdAt,
      petId: p.petId,
      petName: pet?.name,
      petSpecies: pet?.species,
      petBreed: pet?.breed,
      mediaPaths: p.media,
      area: p.area,
      likeCount: p.likes.length,
      likedByMe: p.likes.contains(meId),
      followingPet: p.petId != null && _following.contains(p.petId),
      isMine: p.authorId == meId,
      commentCount: p.comments.where(_commentShown).length,
    );
  }

  bool _commentShown(_Comment c) => c.status == 'published';

  _Post _visiblePost(String postId) => _posts.firstWhere(
    (p) => p.id == postId && _visible(p),
    orElse: () => throw const AppFailure(
      'We could not find that. It may have been removed.',
    ),
  );

  @override
  Future<FeedPost> post(String postId) async => _card(_visiblePost(postId));

  @override
  Future<List<PostComment>> comments(String postId) async {
    final p = _visiblePost(postId);
    PostComment row(_Comment c) => PostComment(
      id: c.id,
      parentId: c.parentId,
      authorUserId: c.authorId,
      authorName: c.authorName,
      body: c.body,
      createdAt: c.createdAt,
      likeCount: c.likes.length,
      likedByMe: c.likes.contains(meId),
      isMine: c.authorId == meId,
    );
    final byId = {for (final c in p.comments) c.id: c};
    return [
      for (final c in p.comments)
        if (_commentShown(c) &&
            !blocked.contains(c.authorId) &&
            (c.parentId == null ||
                (byId[c.parentId] != null && _commentShown(byId[c.parentId]!))))
          row(c),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<String> addComment(
    String postId,
    String body, {
    String? parentId,
  }) async {
    if (failNextComment != null) {
      return _fail(failNextComment, () => failNextComment = null);
    }
    final p = _visiblePost(postId);
    final text = body.trim();
    if (text.isEmpty) throw const AppFailure('Write a comment first');
    if (text.length > 1000) throw const AppFailure('That comment is too long');
    String? parent = parentId;
    if (parent != null) {
      final c = p.comments.where((c) => c.id == parent).firstOrNull;
      if (c == null || !_commentShown(c) || blocked.contains(c.authorId)) {
        throw const AppFailure('That comment is no longer there');
      }
      // Replies stay one level deep.
      parent = c.parentId ?? c.id;
    }
    final id = 'c${++_seq}';
    p.comments.add(
      _Comment(
        id: id,
        authorId: meId,
        authorName: meName,
        body: text,
        createdAt: _t.add(Duration(seconds: _seq)),
        parentId: parent,
      ),
    );
    return id;
  }

  @override
  Future<void> deleteComment(String commentId) async {
    for (final p in _posts) {
      final c = p.comments.where((c) => c.id == commentId).firstOrNull;
      if (c == null) continue;
      if (c.authorId != meId && p.authorId != meId) {
        throw const AppFailure('You can only remove your own comments');
      }
      c.status = 'removed';
      return;
    }
    throw const AppFailure('We could not find that. It may have been removed.');
  }

  @override
  Future<({bool liked, int count})> toggleCommentLike(String commentId) async {
    for (final p in _posts.where(_visible)) {
      final c = p.comments.where((c) => c.id == commentId).firstOrNull;
      if (c == null || !_commentShown(c)) continue;
      final liked = !c.likes.remove(meId);
      if (liked) c.likes.add(meId);
      return (liked: liked, count: c.likes.length);
    }
    throw const AppFailure('We could not find that. It may have been removed.');
  }

  /// Test hook: how many comments a post shows.
  int postCommentCount(String postId) =>
      _posts.firstWhere((p) => p.id == postId).comments.where(_commentShown).length;

  /// Test hook: the conversation made most recently.
  String get lastConversationId => _threads.last.id;

  /// Test and demo hook: someone else comments on a post (or replies to a comment).
  String receiveComment(
    String postId,
    String body, {
    String who = 'Kemi',
    String? parentId,
  }) {
    final p = _posts.firstWhere((p) => p.id == postId);
    final parent = parentId == null
        ? null
        : (p.comments.firstWhere((c) => c.id == parentId).parentId ?? parentId);
    final id = 'c${++_seq}';
    p.comments.add(
      _Comment(
        id: id,
        authorId: 'u-${who.toLowerCase()}',
        authorName: who,
        body: body,
        createdAt: _t.add(Duration(seconds: _seq)),
        parentId: parent,
      ),
    );
    return id;
  }

  @override
  Future<List<FeedPost>> feed(FeedScope scope, {DateTime? before}) async {
    if (failNextFeed != null) {
      return _fail(failNextFeed, () => failNextFeed = null);
    }
    final list = _posts.where(_visible).where((p) {
      if (scope == FeedScope.near && !(p.area != null && p.area == myArea)) {
        return false;
      }
      return before == null || p.createdAt.isBefore(before.toUtc());
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [for (final p in list) _card(p)];
  }

  @override
  Future<({bool liked, int count})> toggleLike(String postId) async {
    final p = _posts.firstWhere(
      (p) => p.id == postId && _visible(p),
      orElse: () => throw const AppFailure(
        'We could not find that. It may have been removed.',
      ),
    );
    final liked = !p.likes.remove(meId);
    if (liked) p.likes.add(meId);
    return (liked: liked, count: p.likes.length);
  }

  @override
  Future<String> createPost({
    required String? petId,
    required String body,
    required PostVisibility visibility,
    required bool showArea,
    List<PickedPhoto> photos = const [],
  }) async {
    if (failNextCreatePost != null) {
      return _fail(failNextCreatePost, () => failNextCreatePost = null);
    }
    final text = body.trim();
    if (text.isEmpty && photos.isEmpty) {
      throw const AppFailure('Write something or add a photo');
    }
    if (text.length > 500) {
      throw const AppFailure('A post can be at most 500 characters');
    }
    if (photos.length > 4) {
      throw const AppFailure('A post can have at most 4 photos');
    }
    if (visibility == PostVisibility.followers && petId == null) {
      throw const AppFailure(
        'Followers see posts about a pet. Choose a pet to post as.',
      );
    }
    if (visibility == PostVisibility.nearby && !showArea) {
      throw const AppFailure(
        'Nearby posts need your area. Turn on "Show area" and set your area in your profile.',
      );
    }
    final id = 'post-${++_seq}';
    _posts.add(
      _Post(
        id: id,
        authorId: meId,
        authorName: meName,
        petId: petId,
        body: text,
        createdAt: _t,
        visibility: visibility,
        area: showArea ? myArea : null,
        media: [for (var i = 0; i < photos.length; i++) 'u/$id-$i.jpg'],
      ),
    );
    return id;
  }

  @override
  Future<String?> mediaUrl(String path, {bool pet = false}) async => null;

  _Pet _petFor(String id) =>
      _pets[id] ??
      (throw const AppFailure(
        'We could not find that. It may have been removed.',
      ));

  @override
  Future<PetProfileData> petProfile(String petId) async {
    final p = _petFor(petId);
    final followers =
        (p.id == 'pet-luna' ? 1200 : 3) + (_following.contains(p.id) ? 1 : 0);
    return PetProfileData(
      id: p.id,
      name: p.name,
      species: p.species,
      breed: p.breed,
      ageMonths: p.ageMonths,
      ownerUserId: p.ownerId,
      ownerName: p.ownerName,
      area: p.area,
      isMine: p.ownerId == meId,
      isFollowing: _following.contains(p.id),
      posts:
          _posts
              .where(
                (x) =>
                    x.petId == p.id && x.visibility == PostVisibility.everyone,
              )
              .length +
          (p.id == 'pet-luna' ? 47 : 0),
      followers: followers,
      following: 86,
      lost: _alerts.any((a) => a.pet.id == p.id && a.status == 'active'),
    );
  }

  @override
  Future<List<FeedPost>> petPosts(String petId) async => [
    for (final p in _posts.where((p) => p.petId == petId && _visible(p)))
      _card(p),
  ];

  @override
  Future<void> follow(String petId) async {
    if (_petFor(petId).ownerId == meId) {
      throw const AppFailure('You cannot follow your own pet.');
    }
    _following.add(petId);
  }

  @override
  Future<void> unfollow(String petId) async => _following.remove(petId);

  @override
  Future<void> shareLocation(double lat, double lng) async =>
      sharedLocations.add((lat: lat, lng: lng));

  LostAlertSummary _summary(_Alert a) => LostAlertSummary(
    alertId: a.id,
    petId: a.pet.id,
    petName: a.pet.name,
    species: a.pet.species,
    breed: a.pet.breed,
    colour: 'brown and white',
    address: a.address,
    description: a.description,
    lastSeenAt: a.lastSeenAt,
    distanceM: 1200,
    sightings: a.sightings.length + a.foreignSightings,
    isMine: a.pet.ownerId == meId,
  );

  @override
  Future<List<LostAlertSummary>> lostNearby({double? lat, double? lng}) async {
    if (failNextLost != null) {
      return _fail(failNextLost, () => failNextLost = null);
    }
    return [
      for (final a in _alerts)
        if (a.status == 'active' && !blocked.contains(a.pet.ownerId))
          _summary(a),
    ]..sort((a, b) => (b.isMine ? 1 : 0).compareTo(a.isMine ? 1 : 0));
  }

  @override
  Future<LostAlertDetail> lostDetail(
    String alertId, {
    double? lat,
    double? lng,
  }) async {
    if (failNextLost != null) {
      return _fail(failNextLost, () => failNextLost = null);
    }
    final a = _alerts.firstWhere(
      (a) => a.id == alertId,
      orElse: () => throw const AppFailure(
        'We could not find that. It may have been removed.',
      ),
    );
    final mine = a.pet.ownerId == meId;
    if (a.status != 'active' && !mine) {
      throw const AppFailure(
        'We could not find that. It may have been removed.',
      );
    }
    return LostAlertDetail(
      summary: _summary(a),
      status: a.status,
      ownerName: a.pet.ownerName,
      radiusM: a.radiusM,
      sightingCount: a.sightings.length + a.foreignSightings,
      sightings: a.sightings,
    );
  }

  @override
  Future<({String alertId, int notified})> createLostAlert({
    required String petId,
    required double lat,
    required double lng,
    required String address,
    required DateTime seenAt,
    required String description,
    required int radiusM,
  }) async {
    if (failNextLost != null) {
      return _fail(failNextLost, () => failNextLost = null);
    }
    final pet = _petFor(petId);
    if (pet.ownerId != meId) {
      throw const AppFailure(
        'We could not find that. It may have been removed.',
      );
    }
    if (!lostRadiusOptions.contains(radiusM)) {
      throw const AppFailure('Choose 2, 5 or 10 km');
    }
    if (seenAt.toUtc().isAfter(_t.add(const Duration(minutes: 5))) ||
        seenAt.toUtc().isBefore(_t.subtract(const Duration(days: 14)))) {
      throw const AppFailure(
        'When was your pet last seen? It must be in the last 14 days.',
      );
    }
    if (_alerts.any((a) => a.pet.id == petId && a.status == 'active')) {
      throw AppFailure('${pet.name} already has an active alert');
    }
    final id = 'alert-${++_seq}';
    _alerts.add(
      _Alert(
        id: id,
        pet: pet,
        lastSeenAt: seenAt.toUtc(),
        address: address,
        description: description,
        radiusM: radiusM,
      ),
    );
    return (alertId: id, notified: 12);
  }

  @override
  Future<void> reportSighting(
    String alertId, {
    required double lat,
    required double lng,
    String? note,
  }) async {
    if (failNextLost != null) {
      return _fail(failNextLost, () => failNextLost = null);
    }
    final a = _alerts.firstWhere((a) => a.id == alertId);
    if (a.status != 'active') {
      throw const AppFailure('This alert has been closed');
    }
    if (a.pet.ownerId == meId) throw const AppFailure('This is your own alert');
    if (a.sightings.length >= 5) {
      throw const AppFailure(
        'You have already shared several sightings today. Message the owner instead.',
      );
    }
    a.sightings.add(
      Sighting(id: 's${++_seq}', seenAt: _t, note: note, mine: true),
    );
  }

  @override
  Future<void> closeAlert(String alertId, {required bool found}) async {
    final a = _alerts.firstWhere((a) => a.id == alertId);
    a.status = found ? 'found' : 'closed';
  }

  _Thread _thread(String id) => _threads.firstWhere(
    (t) => t.id == id,
    orElse: () =>
        throw const AppFailure('We could not find this conversation.'),
  );

  @override
  Future<String> openAlertChat(String alertId) async {
    final a = _alerts.firstWhere(
      (a) => a.id == alertId,
      orElse: () => throw const AppFailure(
        'We could not find that. It may have been removed.',
      ),
    );
    if (a.pet.ownerId == meId) throw const AppFailure('This is your own alert');
    final existing = _threads.where((t) => t.alert?.id == alertId).firstOrNull;
    if (existing != null) return existing.id;
    if (a.status != 'active') {
      throw const AppFailure('This alert has been closed');
    }
    final t = _Thread(
      'conv-${++_seq}',
      a,
      a.pet.ownerName,
      _t,
      otherId: a.pet.ownerId,
    );
    _threads.add(t);
    return t.id;
  }

  @override
  Future<String> requestChat(String petId, String message) async {
    if (failNextRequest != null) {
      return _fail(failNextRequest, () => failNextRequest = null);
    }
    final pet = _petFor(petId);
    if (pet.ownerId == meId) throw const AppFailure('That is your own pet');
    if (blocked.contains(pet.ownerId)) {
      throw const AppFailure(
        'We could not find that. It may have been removed.',
      );
    }
    final existing = _threads
        .where((t) => t.requestId != null && t.otherId == pet.ownerId)
        .firstOrNull;
    if (existing != null) {
      if (existing.requestStatus == 'declined') {
        throw const AppFailure(
          'This person is not taking messages from you right now',
        );
      }
      return existing.id;
    }
    final text = message.trim();
    if (text.isEmpty) throw const AppFailure('Write a short message first');
    if (text.length > 500) {
      throw const AppFailure('Keep the first message under 500 characters');
    }
    final t = _Thread(
      'conv-${++_seq}',
      null,
      pet.ownerName,
      _t,
      otherId: pet.ownerId,
      directPetId: pet.id,
      directPetName: pet.name,
      requestId: 'req-$_seq',
      requestStatus: 'pending',
      iRequested: true,
    );
    t.messages.add(
      ChatMessage(
        id: 'm${++_seq}',
        mine: true,
        body: text,
        createdAt: _t.add(Duration(seconds: _seq)),
      ),
    );
    t.lastRead = t.messages.last.createdAt;
    _threads.add(t);
    return t.id;
  }

  @override
  Future<void> answerChatRequest(
    String requestId, {
    required bool accept,
  }) async {
    final t = _threads
        .where((t) => t.requestId == requestId && !t.iRequested)
        .firstOrNull;
    if (t == null) throw const AppFailure('Request not found');
    if (t.requestStatus != 'pending') {
      throw const AppFailure('You already answered this request');
    }
    t.requestStatus = accept ? 'accepted' : 'declined';
  }

  /// Test and demo hook: someone asks to chat about one of this person's pets.
  String incomingRequest(String who, String message, {String petName = 'Bingo'}) {
    final t = _Thread(
      'conv-${++_seq}',
      null,
      who,
      _t,
      otherId: 'u-${who.toLowerCase()}',
      directPetName: petName,
      requestId: 'req-$_seq',
      requestStatus: 'pending',
    );
    t.messages.add(
      ChatMessage(
        id: 'm${++_seq}',
        mine: false,
        body: message,
        createdAt: _t.add(Duration(seconds: _seq)),
      ),
    );
    _threads.add(t);
    return t.id;
  }

  /// Test and demo hook: the pet's owner answers a request this person sent.
  void answerFromOther(String conversationId, {required bool accept}) {
    _thread(conversationId).requestStatus = accept ? 'accepted' : 'declined';
  }

  @override
  Future<List<ChatThread>> threads() async => [
    for (final t in _threads.where(
      (t) => !blocked.contains(t.otherId) && t.requestStatus != 'declined',
    ))
      _threadRow(t),
  ]..sort((a, b) => b.lastAt.compareTo(a.lastAt));

  ChatThread _threadRow(_Thread t) {
    final last = t.messages.lastOrNull;
    return ChatThread(
      id: t.id,
      contextType: t.alert == null ? 'direct' : 'lost_alert',
      contextId: t.alert?.id ?? t.directPetId,
      contextLabel: t.alert == null
          ? 'About ${t.directPetName ?? 'a pet'}'
          : 'Lost alert · ${t.alert!.pet.name}',
      otherName: t.otherName,
      otherUserId: t.otherId,
      requestId: t.requestId,
      requestStatus: t.requestStatus,
      iRequested: t.iRequested,
      lastBody: last == null
          ? null
          : (last.isLocation && last.body == null
                ? 'Shared a location'
                : last.body),
      lastAt: last?.createdAt ?? t.createdAt,
      unread: t.messages
          .where((m) => !m.mine && m.createdAt.isAfter(t.lastRead))
          .length,
    );
  }

  @override
  Future<ChatThread> thread(String conversationId) async =>
      _threadRow(_thread(conversationId));

  @override
  Future<List<ChatMessage>> messages(String conversationId) async =>
      List.of(_thread(conversationId).messages);

  @override
  Future<void> sendMessage(
    String conversationId, {
    String? body,
    double? lat,
    double? lng,
  }) async {
    if (failNextSend != null) {
      return _fail(failNextSend, () => failNextSend = null);
    }
    final t = _thread(conversationId);
    final text = body?.trim();
    if ((text == null || text.isEmpty) && lat == null) {
      throw const AppFailure('Write a message first');
    }
    if ((text ?? '').length > 1000) {
      throw const AppFailure('That message is too long');
    }
    if (t.requestStatus == 'declined') {
      throw const AppFailure('This chat is closed');
    }
    if (t.requestStatus == 'pending') {
      throw AppFailure(
        t.iRequested
            ? 'Wait for them to accept your request before sending more'
            : 'Accept the request to reply',
      );
    }
    if (blocked.contains(t.otherId)) {
      throw const AppFailure('You can no longer message this person');
    }
    t.messages.add(
      ChatMessage(
        id: 'm${++_seq}',
        mine: true,
        body: text == null || text.isEmpty ? null : text,
        lat: lat,
        lng: lng,
        createdAt: _t.add(Duration(seconds: _seq)),
      ),
    );
    t.lastRead = t.messages.last.createdAt;
  }

  /// Test and demo hook: the other person writes back.
  void receive(String conversationId, String body) {
    final t = _thread(conversationId);
    t.messages.add(
      ChatMessage(
        id: 'm${++_seq}',
        mine: false,
        body: body,
        createdAt: _t.add(Duration(seconds: _seq)),
      ),
    );
    t.controller.add(null);
  }

  @override
  Future<void> markRead(String conversationId) async {
    final t = _thread(conversationId);
    t.lastRead = t.messages.isEmpty ? _t : t.messages.last.createdAt;
  }

  @override
  Stream<void> watchMessages(String conversationId) =>
      _thread(conversationId).controller.stream;

  @override
  Future<void> report(
    ReportTarget target,
    String id,
    ReportReason reason, {
    bool block = false,
  }) async {
    if (failNextReport != null) {
      return _fail(failNextReport, () => failNextReport = null);
    }
    if (reports.any((r) => r.target == target && r.id == id)) return;
    reports.add((target: target, id: id, reason: reason, block: block));
    if (block) {
      final who = switch (target) {
        ReportTarget.post =>
          _posts.where((p) => p.id == id).firstOrNull?.authorId,
        ReportTarget.comment => _posts
            .expand((p) => p.comments)
            .where((c) => c.id == id)
            .firstOrNull
            ?.authorId,
        ReportTarget.user => id,
        ReportTarget.lostAlert =>
          _alerts.where((a) => a.id == id).firstOrNull?.pet.ownerId,
      };
      if (who != null) blocked.add(who);
    }
  }
}
