import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/course_logic.dart';
import '../domain/models.dart';
import 'courses_widgets.dart';

/// One lesson: short, friendly text with bullets and tip cards, and a button to mark it done and move on.
class LessonScreen extends StatefulWidget {
  const LessonScreen({
    super.key,
    required this.courseId,
    required this.lessonId,
  });

  final String courseId;
  final String lessonId;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  var _asked = false;
  var _busy = false;

  Future<void> _finish(Course course, Lesson lesson) async {
    if (_busy) {
      return;
    }
    final c = AppScope.of(context).courses;
    setState(() => _busy = true);
    final ok = await c.setLessonDone(lesson.id, true);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (!ok) {
      _say(c.actionError ?? 'We could not save that. Please try again.');
      return;
    }
    final next = lessonAfter(course, lesson);
    if (next != null) {
      context.pushReplacement('/courses/${course.id}/lesson/${next.id}');
      return;
    }
    if (isCourseComplete(course, c.done)) {
      await showDialog<void>(
        context: context,
        builder: (_) => _Celebration(course: course),
      );
      if (!mounted) {
        return;
      }
    }
    context.pop();
  }

  Future<void> _undo(Lesson lesson) async {
    if (_busy) {
      return;
    }
    final c = AppScope.of(context).courses;
    setState(() => _busy = true);
    final ok = await c.setLessonDone(lesson.id, false);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (!ok) {
      _say(c.actionError ?? 'We could not save that. Please try again.');
    }
  }

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context).courses;
    if (!_asked && !c.loaded) {
      _asked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => c.load());
    }
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final course = c.byId(widget.courseId);
        final lesson = course == null
            ? null
            : c.lessonById(course, widget.lessonId);
        if (course == null || lesson == null) {
          return Scaffold(
            backgroundColor: PawColors.ground,
            body: SafeArea(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(PawSpace.screenSide),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: PawBackButton(),
                    ),
                  ),
                  Expanded(
                    child: c.loading || !c.loaded && c.loadError == null
                        ? const Center(child: CircularProgressIndicator())
                        : PawEmptyState(
                            icon: PawIconData.book,
                            tone: PawStateTone.neutral,
                            title: 'This lesson is not available',
                            message: 'It may have been changed or taken down. Have a look at the courses.',
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
        final done = c.isDone(lesson.id);
        final next = lessonAfter(course, lesson);
        final blocks = parseLessonBody(lesson.body);
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
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            PawSpace.screenSide,
                            12,
                            PawSpace.screenSide,
                            18,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const PawBackButton(),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      course.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: PawText.body14Strong.copyWith(
                                        color: colors.text,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'LESSON ${lesson.position} OF ${course.lessons.length}',
                                          style: PawText.overline12.copyWith(
                                            color: colors.text,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Semantics(
                                          header: true,
                                          child: Text(
                                            lesson.title,
                                            style: PawText.title28.copyWith(
                                              color: PawColors.ink,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        CoursePill(
                                          '${minutesLabel(lesson.minutes)} to read',
                                          icon: PawIconData.clock,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 96,
                                    height: 80,
                                    child: CourseArt(
                                      accent: course.accent,
                                      art: course.art,
                                      coverUrl: null,
                                      height: 80,
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        PawSpace.screenSide,
                        20,
                        PawSpace.screenSide,
                        28,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final b in blocks) ...[
                            _Block(block: b, colors: colors),
                            const SizedBox(height: 14),
                          ],
                          if (done)
                            Semantics(
                              liveRegion: true,
                              child: CoursePill(
                                'Done',
                                color: colors,
                                icon: PawIconData.check,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              PawStickyFooter(
                children: [
                  PawButton(
                    label: done
                        ? (next != null ? 'Next lesson' : 'Back to the course')
                        : (next != null
                              ? 'Done, next lesson'
                              : 'Finish course'),
                    loading: _busy,
                    onPressed: done
                        ? () => next != null
                              ? context.pushReplacement(
                                  '/courses/${course.id}/lesson/${next.id}',
                                )
                              : context.pop()
                        : () => _finish(course, lesson),
                  ),
                  if (done)
                    TextButton(
                      onPressed: _busy ? null : () => _undo(lesson),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(PawSize.touch),
                      ),
                      child: Text(
                        'Mark as not done',
                        style: PawText.body14Strong.copyWith(
                          color: PawColors.primaryText,
                        ),
                      ),
                    )
                  else if (next != null)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => context.pushReplacement(
                              '/courses/${course.id}/lesson/${next.id}',
                            ),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(PawSize.touch),
                      ),
                      child: Text(
                        'Skip for now',
                        style: PawText.body14Strong.copyWith(
                          color: PawColors.primaryText,
                        ),
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

class _Block extends StatelessWidget {
  const _Block({required this.block, required this.colors});
  final LessonBlock block;
  final PawCourseColor colors;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      ParagraphBlock(:final text) => Text(text, style: PawText.body15),
      BulletsBlock(:final items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 12),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors.strong,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(child: Text(item, style: PawText.body15)),
                ],
              ),
            ),
        ],
      ),
      TipBlock(:final text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.soft,
          borderRadius: BorderRadius.circular(PawRadius.cardSmall),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PawIcon(PawIconData.paw, color: colors.text, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Tip: ',
                      style: PawText.body14Strong.copyWith(color: colors.text),
                    ),
                    TextSpan(
                      text: text,
                      style: PawText.body14.copyWith(color: PawColors.ink),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    };
  }
}

/// Shown when the last lesson of a course is done.
class _Celebration extends StatelessWidget {
  const _Celebration({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) {
    final colors = PawCourseColors.byKey(course.accent);
    return Dialog(
      backgroundColor: PawColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PawRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CourseArt(
              accent: 'sunny',
              art: 'tricks',
              height: 150,
              radius: BorderRadius.all(Radius.circular(PawRadius.cardSmall)),
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                'Course complete!',
                style: PawText.title28.copyWith(color: colors.text),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You finished ${course.title}. Time for a treat and a cuddle.',
              style: PawText.body15,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            PawButton(label: 'Lovely', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}
