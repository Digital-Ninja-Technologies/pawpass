import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../onboarding/domain/models.dart';
import '../domain/models.dart';
import 'community_repository.dart';

AppFailure _failure(Object e, String fallback) {
  if (e is AppFailure) return e;
  if (e is SocketException || e is HttpException) {
    return const AppFailure(
      'No connection. Check your internet and try again.',
    );
  }
  if (e is PostgrestException) {
    // Our own checks (P0001 rules, 22023 input) carry a message meant to be read.
    if (e.code == 'P0001' || e.code == '22023') return AppFailure(e.message);
    if (e.code == 'P0002' || e.code == '42501') {
      return const AppFailure(
        'We could not find that. It may have been removed.',
      );
    }
  }
  return AppFailure(fallback);
}

class SupabaseCommunityRepository implements CommunityRepository {
  SupabaseCommunityRepository(this._client);
  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  Future<List<Map<String, dynamic>>> _rows(
    String fn, [
    Map<String, dynamic>? params,
  ]) async {
    final res = await _client.rpc(fn, params: params) as List;
    return [for (final r in res) Map<String, dynamic>.from(r as Map)];
  }

  @override
  Future<List<FeedPost>> feed(FeedScope scope, {DateTime? before}) async {
    try {
      final rows = await _rows('community_feed', {
        'p_scope': scope.value,
        'p_before': before?.toUtc().toIso8601String(),
      });
      return [for (final r in rows) FeedPost.fromRow(r)];
    } catch (e) {
      throw _failure(e, 'We could not load the feed.');
    }
  }

  @override
  Future<({bool liked, int count})> toggleLike(String postId) async {
    try {
      final r = Map<String, dynamic>.from(
        await _client.rpc('toggle_like', params: {'p_post': postId}) as Map,
      );
      return (liked: r['liked'] == true, count: (r['count'] as num).toInt());
    } catch (e) {
      throw _failure(e, 'We could not save your like.');
    }
  }

  @override
  Future<FeedPost> post(String postId) async {
    try {
      final rows = await _rows('post_detail', {'p_post': postId});
      if (rows.isEmpty) {
        throw const AppFailure('That post is no longer there.');
      }
      return FeedPost.fromRow(rows.first);
    } catch (e) {
      throw _failure(e, 'We could not open that post.');
    }
  }

  @override
  Future<List<PostComment>> comments(String postId) async {
    try {
      final rows = await _rows('post_comments_list', {'p_post': postId});
      return [for (final r in rows) PostComment.fromRow(r)];
    } catch (e) {
      throw _failure(e, 'We could not load the comments.');
    }
  }

  @override
  Future<String> addComment(
    String postId,
    String body, {
    String? parentId,
  }) async {
    try {
      return await _client.rpc(
            'add_comment',
            params: {'p_post': postId, 'p_body': body, 'p_parent': parentId},
          )
          as String;
    } catch (e) {
      throw _failure(e, 'We could not post your comment. Please try again.');
    }
  }

  @override
  Future<void> deleteComment(String commentId) async {
    try {
      await _client.rpc('delete_comment', params: {'p_comment': commentId});
    } catch (e) {
      throw _failure(e, 'We could not remove that comment.');
    }
  }

  @override
  Future<({bool liked, int count})> toggleCommentLike(String commentId) async {
    try {
      final r = Map<String, dynamic>.from(
        await _client.rpc(
              'toggle_comment_like',
              params: {'p_comment': commentId},
            )
            as Map,
      );
      return (liked: r['liked'] == true, count: (r['count'] as num).toInt());
    } catch (e) {
      throw _failure(e, 'We could not save your like.');
    }
  }

  @override
  Future<String> createPost({
    required String? petId,
    required String body,
    required PostVisibility visibility,
    required bool showArea,
    List<PickedPhoto> photos = const [],
  }) async {
    try {
      final paths = <String>[];
      for (final photo in photos) {
        final path = '$_uid/${_id()}.${photo.extension}';
        await _client.storage
            .from('post-media')
            .uploadBinary(path, photo.bytes);
        paths.add(path);
      }
      final id = await _client.rpc(
        'create_post',
        params: {
          'p_pet': petId,
          'p_body': body,
          'p_media': paths,
          'p_visibility': visibility.value,
          'p_show_area': showArea,
        },
      );
      return id as String;
    } catch (e) {
      throw _failure(e, 'We could not share your post. Please try again.');
    }
  }

