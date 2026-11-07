import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/community_logic.dart';
import 'community_screen.dart' show PostCard;
import 'community_widgets.dart';
import 'post_actions.dart';

/// A pet's public profile (design/screens/PetProfile.dc.html). Health records are never shown here.
class PetProfileScreen extends StatefulWidget {
  const PetProfileScreen({super.key, required this.petId});
  final String petId;

  @override
  State<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen> {
  var _started = false;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context).community;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => c.loadProfile(widget.petId),
      );
    }
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final p = c.profile;
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            child: c.loadingProfile && p == null
                ? const Center(child: CircularProgressIndicator())
                : p == null
                ? Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(PawSpace.screenSide),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PawBackButton(),
                        ),
                      ),
                      Expanded(
                        child: LoadError(
                          message:
                              c.profileError ??
                              'We could not load this profile.',
                          onRetry: () => c.loadProfile(widget.petId),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      PawSpace.screenSide,
                      12,
                      PawSpace.screenSide,
                      32,
                    ),
                    children: [
                      Row(
                        children: [
                          const PawBackButton(),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(
                                "${p.name}'s profile",
                                style: PawText.heading22,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (!p.isMine)
                            PopupMenuButton<String>(
                              tooltip: 'More about this profile',
                              icon: const Icon(
                                Icons.more_horiz,
                                color: PawColors.muted,
                              ),
                              onSelected: (v) {
                                if (v == 'report') {
                                  context.push('/report/user/${p.ownerUserId}');
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'report',
                                  child: Text('Report this profile'),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: PetMark(
                          name: p.name,
                          path: p.photoPath,
                          size: 96,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(child: Text(p.name, style: PawText.title28)),
                      const SizedBox(height: 4),
                      Text(
                        [
                          petKind(p.breed, p.species),
                          if (p.ageMonths != null) ageLabel(p.ageMonths),
                          if (p.area != null) p.area!,
                          'with ${p.ownerName}',
                        ].join(' · '),
                        textAlign: TextAlign.center,
                        style: PawText.meta13.copyWith(color: PawColors.muted),
                      ),
                      if (p.lost) ...[
                        const SizedBox(height: 10),
                        const Center(
                          child: PawBadge(
                            'LOST right now',
                            tone: PawBadgeTone.lost,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _Count(value: p.posts, label: 'Posts'),
                          _Count(value: p.followers, label: 'Followers'),
                          _Count(value: p.following, label: 'Following'),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (!p.isMine)
                        PawButton(
                          label: p.isFollowing ? 'Following' : 'Follow',
                          variant: p.isFollowing
                              ? PawButtonVariant.secondary
                              : PawButtonVariant.primary,
                          onPressed: () => c.toggleFollow(
                            p.id,
                            currentlyFollowing: p.isFollowing,
                          ),
                        ),
                      if (!p.isMine) ...[
                        const SizedBox(height: 10),
                        PawButton(
                          label: 'Message ${p.ownerName}',
                          variant: PawButtonVariant.secondary,
                          onPressed: () => showMessageRequestSheet(
                            context,
                            petId: p.id,
                            ownerName: p.ownerName,
                            petName: p.name,
                          ),
                        ),
                      ],
                      if (c.actionError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          c.actionError!,
                          style: PawText.meta13.copyWith(
                            color: PawColors.danger,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      PawCard(
                        color: PawColors.primarySoft,
                        radius: PawRadius.cardSmall,
                        child: Text(
                          'Health records stay private. Only the owner can share them.',
                          style: PawText.meta13.copyWith(
                            color: PawColors.primaryText,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SectionLabel('Posts'),
                      const SizedBox(height: 10),
                      if (c.profilePosts.isEmpty)
                        const InfoCard(
                          title: 'No posts yet',
                          body: 'Posts from this pet show up here.',
                          icon: PawIconData.paw,
                        )
                      else
                        for (final post in c.profilePosts)
                          PostCard(
                            post: post,
                            controller: c,
                            showHeader: false,
                          ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$value $label',
        excludeSemantics: true,
        child: Column(
          children: [
            Text(countLabel(value), style: PawText.heading22),
            Text(label, style: PawText.meta13.copyWith(color: PawColors.muted)),
          ],
        ),
      ),
    );
  }
}
