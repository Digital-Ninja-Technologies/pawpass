import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../booking/ui/booking_widgets.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/course_logic.dart';
import '../domain/models.dart';
import 'courses_widgets.dart';

/// One course: a big colourful picture, what it covers, and its lessons with ticks.
class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key, required this.courseId});
  final String courseId;

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  var _asked = false;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context).courses;
    if (!_asked && !c.loaded) {
      // Opened from outside the list (a link, or after a restart): load first.
      _asked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => c.load());
    }
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final course = c.byId(widget.courseId);
        if (course == null) {
          return Scaffold(
            backgroundColor: PawColors.ground,
            body: SafeArea(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(PawSpace.screenSide),
                    child: BookingHeader('Course'),
                  ),
                  Expanded(
                    child: c.loading || !c.loaded && c.loadError == null
                        ? const Center(child: CircularProgressIndicator())
                        : c.loadError != null
                        ? PawErrorState(
                            title: 'We could not load this course',
                            message: c.loadError!,
                            onAction: c.load,
                          )
                        : PawEmptyState(
                            icon: PawIconData.book,
                            tone: PawStateTone.neutral,
                            title: 'This course is not available',
                            message: 'It may have been taken down. Have a look at the other courses.',
                            actionLabel: 'See all courses',
                            onAction: () => context.go('/courses'),
                          ),
                  ),
                ],
              ),
            ),
          );
        }
        final colors = PawCourseColors.byKey(course.accent);
        final p = c.progressOf(course);
        final next = nextLesson(course, c.done);
        final finished = isCourseComplete(course, c.done);
        final started = p.done > 0;
        final first = course.lessons.isEmpty ? null : course.lessons.first;
        final target = next ?? first;
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Container(
                      color: colors.soft,
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(
                                PawSpace.screenSide,
                                12,
                                PawSpace.screenSide,
                                0,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: PawBackButton(),
                              ),
                            ),
                            CourseArt.of(
                              course,
                              height: 210,
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        PawSpace.screenSide,
                        18,
                        PawSpace.screenSide,
                        24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              CoursePill(course.audience.label, color: colors),
                              CoursePill(course.level.label),
                              CoursePill(
                                '${lessonCountLabel(course.lessons.length)} · ${minutesLabel(course.minutes)}',
                                icon: PawIconData.clock,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Semantics(
                            header: true,
                            child: Text(course.title, style: PawText.title28),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            course.summary,
                            style: PawText.body15.copyWith(
                              color: PawColors.ink2,
                            ),
                          ),
                          if (started) ...[
                            const SizedBox(height: 16),
                            CourseProgressBar(
                              fraction: p.total == 0 ? 0 : p.done / p.total,
                              color: colors,
                              height: 12,
                            ),
                            const SizedBox(height: 6),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                finished
                                    ? 'You finished this course. Well done!'
                                    : '${p.done} of ${p.total} lessons done',
                                style: PawText.meta13.copyWith(
                                  color: colors.text,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          const SectionLabel('Lessons'),
                          const SizedBox(height: 8),
                          if (course.lessons.isEmpty)
                            Text(
                              'Lessons are coming soon.',
                              style: PawText.body14.copyWith(
                                color: PawColors.muted,
                              ),
                            )
                          else
                            for (final l in course.lessons)
                              _LessonRow(
                                course: course,
                                lesson: l,
                                done: c.isDone(l.id),
                                colors: colors,
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (target != null)
                PawStickyFooter(
                  children: [
                    PawButton(
                      label: finished
                          ? 'Read it again'
                          : started
                          ? 'Continue'
                          : 'Start course',
                      onPressed: () => context.push(
                        '/courses/${course.id}/lesson/${target.id}',
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.course,
    required this.lesson,
    required this.done,
    required this.colors,
  });

  final Course course;
  final Lesson lesson;
  final bool done;
  final PawCourseColor colors;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label:
          'Lesson ${lesson.position}, ${lesson.title}, ${minutesLabel(lesson.minutes)}. ${done ? 'Done.' : 'Not done yet.'}',
      onTap: () => context.push('/courses/${course.id}/lesson/${lesson.id}'),
      child: InkWell(
        borderRadius: BorderRadius.circular(PawRadius.cardSmall),
        onTap: () => context.push('/courses/${course.id}/lesson/${lesson.id}'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: done ? colors.text : colors.soft,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: done
                      ? const PawIcon(
                          PawIconData.check,
                          size: 20,
                          color: Colors.white,
                          strokeWidth: 2.6,
                        )
                      : Text(
                          '${lesson.position}',
                          style: PawText.body15Strong.copyWith(
                            color: colors.text,
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lesson.title, style: PawText.body15Strong),
                      Text(
                        minutesLabel(lesson.minutes),
                        style: PawText.meta13.copyWith(color: PawColors.muted),
                      ),
                    ],
                  ),
                ),
                const PawIcon(
                  PawIconData.chevronRight,
                  color: PawColors.muted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