  @override
  Future<String?> mediaUrl(String path, {bool pet = false}) async {
    try {
      return await _client.storage
          .from(pet ? 'pet-photos' : 'post-media')
          .createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PetProfileData> petProfile(String petId) async {
    try {
      final r = await _client.rpc('pet_profile', params: {'p_pet': petId});
      return PetProfileData.fromJson(Map<String, dynamic>.from(r as Map));
    } catch (e) {
      throw _failure(e, 'We could not load this profile.');
    }
  }

  @override
  Future<List<FeedPost>> petPosts(String petId) async {
    try {
      final rows = await _rows('pet_posts', {'p_pet': petId});
      return [
        for (final r in rows)
          FeedPost(
            id: r['post_id'] as String,
            authorUserId: '',
            authorName: '',
            body: (r['body'] as String?) ?? '',
            createdAt: DateTime.parse(r['created_at'] as String).toUtc(),
            mediaPaths: [
              for (final p in (r['media_paths'] as List? ?? const []))
                p as String,
            ],
            area: r['area'] as String?,
            likeCount: (r['like_count'] as num?)?.toInt() ?? 0,
            likedByMe: r['liked_by_me'] == true,
            commentCount: (r['comment_count'] as num?)?.toInt() ?? 0,
            petId: petId,
          ),
      ];
    } catch (e) {
      throw _failure(e, 'We could not load posts.');
    }
  }

  @override
  Future<void> follow(String petId) async {
    try {
      await _client.from('follows').insert({
        'follower_user_id': _uid,
        'pet_id': petId,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') return; // already following
      throw _failure(e, 'We could not follow. Please try again.');
    } catch (e) {
      throw _failure(e, 'We could not follow. Please try again.');
    }
  }

  @override
  Future<void> unfollow(String petId) async {
    try {
      await _client
          .from('follows')
          .delete()
          .eq('follower_user_id', _uid)
          .eq('pet_id', petId);
    } catch (e) {
      throw _failure(e, 'We could not unfollow. Please try again.');
    }
  }

  @override
  Future<void> shareLocation(double lat, double lng) async {
    try {
      await _client.rpc(
        'update_my_location',
        params: {'p_lat': lat, 'p_lng': lng},
      );
    } catch (_) {
      // Telling the server where we are is a convenience; nothing breaks if it fails.
    }
  }

  @override
  Future<List<LostAlertSummary>> lostNearby({double? lat, double? lng}) async {
    try {
      final rows = await _rows('lost_alerts_nearby', {
        'p_lat': lat,
        'p_lng': lng,
      });
      return [for (final r in rows) LostAlertSummary.fromRow(r)];
    } catch (e) {
      throw _failure(e, 'We could not load lost pet alerts.');
    }
  }

  @override
  Future<LostAlertDetail> lostDetail(
    String alertId, {
    double? lat,
    double? lng,
  }) async {
    try {
      final r = await _client.rpc(
        'lost_alert_detail',
        params: {'p_alert': alertId, 'p_lat': lat, 'p_lng': lng},
      );
      return LostAlertDetail.fromJson(Map<String, dynamic>.from(r as Map));
    } catch (e) {
      throw _failure(e, 'We could not load this alert.');
    }
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
    try {
      final r = Map<String, dynamic>.from(
        await _client.rpc(
          'create_lost_alert',
          params: {
            'p_pet': petId,
            'p_lat': lat,
            'p_lng': lng,
            'p_address': address,
            'p_seen_at': seenAt.toUtc().toIso8601String(),
            'p_description': description,
            'p_radius_m': radiusM,
          },
        ) as Map,
      );
      return (
        alertId: r['alert_id'] as String,
        notified: (r['notified'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      throw _failure(e, 'We could not send the alert. Please try again.');
    }
  }

  @override
  Future<void> reportSighting(
    String alertId, {
    required double lat,
    required double lng,
    String? note,
  }) async {
    try {
      await _client.rpc(
        'report_sighting',
        params: {
          'p_alert': alertId,
          'p_lat': lat,
          'p_lng': lng,
          'p_note': note,
        },
      );
    } catch (e) {
      throw _failure(e, 'We could not share your sighting. Please try again.');
    }
  }

  @override
  Future<void> closeAlert(String alertId, {required bool found}) async {
    try {
      await _client
          .from('lost_alerts')
          .update({'status': found ? 'found' : 'closed'})
          .eq('id', alertId);
    } catch (e) {
      throw _failure(e, 'We could not close the alert. Please try again.');
    }
  }

  @override
  Future<String> openAlertChat(String alertId) async {
    try {
      return await _client.rpc('open_alert_chat', params: {'p_alert': alertId})
          as String;
    } catch (e) {
      throw _failure(e, 'We could not open the chat. Please try again.');
    }
  }

  @override
  Future<String> requestChat(String petId, String message) async {
    try {
      return await _client.rpc(
            'request_chat',
            params: {'p_pet': petId, 'p_message': message},
          )
          as String;
    } catch (e) {
      throw _failure(e, 'We could not send your message. Please try again.');
    }
  }

  @override
  Future<void> answerChatRequest(
    String requestId, {
    required bool accept,
  }) async {
    try {
      await _client.rpc(
        'respond_to_chat_request',
        params: {'p_request': requestId, 'p_accept': accept},
      );
    } catch (e) {
      throw _failure(e, 'We could not save your answer. Please try again.');
    }
  }

  @override
  Future<List<ChatThread>> threads() async {
    try {
      return [
        for (final r in await _rows('my_conversations')) ChatThread.fromRow(r),
      ];
    } catch (e) {
      throw _failure(e, 'We could not load your messages.');
    }
  }

  @override
  Future<ChatThread> thread(String conversationId) async {
    try {
      final r = await _client.rpc(
        'conversation_header',
        params: {'p_conversation': conversationId},
      );
      if (r == null) {
        throw const AppFailure('We could not find this conversation.');
      }
      return ChatThread.fromHeader(Map<String, dynamic>.from(r as Map));
    } catch (e) {
      throw _failure(e, 'We could not load this conversation.');
    }
  }

  @override
  Future<List<ChatMessage>> messages(String conversationId) async {
    try {
      final rows = await _rows('conversation_messages', {
        'p_conversation': conversationId,
      });
      return [for (final r in rows) ChatMessage.fromRow(r)];
    } catch (e) {
      throw _failure(e, 'We could not load messages.');
    }
  }

  @override
  Future<void> sendMessage(
    String conversationId, {
    String? body,
    double? lat,
    double? lng,
  }) async {
    try {
      await _client.rpc(
        'send_message',
        params: {
          'p_conversation': conversationId,
          'p_body': body,
          'p_lat': lat,
          'p_lng': lng,
        },
      );
    } catch (e) {
      throw _failure(e, 'Your message was not sent. Please try again.');
    }
  }

  @override
  Future<void> markRead(String conversationId) async {
    try {
      await _client.rpc(
        'mark_conversation_read',
        params: {'p_conversation': conversationId},
      );
    } catch (_) {
      // The unread dot may linger; nothing else is affected.
    }
  }

  @override
  Stream<void> watchMessages(String conversationId) {
    late final StreamController<void> controller;
    RealtimeChannel? channel;
    controller = StreamController<void>(
      onListen: () {
        channel = _client
            .channel('chat:$conversationId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'conversation_id',
                value: conversationId,
              ),
              callback: (_) => controller.add(null),
            )
            .subscribe();
      },
      onCancel: () async {
        final c = channel;
        if (c != null) await _client.removeChannel(c);
      },
    );
    return controller.stream;
  }

  @override
  Future<void> report(
    ReportTarget target,
    String id,
    ReportReason reason, {
    bool block = false,
  }) async {
    try {
      await _client.rpc(
        'file_report',
        params: {
          'p_target_type': target.value,
          'p_target_id': id,
          'p_reason': reason.value,
          'p_block': block,
        },
      );
    } catch (e) {
      throw _failure(e, 'We could not send your report. Please try again.');
    }
  }

  String _id() {
    final r = Random.secure();
    return List.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
