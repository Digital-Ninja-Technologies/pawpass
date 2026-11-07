import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../booking/domain/booking_logic.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/community_logic.dart';
import '../domain/models.dart';
import '../state/community_controller.dart';
import '../state/lost_controller.dart';
import 'community_widgets.dart';
import 'post_actions.dart';

/// Community (design/screens/Community.dc.html): the feed, posts near you, and lost and found.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  var _started = false;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final c = scope.community;
    final lost = scope.lost;
    final chat = scope.chat;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!c.loaded) {
          c.load();
        }
        lost.load();
        chat.loadThreads();
      });
    }
    return ListenableBuilder(
      listenable: Listenable.merge([c, lost, chat]),
      builder: (context, _) {
        final tab = c.scope;
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([c.load(), lost.load(), chat.loadThreads()]);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  PawSpace.screenSide,
                  16,
                  PawSpace.screenSide,
                  32,
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text('Community', style: PawText.title28),
                        ),
                      ),
                      RoundIconButton(
                        icon: PawIconData.mail,
                        semanticLabel: chat.unread > 0
                            ? 'Messages, ${chat.unread} new'
                            : 'Messages',
                        dot: chat.unread > 0,
                        onPressed: () async {
                          await context.push('/messages');
                          await chat.loadThreads();
                        },
                      ),
                      const SizedBox(width: 8),
                      RoundIconButton(
                        icon: PawIconData.plus,
                        filled: true,
                        semanticLabel: 'New post',
                        onPressed: () => context.push('/post/new'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  PawSegmented<FeedScope>(
                    segments: const [
                      PawSegment(FeedScope.forYou, 'For you'),
                      PawSegment(FeedScope.near, 'Near me'),
                      PawSegment(FeedScope.lost, 'Lost & found'),
                    ],
                    value: tab,
                    onChanged: (s) {
                      if (s == FeedScope.lost) {
                        c.scope = s;
                        c.posts = const [];
                        // Showing the lost tab needs no feed; notify through a no-op load of alerts.
                        lost.load();
                        setState(() {});
                      } else {
                        c.setScope(s);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  if (c.actionError != null) _ErrorNote(c.actionError!),
                  if (tab == FeedScope.lost)
                    ..._lostTab(context, lost)
                  else
                    ..._feedTab(context, c, lost),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _lostTab(BuildContext context, LostController lost) {
    final alerts = lost.alerts;
    if (lost.loading && alerts.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (lost.error != null && alerts.isEmpty) {
      return [LoadError(message: lost.error!, onRetry: lost.load)];
    }
    return [
      PawButton(
        label: 'Report a lost pet',
        variant: PawButtonVariant.warm,
        onPressed: () => context.push('/lost-report'),
      ),
      const SizedBox(height: 16),
      if (alerts.isEmpty)
        const InfoCard(
          title: 'No lost pets near you',
          body: 'When someone nearby reports a lost pet, it shows up here and you get a notification.',
          icon: PawIconData.paw,
        )
      else
        for (final a in alerts) LostAlertTile(alert: a, now: lost.now),
    ];
  }

  List<Widget> _feedTab(
    BuildContext context,
    CommunityController c,
    LostController lost,
  ) {
    final posts = c.posts;
    final alerts = [
      for (final a in lost.alerts)
        if (!a.isMine) a,
    ];
    return [
      if (alerts.isNotEmpty) ...[
        const SectionLabel('Lost near you', color: PawColors.danger),
        const SizedBox(height: 10),
        LostAlertTile(alert: alerts.first, now: c.now, compact: true),
        const SizedBox(height: 6),
      ],
      if (c.loading && posts.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (c.error != null && posts.isEmpty)
        LoadError(message: c.error!, onRetry: c.load)
      else if (posts.isEmpty)
        InfoCard(
          title: c.scope == FeedScope.near
              ? 'Nothing nearby yet'
              : 'No posts yet',
          body: 'Be the first to share a moment with your pet.',
          icon: PawIconData.community,
        )
      else ...[
        for (final p in posts) PostCard(post: p, controller: c),
        if (!c.reachedEnd)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: PawButton(
              label: 'Show more',
              variant: PawButtonVariant.secondary,
              loading: c.loadingMore,
              onPressed: () => c.loadMore(),
            ),
          ),
      ],
    ];
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PawColors.dangerSoft,
            borderRadius: BorderRadius.circular(PawRadius.cardSmall),
          ),
          child: Text(
            message,
            style: PawText.body14.copyWith(color: PawColors.danger),
          ),
        ),
      ),
    );
  }
}

/// A lost pet in the list (and, compact, the red card at the top of the feed).
class LostAlertTile extends StatelessWidget {
  const LostAlertTile({
    super.key,
    required this.alert,
    required this.now,
    this.compact = false,
  });
  final LostAlertSummary alert;
  final DateTime now;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final a = alert;
    final seen =
        'Last seen ${timeAgoLong(a.lastSeenAt, now)}${a.address == null ? '' : ' · ${a.address}'}';
    final dist = a.distanceM == null
        ? ''
        : ' · ${distanceLabel(a.distanceM)} away';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PawCard(
        radius: PawRadius.cardSmall,
        color: compact ? PawColors.dangerSoft : PawColors.surface,
        onTap: () => context.push('/lost/${a.alertId}'),
        semanticLabel:
            'Lost: ${a.petName}, ${petKind(a.colour ?? a.breed, a.species)}. $seen$dist',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PetMark(name: a.petName, path: a.photoPath, size: 52, square: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${a.petName} · ${petKind(a.breed ?? a.colour, a.species)}',
                    style: PawText.body15Strong,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$seen$dist',
                    style: PawText.meta13.copyWith(color: PawColors.ink2),
                  ),
                  if (a.isMine)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Your alert · ${a.sightings} sighting${a.sightings == 1 ? '' : 's'}',
                        style: PawText.meta13.copyWith(
                          color: PawColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else if (compact)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        "I've seen ${a.petName}",
                        style: PawText.meta13.copyWith(
                          color: PawColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A post in the feed.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.controller,
    this.showHeader = true,
  });
  final FeedPost post;
  final CommunityController controller;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final p = post;
    final c = controller;
    final now = c.now;
    final byline = [
      p.authorName,
      if (p.area != null) p.area!,
      timeAgoShort(p.createdAt, now),
    ].where((s) => s.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PawCard(
        radius: PawRadius.cardSmall,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: p.petId != null,
                      label: p.petName == null
                          ? byline
                          : '${p.petName}, $byline',
                      excludeSemantics: true,
                      onTap: p.petId == null
                          ? null
                          : () => context.push('/pet/${p.petId}'),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: p.petId == null
                            ? null
                            : () => context.push('/pet/${p.petId}'),
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
                                    style: PawText.meta13.copyWith(
                                      color: PawColors.muted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (p.petId != null && !p.isMine)
                    FollowButton(
                      following: p.followingPet,
                      petName: p.petName,
                      onTap: () => c.toggleFollow(
                        p.petId!,
                        currentlyFollowing: p.followingPet,
                      ),
                    ),
                  if (!p.isMine)
                    PopupMenuButton<String>(
                      tooltip: 'More about this post',
                      icon: const Icon(
                        Icons.more_horiz,
                        color: PawColors.muted,
                      ),
                      onSelected: (v) {
                        if (v == 'report') {
                          context.push('/report/post/${p.id}');
                        } else if (v == 'message' && p.petId != null) {
                          showMessageRequestSheet(
                            context,
                            petId: p.petId!,
                            ownerName: p.authorName,
                            petName: p.petName ?? 'their pet',
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        if (p.petId != null)
                          PopupMenuItem(
                            value: 'message',
                            child: Text('Message ${p.authorName}'),
                          ),
                        const PopupMenuItem(
                          value: 'report',
                          child: Text('Report this post'),
                        ),
                      ],
                    ),
                ],
              ),
            if (p.body.isNotEmpty) ...[
              SizedBox(height: showHeader ? 12 : 0),
              Text(p.body, style: PawText.body15.copyWith(height: 1.45)),
            ],
            for (final path in p.mediaPaths.take(1)) PostPhoto(path: path),
            const SizedBox(height: 4),
            PostActionRow(
              post: p,
              onLike: () => c.toggleLike(p),
              onComment: () async {
                await context.push('/posts/${p.id}');
              },
            ),
          ],
        ),
      ),
    );
  }
}
