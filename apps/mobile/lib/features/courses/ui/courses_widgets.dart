import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../ui/ui.dart';
import '../domain/course_logic.dart';
import '../domain/models.dart';

/// The illustrations that ship with the app (assets/course_art). An unknown key shows the paw.
const courseArtKeys = {
  'welcome',
  'potty',
  'sit',
  'leash',
  'chew',
  'social',
  'crate',
  'recall',
  'tricks',
  'health',
  'ball',
  'paw',
};

/// A course's picture: the uploaded cover if there is one, otherwise a flat illustration on the course's colour.
/// Decorative, so screen readers skip it (the title says it all).
class CourseArt extends StatelessWidget {
  const CourseArt({
    super.key,
    required this.accent,
    required this.art,
    this.coverUrl,
    this.height = 150,
    this.radius = BorderRadius.zero,
    this.padding = const EdgeInsets.all(6),
  });

  CourseArt.of(
    Course course, {
    Key? key,
    double height = 150,
    BorderRadius radius = BorderRadius.zero,
    EdgeInsets padding = const EdgeInsets.all(6),
  }) : this(
         key: key,
         accent: course.accent,
         art: course.art,
         coverUrl: course.coverUrl,
         height: height,
         radius: radius,
         padding: padding,
       );

  final String accent;
  final String art;
  final String? coverUrl;
  final double height;
  final BorderRadius radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = PawCourseColors.byKey(accent);
    final illustration = Padding(
      padding: padding,
      child: SvgPicture.asset(
        'assets/course_art/${courseArtKeys.contains(art) ? art : 'paw'}.svg',
        fit: BoxFit.contain,
      ),
    );
    final cover = coverUrl;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: radius,
        child: Container(
          height: height,
          width: double.infinity,
          color: colors.soft,
          child: cover == null || cover.isEmpty
              ? illustration
              : Image.network(
                  cover,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => illustration,
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : illustration,
                ),
        ),
      ),
    );
  }
}

/// A small rounded label ("Puppies", "Beginner", "12 mins").
class CoursePill extends StatelessWidget {
  const CoursePill(this.text, {super.key, this.color, this.icon});

  final String text;
  final PawCourseColor? color;
  final PawIconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color;
    final fg = c?.text ?? PawColors.ink2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c?.soft ?? PawColors.subtle,
        borderRadius: BorderRadius.circular(PawRadius.badge + 6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            PawIcon(icon!, size: 14, color: fg, strokeWidth: 2),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              style: PawText.meta12.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A chunky progress bar in the course's strong colour.
class CourseProgressBar extends StatelessWidget {
  const CourseProgressBar({
    super.key,
    required this.fraction,
    required this.color,
    this.height = 10,
  });

  final double fraction;
  final PawCourseColor color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Container(
          height: height,
          color: color.soft,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: f,
            child: Container(color: color.strong),
          ),
        ),
      ),
    );
  }
}

/// A course on the list: big picture, title, a line about it, and how far you are.
class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    required this.course,
    required this.progress,
    required this.onTap,
  });

  final Course course;
  final ({int done, int total}) progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = PawCourseColors.byKey(course.accent);
    final finished = progress.total > 0 && progress.done == progress.total;
    final started = progress.done > 0;
    final status = finished
        ? 'Finished'
        : started
        ? '${progress.done} of ${progress.total} lessons done'
        : 'Not started';
    return PawCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      semanticLabel:
          '${course.title}. ${course.summary} ${lessonCountLabel(course.lessons.length)}, '
          '${minutesLabel(course.minutes)}. $status.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CourseArt.of(course, height: 150),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    CoursePill(course.audience.label, color: colors),
                    CoursePill(course.level.label),
                  ],
                ),
                const SizedBox(height: 10),
                Text(course.title, style: PawText.heading22),
                const SizedBox(height: 4),
                Text(
                  course.summary,
                  style: PawText.body14.copyWith(color: PawColors.ink2),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const PawIcon(
                      PawIconData.clock,
                      size: 16,
                      color: PawColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${lessonCountLabel(course.lessons.length)} · ${minutesLabel(course.minutes)}',
                        style: PawText.meta13.copyWith(color: PawColors.muted),
                      ),
                    ),
                  ],
                ),
                if (started) ...[
                  const SizedBox(height: 12),
                  CourseProgressBar(
                    fraction: progress.total == 0
                        ? 0
                        : progress.done / progress.total,
                    color: colors,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (finished) ...[
                        PawIcon(
                          PawIconData.check,
                          size: 16,
                          color: colors.text,
                          strokeWidth: 2.4,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        status,
                        style: PawText.meta13.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
