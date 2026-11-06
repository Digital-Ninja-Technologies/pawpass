import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
import '../../onboarding/state/app_scope.dart';

/// A round pet picture (or its first letter on a soft colour while the photo loads or if there is none).
class PetMark extends StatelessWidget {
  const PetMark({
    super.key,
    required this.name,
    this.path,
    this.size = 44,
    this.square = false,
  });
  final String name;
  final String? path;
  final double size;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final url = AppScope.of(context).community.urlFor(path, pet: true);
    final tint =
        PawColors.petTints[name.codeUnits.fold<int>(0, (a, b) => a + b) %
            PawColors.petTints.length];
    final fallback = ColoredBox(
      color: tint,
      child: Center(
        child: Text(
          name.isEmpty ? '?' : name[0].toUpperCase(),
          style: PawText.heading22.copyWith(
            fontSize: size * 0.42,
            color: PawColors.warmText,
          ),
        ),
      ),
    );
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(square ? size / 4 : size / 2),
        child: SizedBox(
          width: size,
          height: size,
          child: url == null
              ? fallback
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : fallback,
                ),
        ),
      ),
    );
  }
}

/// A photo from a post, 16:10, or nothing if the link has not arrived.
class PostPhoto extends StatelessWidget {
  const PostPhoto({super.key, required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final url = AppScope.of(context).community.urlFor(path);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: url == null
              ? const ColoredBox(color: PawColors.subtle)
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  semanticLabel: 'Photo from the post',
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: PawColors.subtle),
                ),
        ),
      ),
    );
  }
}

/// The ♡ with a count. The whole thing taps, at least 44 high.
class LikeButton extends StatelessWidget {
  const LikeButton({
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

/// A small outlined button for Follow / Following that is still 44 high to touch.
class FollowButton extends StatelessWidget {
  const FollowButton({
    super.key,
    required this.following,
    required this.onTap,
    this.petName,
  });
  final bool following;
  final VoidCallback onTap;
  final String? petName;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: following,
      label: following
          ? 'Following ${petName ?? ''}, tap to unfollow'
          : 'Follow ${petName ?? ''}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: PawSize.touch,
            minWidth: 64,
          ),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: following ? PawColors.surface : PawColors.primarySoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: following ? PawColors.outline : PawColors.primarySoft,
                ),
              ),
              child: Text(
                following ? 'Following' : 'Follow',
                style: PawText.meta13.copyWith(
                  color: following ? PawColors.ink2 : PawColors.primaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
