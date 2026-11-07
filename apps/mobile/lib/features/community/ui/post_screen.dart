import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../booking/ui/booking_widgets.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/community_logic.dart';
import '../domain/models.dart';
import '../state/comments_controller.dart';
import 'community_widgets.dart';
import 'post_actions.dart';

/// One post with its comments and replies, like the comment page on any social app.
class PostScreen extends StatefulWidget {
  const PostScreen({super.key, required this.postId});
  final String postId;

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  CommentsController? _c;
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    var c = _c;
    if (c == null) {
      final made = c = _c = CommentsController(
        scope.services,
        widget.postId,
        onPostChanged: scope.community.syncPost,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => made.load());
    }
    final ctl = c;
    return ListenableBuilder(
      listenable: Listenable.merge([ctl, _text]),
      builder: (context, _) {
        final post = ctl.post;
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    PawSpace.screenSide,
                    12,
                    PawSpace.screenSide,
                    8,
                  ),
                  child: BookingHeader('Post'),
                ),
                Expanded(
                  child: ctl.loading && post == null
                      ? const Center(child: CircularProgressIndicator())
                      : post == null
                      ? PawErrorState(
                          title: 'We could not open this post',
                          message:
                              ctl.error ??
                              'It may have been removed. Go back and try another.',
                          onAction: () {
                            ctl.loading = false;
                            ctl.load();
                          },
                          linkLabel: 'Go back',
                          onLink: () => context.canPop()
                              ? context.pop()
                              : context.go('/community'),
                        )
                      : RefreshIndicator(
                          onRefresh: () {
                            ctl.loading = false;
                            return ctl.load();
                          },
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                              PawSpace.screenSide,
                              4,
                              PawSpace.screenSide,
                              16,
                            ),
                            children: [
                              _PostBody(post: post, ctl: ctl),
                              const SizedBox(height: 16),
                              Semantics(
                                header: true,
                                child: Text(
                                  commentsLabel(post.commentCount),
                                  style: PawText.body15Strong,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (ctl.threads.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  child: Text(
                                    'Be the first to comment.',
                                    textAlign: TextAlign.center,
                                    style: PawText.body14.copyWith(
                                      color: PawColors.muted,
                                    ),
                                  ),
                                )
                              else
                                for (final t in ctl.threads) ...[
                                  _CommentTile(
                                    comment: t.comment,
                                    ctl: ctl,
                                    postAuthorIsMe: post.isMine,
                                    onReply: () {
                                      ctl.startReply(t.comment);
                                      _focus.requestFocus();
                                    },
                                  ),
                                  for (final r in t.replies)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 36),
                                      child: _CommentTile(
                                        comment: r,
                                        ctl: ctl,
                                        postAuthorIsMe: post.isMine,
                                        onReply: () {
                                          ctl.startReply(r);
                                          _focus.requestFocus();
                                        },
                                      ),
                                    ),
                                ],
                              if (ctl.actionError != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      ctl.actionError!,
                                      style: PawText.meta13.copyWith(
                                        color: PawColors.danger,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
                if (post != null) _Composer(ctl: ctl, text: _text, focus: _focus),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PostBody extends StatelessWidget {
  const _PostBody({required this.post, required this.ctl});
  final FeedPost post;
  final CommentsController ctl;

  @override
  Widget build(BuildContext context) {
    final p = post;
    final byline = [
      p.authorName,
      if (p.area != null) p.area!,
      timeAgoShort(p.createdAt, ctl.now),
    ].where((s) => s.isNotEmpty).join(' · ');
    return PawCard(
      radius: PawRadius.cardSmall,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: p.petId == null ? null : () => context.push('/pet/${p.petId}'),
            child: Row(
              children: [
                PetMark(
                  name: p.petName ?? p.authorName,
                  path: p.petPhotoPath,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.petName == null
                            ? p.authorName
                            : '${p.petName} · ${petKind(p.petBreed, p.petSpecies)}',
                        style: PawText.body15Strong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        byline,
                        style: PawText.meta13.copyWith(color: PawColors.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (p.body.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(p.body, style: PawText.body15.copyWith(height: 1.45)),
          ],
          for (final path in p.mediaPaths.take(1)) PostPhoto(path: path),
          const SizedBox(height: 4),
          PostActionRow(post: p, onLike: ctl.togglePostLike),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.ctl,
    required this.postAuthorIsMe,
    required this.onReply,
  });
  final PostComment comment;
  final CommentsController ctl;
  final bool postAuthorIsMe;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final c = comment;
    final canDelete = c.isMine || postAuthorIsMe;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
        decoration: BoxDecoration(
          color: PawColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PawColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${c.authorName}${c.isMine ? ' (you)' : ''} · ${timeAgoShort(c.createdAt, ctl.now)}',
                    style: PawText.meta13.copyWith(
                      color: PawColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (canDelete || !c.isMine)
                  PopupMenuButton<String>(
                    tooltip: 'More about this comment',
                    icon: const Icon(Icons.more_horiz, color: PawColors.muted),
                    onSelected: (v) async {
                      if (v == 'report') {
                        context.push('/report/comment/${c.id}');
                      } else if (v == 'delete') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(
                              'Remove this comment?',
                              style: PawText.heading22,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Keep it'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  'Remove',
                                  style: TextStyle(color: PawColors.danger),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) await ctl.delete(c);
                      }
                    },
                    itemBuilder: (_) => [
                      if (canDelete)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Remove comment'),
                        ),
                      if (!c.isMine)
                        const PopupMenuItem(
                          value: 'report',
                          child: Text('Report this comment'),
                        ),
                    ],
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(c.body, style: PawText.body15.copyWith(height: 1.4)),
            ),
            Row(
              children: [
                LikeButtonLite(
                  liked: c.likedByMe,
                  count: c.likeCount,
                  onTap: () => ctl.toggleCommentLike(c),
                ),
                TextButton(
                  onPressed: onReply,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(PawSize.touch, PawSize.touch),
                    foregroundColor: PawColors.primaryText,
                  ),
                  child: Text(
                    'Reply',
                    style: PawText.body14Strong.copyWith(
                      color: PawColors.primaryText,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.ctl, required this.text, required this.focus});
  final CommentsController ctl;
  final TextEditingController text;
  final FocusNode focus;

  @override
  Widget build(BuildContext context) {
    final reply = ctl.replyingTo;
    return Container(
      decoration: const BoxDecoration(
        color: PawColors.surface,
        border: Border(top: BorderSide(color: PawColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reply != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Replying to ${reply.authorName}',
                    style: PawText.meta13.copyWith(color: PawColors.muted),
                  ),
                ),
                TextButton(
                  onPressed: ctl.cancelReply,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(PawSize.touch, 36),
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          if (ctl.postError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  ctl.postError!,
                  style: PawText.meta13.copyWith(color: PawColors.danger),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: text,
                  focusNode: focus,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  style: PawText.body15,
                  decoration: InputDecoration(
                    hintText: reply == null ? 'Add a comment' : 'Write a reply',
                    counterText: '',
                    filled: true,
                    fillColor: PawColors.subtle,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RoundIconButton(
                icon: PawIconData.chevronRight,
                filled: true,
                semanticLabel: reply == null ? 'Post comment' : 'Post reply',
                onPressed: ctl.posting
                    ? () {}
                    : () async {
                        final ok = await ctl.submit(text.text);
                        if (ok) text.clear();
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
