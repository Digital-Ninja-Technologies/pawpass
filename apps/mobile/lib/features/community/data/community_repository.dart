import '../../onboarding/domain/models.dart';
import '../domain/models.dart';

/// Everything the Community, Lost and Chat screens need from the server. One interface, since they share
/// people, pets and places. Failures are [AppFailure]s with a message meant to be read.
abstract class CommunityRepository {
  // ----------------------------------------------------------------- feed
  Future<List<FeedPost>> feed(FeedScope scope, {DateTime? before});

  /// Returns the new state of the like.
  Future<({bool liked, int count})> toggleLike(String postId);

  Future<String> createPost({
    required String? petId,
    required String body,
    required PostVisibility visibility,
    required bool showArea,
    List<PickedPhoto> photos = const [],
  });

  /// One post, for opening from a notification or the comments screen. Throws if it is gone or not visible.
  Future<FeedPost> post(String postId);

  // ----------------------------------------------------------------- comments
  /// Comments and replies on a post, oldest first.
  Future<List<PostComment>> comments(String postId);

  /// Adds a comment, or a reply when [parentId] is given. Returns the new comment's id.
  Future<String> addComment(String postId, String body, {String? parentId});

  /// Removes a comment. The comment's author or the post's author may.
  Future<void> deleteComment(String commentId);

  Future<({bool liked, int count})> toggleCommentLike(String commentId);

  /// A short lived link to a post photo or a pet photo (the buckets are private).
  Future<String?> mediaUrl(String path, {bool pet = false});

  // ----------------------------------------------------------------- pets
  Future<PetProfileData> petProfile(String petId);
  Future<List<FeedPost>> petPosts(String petId);
  Future<void> follow(String petId);
  Future<void> unfollow(String petId);

  // ----------------------------------------------------------------- lost and found
  /// Tells the server roughly where this person is, so alerts near them can reach them.
  Future<void> shareLocation(double lat, double lng);

  Future<List<LostAlertSummary>> lostNearby({double? lat, double? lng});
  Future<LostAlertDetail> lostDetail(
    String alertId, {
    double? lat,
    double? lng,
  });

  /// Raises the alert and tells people nearby. Returns the alert id and how many people were told.
  Future<({String alertId, int notified})> createLostAlert({
    required String petId,
    required double lat,
    required double lng,
    required String address,
    required DateTime seenAt,
    required String description,
    required int radiusM,
  });

  Future<void> reportSighting(
    String alertId, {
    required double lat,
    required double lng,
    String? note,
  });

  /// Marks the pet found (or the alert closed).
  Future<void> closeAlert(String alertId, {required bool found});

  // ----------------------------------------------------------------- chat
  Future<String> openAlertChat(String alertId);

  /// Asks a pet's owner to chat, with a first message. Returns the conversation. The owner has to accept
  /// before either of you can send more. If you already have a chat or request with them, returns that one.
  Future<String> requestChat(String petId, String message);

  /// Accepts or declines a message request sent to this person.
  Future<void> answerChatRequest(String requestId, {required bool accept});
  Future<List<ChatThread>> threads();
  Future<ChatThread> thread(String conversationId);
  Future<List<ChatMessage>> messages(String conversationId);
  Future<void> sendMessage(
    String conversationId, {
    String? body,
    double? lat,
    double? lng,
  });
  Future<void> markRead(String conversationId);

  /// Emits whenever a new message arrives in this conversation, so the screen can refresh.
  Stream<void> watchMessages(String conversationId);

  // ----------------------------------------------------------------- reports
  Future<void> report(
    ReportTarget target,
    String id,
    ReportReason reason, {
    bool block = false,
  });
}
