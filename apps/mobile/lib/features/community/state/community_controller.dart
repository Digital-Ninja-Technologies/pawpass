import 'package:flutter/foundation.dart';

import '../../onboarding/data/repositories.dart';
import '../../onboarding/domain/models.dart';
import '../../onboarding/state/session_controller.dart';
import '../domain/models.dart';

/// The feed, a pet's profile, posting, liking, following and reporting. Forgets everything on sign out.
class CommunityController extends ChangeNotifier {
  CommunityController(this._services, this._session) {
    _session.addListener(_onSession);
  }

  final AppServices _services;
  final SessionController _session;
  var _disposed = false;
  var _loadSeq = 0;

  DateTime get now => _services.now();

  // ------------------------------------------------------------------ feed

  FeedScope scope = FeedScope.forYou;
  List<FeedPost> posts = const [];
  bool loading = false;
  bool loaded = false;
  bool loadingMore = false;
  bool reachedEnd = false;
  String? error;
  String? actionError;

  Future<void> load() async {
    final seq = ++_loadSeq;
    loading = true;
    error = null;
    _notify();
    try {
      final result = await _services.community.feed(scope);
      if (seq != _loadSeq) return;
      posts = result;
      reachedEnd = result.length < 20;
      loaded = true;
    } on AppFailure catch (e) {
      if (seq != _loadSeq) return;
      error = e.message;
    } finally {
      if (seq == _loadSeq) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> setScope(FeedScope s) {
    scope = s;
    return load();
  }

  Future<void> loadMore() async {
    if (loadingMore || reachedEnd || posts.isEmpty) return;
    loadingMore = true;
    _notify();
    try {
      final more = await _services.community.feed(
        scope,
        before: posts.last.createdAt,
      );
      final seen = {for (final p in posts) p.id};
      posts = [
        ...posts,
        for (final p in more)
          if (!seen.contains(p.id)) p,
      ];
      reachedEnd = more.length < 20;
    } on AppFailure {
      // The list stays as it is; pulling to refresh tries again.
    } finally {
      loadingMore = false;
      _notify();
    }
  }

  void _replace(String id, FeedPost Function(FeedPost) f) {
    posts = [for (final p in posts) p.id == id ? f(p) : p];
    profilePosts = [for (final p in profilePosts) p.id == id ? f(p) : p];
  }

  /// Puts the latest copy of a post (from the comments screen) into the feed, so counts agree.
  void syncPost(FeedPost post) {
    if (!posts.any((p) => p.id == post.id)) return;
    posts = [for (final p in posts) p.id == post.id ? post : p];
    _notify();
  }

  /// Shows the like at once and puts it back if the server says no.
  Future<void> toggleLike(FeedPost post) async {
    actionError = null;
    final wasLiked = post.likedByMe;
    _replace(
      post.id,
      (p) => p.copyWith(
        likedByMe: !wasLiked,
        likeCount: p.likeCount + (wasLiked ? -1 : 1),
      ),
    );
    _notify();
    try {
      final r = await _services.community.toggleLike(post.id);
      _replace(
        post.id,
        (p) => p.copyWith(likedByMe: r.liked, likeCount: r.count),
      );
    } on AppFailure catch (e) {
      _replace(
        post.id,
        (p) => p.copyWith(likedByMe: wasLiked, likeCount: post.likeCount),
      );
      actionError = e.message;
    }
    _notify();
  }

  /// Follow or unfollow the pet in this post (and everywhere else it shows).
  Future<void> toggleFollow(
    String petId, {
    required bool currentlyFollowing,
  }) async {
    actionError = null;
    _setFollowing(petId, !currentlyFollowing);
    _notify();
    try {
      if (currentlyFollowing) {
        await _services.community.unfollow(petId);
      } else {
        await _services.community.follow(petId);
      }
    } on AppFailure catch (e) {
      _setFollowing(petId, currentlyFollowing);
      actionError = e.message;
    }
    _notify();
  }

  void _setFollowing(String petId, bool value) {
    posts = [
      for (final p in posts)
        p.petId == petId ? p.copyWith(followingPet: value) : p,
    ];
    final pr = profile;
    if (pr != null && pr.id == petId) profile = pr.withFollowing(value);
  }

  // ------------------------------------------------------------------ photos

  final Map<String, String?> _urls = {};

  /// A link for a private photo, fetched once. Returns null until it arrives or if there is none.
  String? urlFor(String? path, {bool pet = false}) {
    if (path == null) return null;
    final key = '${pet ? 'p' : 'm'}:$path';
    if (_urls.containsKey(key)) return _urls[key];
    _urls[key] = null;
    _services.community.mediaUrl(path, pet: pet).then((u) {
      if (u != null) {
        _urls[key] = u;
        _notify();
      }
    });
    return null;
  }

  // ------------------------------------------------------------------ posting

  bool posting = false;
  String? postError;

  Future<bool> createPost({
    required String? petId,
    required String body,
    required PostVisibility visibility,
    required bool showArea,
    List<PickedPhoto> photos = const [],
  }) async {
    if (posting) return false;
    posting = true;
    postError = null;
    _notify();
    try {
      await _services.community.createPost(
        petId: petId,
        body: body,
        visibility: visibility,
        showArea: showArea,
        photos: photos,
      );
      posting = false;
      await load();
      return true;
    } on AppFailure catch (e) {
      postError = e.message;
      posting = false;
      _notify();
      return false;
    }
  }

  // ------------------------------------------------------------------ pet profile

  PetProfileData? profile;
  List<FeedPost> profilePosts = const [];
  bool loadingProfile = false;
  String? profileError;

  Future<void> loadProfile(String petId) async {
    profile = null;
    profilePosts = const [];
    profileError = null;
    loadingProfile = true;
    _notify();
    try {
      final results = await Future.wait([
        _services.community.petProfile(petId),
        _services.community.petPosts(petId),
      ]);
      profile = results[0] as PetProfileData;
      final withNames = results[1] as List<FeedPost>;
      profilePosts = withNames;
    } on AppFailure catch (e) {
      profileError = e.message;
    } finally {
      loadingProfile = false;
      _notify();
    }
  }

  // ------------------------------------------------------------------ reporting

  bool reporting = false;
  String? reportError;

  Future<bool> report(
    ReportTarget target,
    String id,
    ReportReason reason, {
    bool block = false,
  }) async {
    if (reporting) return false;
    reporting = true;
    reportError = null;
    _notify();
    try {
      await _services.community.report(target, id, reason, block: block);
      reporting = false;
      if (block) {
        // Their posts leave the feed straight away.
        await load();
      } else {
        _notify();
      }
      return true;
    } on AppFailure catch (e) {
      reportError = e.message;
      reporting = false;
      _notify();
      return false;
    }
  }

  // ------------------------------------------------------------------ lifecycle

  void _onSession() {
    if (_disposed) return;
    if (_session.status == SessionStatus.signedOut) reset();
  }

  void reset() {
    _loadSeq++;
    scope = FeedScope.forYou;
    posts = const [];
    loaded = false;
    profile = null;
    profilePosts = const [];
    _urls.clear();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _session.removeListener(_onSession);
    super.dispose();
  }
}
