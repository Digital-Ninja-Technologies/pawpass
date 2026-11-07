DateTime? _time(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toUtc();

enum FeedScope {
  forYou('for_you'),
  near('near'),
  lost('lost');

  const FeedScope(this.value);
  final String value;
}

enum PostVisibility {
  everyone('everyone', 'Everyone'),
  nearby('nearby', 'Nearby'),
  followers('followers', 'Followers');

  const PostVisibility(this.value, this.label);
  final String value;
  final String label;
}

/// A post as the feed shows it.
class FeedPost {
  const FeedPost({
    required this.id,
    required this.authorUserId,
    required this.authorName,
    required this.body,
    required this.createdAt,
    this.petId,
    this.petName,
    this.petSpecies,
    this.petBreed,
    this.petPhotoPath,
    this.mediaPaths = const [],
    this.area,
    this.likeCount = 0,
    this.likedByMe = false,
    this.followingPet = false,
    this.isMine = false,
    this.commentCount = 0,
  });

  final String id;
  final String authorUserId;
  final String authorName;
  final String body;
  final DateTime createdAt;
  final String? petId;
  final String? petName;
  final String? petSpecies;
  final String? petBreed;
  final String? petPhotoPath;
  final List<String> mediaPaths;
  final String? area;
  final int likeCount;
  final bool likedByMe;
  final bool followingPet;
  final bool isMine;
  final int commentCount;

  FeedPost copyWith({
    int? likeCount,
    bool? likedByMe,
    bool? followingPet,
    int? commentCount,
  }) =>
      FeedPost(
        id: id,
        authorUserId: authorUserId,
        authorName: authorName,
        body: body,
        createdAt: createdAt,
        petId: petId,
        petName: petName,
        petSpecies: petSpecies,
        petBreed: petBreed,
        petPhotoPath: petPhotoPath,
        mediaPaths: mediaPaths,
        area: area,
        likeCount: likeCount ?? this.likeCount,
        likedByMe: likedByMe ?? this.likedByMe,
        followingPet: followingPet ?? this.followingPet,
        isMine: isMine,
        commentCount: commentCount ?? this.commentCount,
      );

  factory FeedPost.fromRow(Map<String, dynamic> r) => FeedPost(
    id: r['post_id'] as String,
    authorUserId: r['author_user_id'] as String,
    authorName: r['author_name'] as String,
    body: (r['body'] as String?) ?? '',
    createdAt: _time(r['created_at'])!,
    petId: r['pet_id'] as String?,
    petName: r['pet_name'] as String?,
    petSpecies: r['pet_species'] as String?,
    petBreed: r['pet_breed'] as String?,
    petPhotoPath: r['pet_photo_path'] as String?,
    mediaPaths: [
      for (final p in (r['media_paths'] as List? ?? const [])) p as String,
    ],
    area: r['area'] as String?,
    likeCount: (r['like_count'] as num?)?.toInt() ?? 0,
    likedByMe: r['liked_by_me'] == true,
    followingPet: r['following_pet'] == true,
    isMine: r['is_mine'] == true,
    commentCount: (r['comment_count'] as num?)?.toInt() ?? 0,
  );
}

/// A comment on a post. Replies sit one level under a comment.
class PostComment {
  const PostComment({
    required this.id,
    required this.authorUserId,
    required this.authorName,
    required this.body,
    required this.createdAt,
    this.parentId,
    this.likeCount = 0,
    this.likedByMe = false,
    this.isMine = false,
  });

  final String id;
  final String? parentId;
  final String authorUserId;
  final String authorName;
  final String body;
  final DateTime createdAt;
  final int likeCount;
  final bool likedByMe;
  final bool isMine;

  bool get isReply => parentId != null;

  PostComment copyWith({int? likeCount, bool? likedByMe}) => PostComment(
    id: id,
    parentId: parentId,
    authorUserId: authorUserId,
    authorName: authorName,
    body: body,
    createdAt: createdAt,
    likeCount: likeCount ?? this.likeCount,
    likedByMe: likedByMe ?? this.likedByMe,
    isMine: isMine,
  );

  factory PostComment.fromRow(Map<String, dynamic> r) => PostComment(
    id: r['comment_id'] as String,
    parentId: r['parent_id'] as String?,
    authorUserId: r['author_user_id'] as String,
    authorName: r['author_name'] as String,
    body: (r['body'] as String?) ?? '',
    createdAt: _time(r['created_at'])!,
    likeCount: (r['like_count'] as num?)?.toInt() ?? 0,
    likedByMe: r['liked_by_me'] == true,
    isMine: r['is_mine'] == true,
  );
}

/// A comment with its replies, oldest first.
class CommentThread {
  const CommentThread(this.comment, this.replies);
  final PostComment comment;
  final List<PostComment> replies;
}

/// Groups a flat list (oldest first) into comments with their replies. A reply whose comment is missing is dropped.
List<CommentThread> threadComments(List<PostComment> all) {
  final tops = [
    for (final c in all)
      if (!c.isReply) c,
  ];
  return [
    for (final t in tops)
      CommentThread(t, [
        for (final c in all)
          if (c.parentId == t.id) c,
      ]),
  ];
}

class PetProfileData {
  const PetProfileData({
    required this.id,
    required this.name,
    required this.species,
    required this.ownerUserId,
    required this.ownerName,
    this.breed,
    this.photoPath,
    this.ageMonths,
    this.area,
    this.isMine = false,
    this.isFollowing = false,
    this.posts = 0,
    this.followers = 0,
    this.following = 0,
    this.lost = false,
  });

  final String id;
  final String name;
  final String species;
  final String? breed;
  final String? photoPath;
  final int? ageMonths;
  final String ownerUserId;
  final String ownerName;
  final String? area;
  final bool isMine;
  final bool isFollowing;
  final int posts;
  final int followers;
  final int following;
  final bool lost;

  PetProfileData withFollowing(bool value) => PetProfileData(
    id: id,
    name: name,
    species: species,
    breed: breed,
    photoPath: photoPath,
    ageMonths: ageMonths,
    ownerUserId: ownerUserId,
    ownerName: ownerName,
    area: area,
    isMine: isMine,
    isFollowing: value,
    posts: posts,
    followers: followers + (value == isFollowing ? 0 : (value ? 1 : -1)),
    following: following,
    lost: lost,
  );

  factory PetProfileData.fromJson(Map<String, dynamic> r) => PetProfileData(
    id: r['id'] as String,
    name: r['name'] as String,
    species: r['species'] as String,
    breed: r['breed'] as String?,
    photoPath: r['photo_path'] as String?,
    ageMonths: (r['age_months'] as num?)?.toInt(),
    ownerUserId: r['owner_user_id'] as String,
    ownerName: r['owner_name'] as String,
    area: r['area'] as String?,
    isMine: r['is_mine'] == true,
    isFollowing: r['is_following'] == true,
    posts: (r['posts'] as num?)?.toInt() ?? 0,
    followers: (r['followers'] as num?)?.toInt() ?? 0,
    following: (r['following'] as num?)?.toInt() ?? 0,
    lost: r['lost'] == true,
  );
}

class LostAlertSummary {
  const LostAlertSummary({
    required this.alertId,
    required this.petId,
    required this.petName,
    required this.species,
    required this.lastSeenAt,
    this.breed,
    this.colour,
    this.photoPath,
    this.address,
    this.description,
    this.distanceM,
    this.sightings = 0,
    this.isMine = false,
  });

  final String alertId;
  final String petId;
  final String petName;
  final String species;
  final String? breed;
  final String? colour;
  final String? photoPath;
  final String? address;
  final String? description;
  final DateTime lastSeenAt;
  final int? distanceM;
  final int sightings;
  final bool isMine;

  factory LostAlertSummary.fromRow(Map<String, dynamic> r) => LostAlertSummary(
    alertId: r['alert_id'] as String,
    petId: r['pet_id'] as String,
    petName: r['pet_name'] as String,
    species: r['species'] as String,
    breed: r['breed'] as String?,
    colour: r['colour'] as String?,
    photoPath: r['photo_path'] as String?,
    address: r['address'] as String?,
    description: r['description'] as String?,
    lastSeenAt: _time(r['last_seen_at'])!,
    distanceM: (r['distance_m'] as num?)?.toInt(),
    sightings: (r['sightings'] as num?)?.toInt() ?? 0,
    isMine: r['is_mine'] == true,
  );
}

class Sighting {
  const Sighting({
    required this.id,
    required this.seenAt,
    this.note,
    this.mine = false,
    this.lat,
    this.lng,
  });

  final String id;
  final DateTime seenAt;
  final String? note;
  final bool mine;
  final double? lat;
  final double? lng;

  factory Sighting.fromJson(Map<String, dynamic> r) => Sighting(
    id: r['id'] as String,
    seenAt: _time(r['seen_at'])!,
    note: r['note'] as String?,
    mine: r['mine'] == true,
    lat: (r['lat'] as num?)?.toDouble(),
    lng: (r['lng'] as num?)?.toDouble(),
  );
}

class LostAlertDetail {
  const LostAlertDetail({
    required this.summary,
    required this.status,
    required this.ownerName,
    this.radiusM,
    this.sightingCount = 0,
    this.sightings = const [],
  });

  final LostAlertSummary summary;
  final String status;
  final String ownerName;
  final int? radiusM;
  final int sightingCount;
  final List<Sighting> sightings;

  bool get active => status == 'active';

  factory LostAlertDetail.fromJson(Map<String, dynamic> r) => LostAlertDetail(
    summary: LostAlertSummary(
      alertId: r['alert_id'] as String,
      petId: r['pet_id'] as String,
      petName: r['pet_name'] as String,
      species: r['species'] as String,
      breed: r['breed'] as String?,
      colour: r['colour'] as String?,
      photoPath: r['photo_path'] as String?,
      address: r['address'] as String?,
      description: r['description'] as String?,
      lastSeenAt: _time(r['last_seen_at'])!,
      distanceM: (r['distance_m'] as num?)?.toInt(),
      sightings: (r['sighting_count'] as num?)?.toInt() ?? 0,
      isMine: r['is_mine'] == true,
    ),
    status: r['status'] as String,
    ownerName: (r['owner_name'] as String?) ?? 'the owner',
    radiusM: (r['radius_m'] as num?)?.toInt(),
    sightingCount: (r['sighting_count'] as num?)?.toInt() ?? 0,
    sightings: [
      for (final s in (r['sightings'] as List? ?? const []))
        Sighting.fromJson(Map<String, dynamic>.from(s as Map)),
    ],
  );
}

/// One row of the chat inbox.
class ChatThread {
  const ChatThread({
    required this.id,
    required this.contextLabel,
    required this.otherName,
    required this.lastAt,
    this.contextType = 'lost_alert',
    this.contextId,
    this.lastBody,
    this.unread = 0,
    this.requestId,
    this.requestStatus,
    this.iRequested = false,
    this.otherUserId,
  });

  final String id;
  final String contextType;
  final String? contextId;
  final String contextLabel;
  final String otherName;

  /// For reporting or blocking the other person from the chat.
  final String? otherUserId;
  final String? lastBody;
  final DateTime lastAt;
  final int unread;

  /// For a message request (a chat a stranger started from the community): its id, state, and who asked.
  final String? requestId;
  final String? requestStatus;
  final bool iRequested;

  bool get isRequest => requestId != null;

  /// A request that this person has to accept or decline.
  bool get needsMyAnswer => isRequest && requestStatus == 'pending' && !iRequested;

  /// A request this person sent that has not been accepted yet.
  bool get waitingForThem => isRequest && requestStatus == 'pending' && iRequested;

  /// Messages can be sent: not a request, or an accepted one.
  bool get canSend => !isRequest || requestStatus == 'accepted';

  factory ChatThread.fromRow(Map<String, dynamic> r) => ChatThread(
    id: r['conversation_id'] as String,
    contextType: r['context_type'] as String,
    contextId: r['context_id'] as String?,
    contextLabel: r['context_label'] as String,
    otherName: r['other_name'] as String,
    lastBody: r['last_body'] as String?,
    lastAt: _time(r['last_at'])!,
    unread: (r['unread'] as num?)?.toInt() ?? 0,
    otherUserId: r['other_user_id'] as String?,
    requestId: r['request_id'] as String?,
    requestStatus: r['request_status'] as String?,
    iRequested: r['i_requested'] == true,
  );

  factory ChatThread.fromHeader(Map<String, dynamic> r) => ChatThread(
    id: r['conversation_id'] as String,
    contextType: r['context_type'] as String,
    contextId: r['context_id'] as String?,
    contextLabel: r['context_label'] as String,
    otherName: r['other_name'] as String,
    lastAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    otherUserId: r['other_user_id'] as String?,
    requestId: r['request_id'] as String?,
    requestStatus: r['request_status'] as String?,
    iRequested: r['i_requested'] == true,
  );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.mine,
    required this.createdAt,
    this.body,
    this.lat,
    this.lng,
  });

  final String id;
  final bool mine;
  final String? body;
  final double? lat;
  final double? lng;
  final DateTime createdAt;

  bool get isLocation => lat != null && lng != null;

  factory ChatMessage.fromRow(Map<String, dynamic> r) => ChatMessage(
    id: r['message_id'] as String,
    mine: r['mine'] == true,
    body: r['body'] as String?,
    lat: (r['lat'] as num?)?.toDouble(),
    lng: (r['lng'] as num?)?.toDouble(),
    createdAt: _time(r['created_at'])!,
  );
}

/// Why someone is reporting something. The value goes to the database; the label and hint are on screen.
enum ReportReason {
  scam(
    'scam',
    'Scam or fake seller',
    'Asks to pay outside PawPass, fake photos',
  ),
  cruelty('cruelty', 'Animal cruelty or neglect', ''),
  unsafeAdvice('unsafe_advice', 'Unsafe health advice', ''),
  harassment('harassment', 'Harassment or hate', ''),
  spam('spam', 'Spam or something else', '');

  const ReportReason(this.value, this.label, this.hint);
  final String value;
  final String label;
  final String hint;
}

/// What can be reported from the app.
enum ReportTarget {
  post('post'),
  comment('comment'),
  user('user'),
  lostAlert('lost_alert');

  const ReportTarget(this.value);
  final String value;

  static ReportTarget? parse(String? v) {
    for (final t in values) {
      if (t.value == v) return t;
    }
    return null;
  }
}

/// Options for the lost pet radius.
const lostRadiusOptions = [2000, 5000, 10000];
