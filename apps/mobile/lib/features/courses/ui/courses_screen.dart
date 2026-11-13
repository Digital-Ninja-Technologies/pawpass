import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../booking/ui/booking_widgets.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/course_logic.dart';
import '../domain/models.dart';
import '../state/courses_controller.dart';
import 'courses_widgets.dart';

/// Courses for puppies and dogs: a friendly list with a filter, a "keep going" card and a progress card.
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  var _asked = false;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context).courses;
    if (!_asked) {
      _asked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => c.load());
    }
    return Scaffold(
      backgroundColor: PawColors.ground,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            if (!c.loaded && c.loading) {
              return Semantics(
                label: 'Loading courses',
                child: const Center(child: CircularProgressIndicator()),
              );
            }
            if (!c.loaded && c.loadError != null) {
              return Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(PawSpace.screenSide),
                    child: BookingHeader('Courses'),
                  ),
                  Expanded(
                    child: PawErrorState(
                      title: 'We could not load the courses',
                      message: c.loadError!,
                      onAction: c.load,
                    ),
                  ),
                ],
              );
            }
            return RefreshIndicator(
              onRefresh: c.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  PawSpace.screenSide,
                  12,
                  PawSpace.screenSide,
                  32,
                ),
                children: [
                  const BookingHeader('Courses'),
                  const SizedBox(height: 14),
                  _Hero(c: c),
                  if (courseInProgress(c.courses, c.done) case final next?) ...[
                    const SizedBox(height: 18),
                    _KeepGoing(course: next, c: c),
                  ],
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in CourseFilter.values)
                        PawChip(
                          label: f.label,
                          selected: c.filter == f,
                          onTap: () => c.setFilter(f),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (c.visible.isEmpty)
                    SizedBox(
                      height: 320,
                      child: PawEmptyState(
                        icon: PawIconData.book,
                        tone: PawStateTone.neutral,
                        title: c.courses.isEmpty
                            ? 'No courses yet'
                            : 'No courses for that',
                        message: c.courses.isEmpty
                            ? 'New courses are on the way. Check back soon.'
                            : 'Try another filter to see more courses.',
                        actionLabel: c.courses.isEmpty ? null : 'Show all',
                        onAction: c.courses.isEmpty
                            ? null
                            : () => c.setFilter(CourseFilter.all),
                      ),
                    )
                  else
                    for (final course in c.visible) ...[
                      CourseCard(
                        course: course,
                        progress: c.progressOf(course),
                        onTap: () => context.push('/courses/${course.id}'),
                      ),
                      const SizedBox(height: 16),
                    ],
                  const SizedBox(height: 4),
                  Text(
                    'These courses are friendly guides, not a replacement for your vet or a trainer.',
                    textAlign: TextAlign.center,
                    style: PawText.meta12.copyWith(color: PawColors.muted),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The colourful intro card, with how many lessons the person has finished.
class _Hero extends StatelessWidget {
  const _Hero({required this.c});
  final CoursesController c;

  @override
  Widget build(BuildContext context) {
    final total = c.courses.fold<int>(0, (n, x) => n + x.lessons.length);
    final doneCount = c.courses.fold<int>(
      0,
      (n, x) => n + courseProgress(x, c.done).done,
    );
    final colors = PawCourseColors.sunny;
    return Container(
      decoration: BoxDecoration(
        color: colors.soft,
        borderRadius: BorderRadius.circular(PawRadius.card),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Little lessons, big tail wags',
                  style: PawText.heading22.copyWith(color: colors.text),
                ),
                const SizedBox(height: 6),
                Text(
                  total == 0
                      ? 'Short, fun lessons for puppies and dogs.'
                      : doneCount == 0
                      ? '$total short lessons to try. Five minutes is plenty.'
                      : '$doneCount of $total lessons done. Keep it up!',
                  style: PawText.body14.copyWith(color: PawColors.ink),
                ),
                if (total > 0 && doneCount > 0) ...[
                  const SizedBox(height: 10),
                  CourseProgressBar(
                    fraction: doneCount / total,
                    color: colors,
                    height: 12,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          const SizedBox(
            width: 104,
            height: 90,
            child: CourseArt(
              accent: 'sunny',
              art: 'tricks',
              height: 90,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeepGoing extends StatelessWidget {
  const _KeepGoing({required this.course, required this.c});
  final Course course;
  final CoursesController c;

  @override
  Widget build(BuildContext context) {
    final colors = PawCourseColors.byKey(course.accent);
    final next = nextLesson(course, c.done);
    final p = c.progressOf(course);
    return PawCard(
      color: colors.soft,
      radius: PawRadius.card,
      onTap: () => next == null
          ? context.push('/courses/${course.id}')
          : context.push('/courses/${course.id}/lesson/${next.id}'),
      semanticLabel:
          'Keep going: ${course.title}. ${next == null ? '' : 'Next lesson, ${next.title}.'}',
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CourseArt.of(
              course,
              height: 72,
              radius: BorderRadius.circular(18),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Keep going'),
                const SizedBox(height: 2),
                Text(
                  course.title,
                  style: PawText.body15Strong.copyWith(color: colors.text),
                ),
                if (next != null)
                  Text(
                    'Next: ${next.title}',
                    style: PawText.meta13.copyWith(color: PawColors.ink),
                  ),
                const SizedBox(height: 8),
                CourseProgressBar(
                  fraction: p.total == 0 ? 0 : p.done / p.total,
                  color: colors,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PawIcon(PawIconData.chevronRight, color: colors.text),
        ],
      ),
    );
  }
}
