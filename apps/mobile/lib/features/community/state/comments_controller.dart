import 'package:flutter/foundation.dart';

import '../../onboarding/data/repositories.dart';
import '../../onboarding/domain/models.dart';
import '../domain/models.dart';

/// One post and its comments: loading, commenting, replying, liking and removing. Lives as long as the screen.
class CommentsController extends ChangeNotifier {
  CommentsController(this._services, this.postId, {this.onPostChanged});

  final AppServices _services;
  final String postId;

  /// Called with the latest copy of the post so the feed's counts stay in step.
  final void Function(FeedPost post)? onPostChanged;
  var _disposed = false;

  DateTime get now => _services.now();

  FeedPost? post;
  List<PostComment> all = const [];
  var loading = false;
  var loaded = false;
  String? error;

  var posting = false;
  String? postError;

  /// Shown under the list after a failed like or delete.
  String? actionError;

  /// The comment a reply is being written to.
  PostComment? replyingTo;

  List<CommentThread> get threads => threadComments(all);

  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    _notify();
    try {
      final results = await Future.wait([
        _services.community.post(postId),
        _services.community.comments(postId),
      ]);
      post = results[0] as FeedPost;
      all = results[1] as List<PostComment>;
      post = post!.copyWith(commentCount: all.length);
      loaded = true;
      onPostChanged?.call(post!);
    } on AppFailure catch (e) {
      error = e.message;
    } finally {
      loading = false;
      _notify();
    }
  }

  void startReply(PostComment c) {
    replyingTo = c;
    postError = null;
    _notify();
  }

  void cancelReply() {
    replyingTo = null;
    _notify();
  }

  /// Adds the comment (or reply). Returns true if it went through.
  Future<bool> submit(String text) async {
    if (posting) return false;
    final body = text.trim();
    if (body.isEmpty) {
      postError = 'Write a comment first.';
      _notify();
      return false;
    }
    if (body.length > 1000) {
      postError = 'Keep it under 1,000 characters.';
      _notify();
      return false;
    }
    posting = true;
    postError = null;
    _notify();
    try {
      await _services.community.addComment(
        postId,
        body,
        parentId: replyingTo?.id,
      );
      replyingTo = null;
      all = await _services.community.comments(postId);
      _syncCount();
      return true;
    } on AppFailure catch (e) {
      postError = e.message;
      return false;
    } finally {
      posting = false;
      _notify();
    }
  }

  /// Shows the like at once and puts it back if the server says no.
  Future<void> toggleCommentLike(PostComment c) async {
    actionError = null;
    final was = c.likedByMe;
    _replaceComment(
      c.id,
      (x) => x.copyWith(
        likedByMe: !was,
        likeCount: x.likeCount + (was ? -1 : 1),
      ),
    );
    _notify();
    try {
      final r = await _services.community.toggleCommentLike(c.id);
      _replaceComment(
        c.id,
        (x) => x.copyWith(likedByMe: r.liked, likeCount: r.count),
      );
    } on AppFailure catch (e) {
      _replaceComment(
        c.id,
        (x) => x.copyWith(likedByMe: was, likeCount: c.likeCount),
      );
      actionError = e.message;
    }
    _notify();
  }

  Future<void> togglePostLike() async {
    final p = post;
    if (p == null) return;
    actionError = null;
    final was = p.likedByMe;
    post = p.copyWith(
      likedByMe: !was,
      likeCount: p.likeCount + (was ? -1 : 1),
    );
    _notify();
    try {
      final r = await _services.community.toggleLike(postId);
      post = post!.copyWith(likedByMe: r.liked, likeCount: r.count);
    } on AppFailure catch (e) {
      post = post!.copyWith(likedByMe: was, likeCount: p.likeCount);
      actionError = e.message;
    }
    onPostChanged?.call(post!);
    _notify();
  }

  Future<bool> delete(PostComment c) async {
    actionError = null;
    try {
      await _services.community.deleteComment(c.id);
      all = await _services.community.comments(postId);
      if (replyingTo?.id == c.id) replyingTo = null;
      _syncCount();
      _notify();
      return true;
    } on AppFailure catch (e) {
      actionError = e.message;
      _notify();
      return false;
    }
  }

  void _syncCount() {
    final p = post;
    if (p == null) return;
    post = p.copyWith(commentCount: all.length);
    onPostChanged?.call(post!);
  }

  void _replaceComment(String id, PostComment Function(PostComment) f) {
    all = [for (final c in all) c.id == id ? f(c) : c];
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
