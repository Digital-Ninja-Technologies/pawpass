import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../health/domain/health_logic.dart' show whatsAppUri;
import '../../onboarding/state/app_scope.dart';
import '../domain/community_logic.dart';
import '../domain/models.dart';

/// An icon and a count that taps, at least 44 high. Used for Comment and Share under a post.
class PostActionButton extends StatelessWidget {
  const PostActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });
  final PawIconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: PawSize.touch,
            minWidth: PawSize.touch,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PawIcon(icon, size: 21, color: PawColors.muted),
                if (label.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: PawText.body14Strong.copyWith(color: PawColors.ink2),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Like, Comment and Share under a post. Tapping Comment opens the post's comments.
class PostActionRow extends StatelessWidget {
  const PostActionRow({
    super.key,
    required this.post,
    required this.onLike,
    this.onComment,
  });
  final FeedPost post;
  final VoidCallback onLike;

  /// Null on the comments screen itself, where the composer is already there.
  final VoidCallback? onComment;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        LikeButtonLite(
          liked: post.likedByMe,
          count: post.likeCount,
          onTap: onLike,
        ),
        const SizedBox(width: 4),
        PostActionButton(
          icon: PawIconData.messages,
          label: post.commentCount == 0 ? '' : countLabel(post.commentCount),
          semanticLabel: post.commentCount == 0
              ? 'Comment on this post'
              : 'Comments, ${post.commentCount}. Open to read and reply',
          onTap: onComment ?? () {},
        ),
        const SizedBox(width: 4),
        PostActionButton(
          icon: PawIconData.share,
          label: '',
          semanticLabel: 'Share this post',
          onTap: () => showShareSheet(context, post),
        ),
      ],
    );
  }
}

/// The heart with a count (the same look as the feed's like button).
class LikeButtonLite extends StatelessWidget {
  const LikeButtonLite({
    super.key,
    required this.liked,
    required this.count,
    required this.onTap,
  });
  final bool liked;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: liked,
      label: liked ? 'Unlike, $count likes' : 'Like, $count likes',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: PawSize.touch,
            minWidth: PawSize.touch,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  liked ? '♥' : '♡',
                  style: TextStyle(
                    fontSize: 22,
                    height: 1,
                    color: liked ? PawColors.dot : PawColors.muted,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: PawText.body14Strong.copyWith(color: PawColors.ink2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Share a post to WhatsApp or copy the text. There is no web page for a single post, so the link is the app's site.
Future<void> showShareSheet(BuildContext context, FeedPost post) {
  final services = AppScope.of(context).services;
  final site = Uri.parse(services.shareBaseUrl).replace(path: '/').toString();
  final text = postShareText(
    authorName: post.authorName,
    body: post.body,
    petName: post.petName,
    url: site,
  );
  final messenger = ScaffoldMessenger.of(context);
  void say(String m) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: PawColors.surface,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PawSpace.screenSide,
          0,
          PawSpace.screenSide,
          20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('Share this post', style: PawText.heading22),
            ),
            const SizedBox(height: 6),
            Text(
              'Only what is already public in the post is shared. Pet health records are never included.',
              style: PawText.meta13.copyWith(color: PawColors.muted),
            ),
            const SizedBox(height: 14),
            PawButton(
              label: 'Share on WhatsApp',
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await services.links.open(whatsAppUri(text));
                if (!ok) {
                  say('We could not open WhatsApp. Use Copy instead.');
                }
              },
            ),
            const SizedBox(height: 10),
            PawButton(
              label: 'Copy',
              variant: PawButtonVariant.secondary,
              onPressed: () async {
                Navigator.pop(ctx);
                await services.links.copy(text);
                say('Copied.');
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// Ask a pet's owner to chat. They have to accept before either of you can send more.
Future<void> showMessageRequestSheet(
  BuildContext context, {
  required String petId,
  required String ownerName,
  required String petName,
}) async {
  final chat = AppScope.of(context).chat;
  final router = GoRouter.of(context);
  chat.requestError = null;
  final id = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: PawColors.surface,
    showDragHandle: true,
    builder: (ctx) => _RequestSheet(
      petId: petId,
      ownerName: ownerName,
      petName: petName,
    ),
  );
  if (id != null) {
    await router.push('/chat/$id');
    await chat.loadThreads();
  }
}

class _RequestSheet extends StatefulWidget {
  const _RequestSheet({
    required this.petId,
    required this.ownerName,
    required this.petName,
  });
  final String petId;
  final String ownerName;
  final String petName;

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = AppScope.of(context).chat;
    return ListenableBuilder(
      listenable: Listenable.merge([chat, _text]),
      builder: (context, _) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PawSpace.screenSide,
              0,
              PawSpace.screenSide,
              16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Message ${widget.ownerName}',
                    style: PawText.heading22,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'About ${widget.petName}. ${widget.ownerName} has to accept before you can chat. Phone numbers stay hidden.',
                  style: PawText.meta13.copyWith(color: PawColors.muted),
                ),
                const SizedBox(height: 14),
                PawTextField(
                  label: 'Your first message',
                  controller: _text,
                  hint: 'Say hello and why you are getting in touch',
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  errorText: chat.requestError,
                ),
                const SizedBox(height: 12),
                PawButton(
                  label: 'Send request',
                  loading: chat.requesting,
                  onPressed: _text.text.trim().isEmpty
                      ? null
                      : () async {
                          final nav = Navigator.of(context);
                          final id = await chat.requestChat(
                            widget.petId,
                            _text.text,
                          );
                          if (id != null && nav.mounted) nav.pop(id);
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
