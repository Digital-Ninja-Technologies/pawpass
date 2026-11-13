import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../booking/domain/booking_logic.dart' show nairaFromKobo;
import '../../booking/ui/booking_widgets.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/course_logic.dart';
import '../domain/models.dart';
import '../state/courses_controller.dart';
import 'courses_widgets.dart';

/// One course: a big colourful picture, what it covers, and its lessons with ticks. A paid course the person has not
/// bought shows its price, which lessons are free to try, and a button to unlock it on Paystack.
class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key, required this.courseId});
  final String courseId;

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen>
    with WidgetsBindingObserver {
  var _asked = false;
  CoursesController? _c;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back from the Paystack page checks the payment by itself.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _c;
    if (state == AppLifecycleState.resumed &&
        c != null &&
        c.buyStage == BuyStage.waiting &&
        c.buyingCourseId == widget.courseId) {
      _check(c);
    }
  }

  Future<void> _check(CoursesController c) async {
    final unlocked = await c.checkPurchase();
    if (unlocked && mounted) {
      _say('Unlocked! Enjoy the course.');
    }
  }

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final c = _c = AppScope.of(context).courses;
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
        final owned = c.owns(course);
        final locked = course.isPaid && !owned;
        final p = c.progressOf(course);
        final next = nextLesson(course, c.done);
        final finished = isCourseComplete(course, c.done);
        final started = p.done > 0;
        final first = course.lessons.isEmpty ? null : course.lessons.first;
        final target = next ?? first;
        final preview = course.lessons.where((l) => l.preview).firstOrNull;
        final mine = c.buyingCourseId == course.id;
        final waiting =
            mine &&
            (c.buyStage == BuyStage.waiting || c.buyStage == BuyStage.checking);
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
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                PawSpace.screenSide,
                                12,
                                PawSpace.screenSide,
                                0,
                              ),
                              child: Row(
                                children: [
                                  const PawBackButton(),
                                  const Spacer(),
                                  PricePill(course: course, owned: owned),
                                ],
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
                          if (locked) ...[
                            const SizedBox(height: 16),
                            _UnlockCard(
                              course: course,
                              colors: colors,
                              hasPreview: preview != null,
                              controller: c,
                              mine: mine,
                            ),
                          ] else if (started) ...[
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
                                onLocked: () => _say(
                                  'Unlock this course to read this lesson.',
                                ),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (locked)
                PawStickyFooter(
                  children: waiting
                      ? [
                          Text(
                            'Finish paying on the Paystack page, then come back here. We will check automatically.',
                            textAlign: TextAlign.center,
                            style: PawText.meta12.copyWith(
                              color: PawColors.muted,
                            ),
                          ),
                          PawButton(
                            label: 'I have paid, check now',
                            loading: c.buyStage == BuyStage.checking,
                            onPressed: () => _check(c),
                          ),
                          PawButton(
                            label: 'Not now',
                            variant: PawButtonVariant.secondary,
                            height: 44,
                            onPressed: c.buyStage == BuyStage.checking
                                ? null
                                : c.cancelBuying,
                          ),
                        ]
                      : [
                          PawButton(
                            label:
                                'Unlock for ${nairaFromKobo(course.priceKobo)}',
                            loading: mine && c.buyStage == BuyStage.starting,
                            onPressed: c.buyBusy ? null : () => c.buy(course),
                          ),
                          if (preview != null)
                            PawButton(
                              label: 'Try the free lesson',
                              variant: PawButtonVariant.secondary,
                              height: 44,
                              onPressed: () => context.push(
                                '/courses/${course.id}/lesson/${preview.id}',
                              ),
                            )
                          else
                            Text(
                              "Card, bank transfer or USSD, on Paystack's secure page.",
                              textAlign: TextAlign.center,
                              style: PawText.meta12.copyWith(
                                color: PawColors.muted,
                              ),
                            ),
                        ],
                )
              else if (target != null)
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

/// What buying gets you, and any message about the payment.
class _UnlockCard extends StatelessWidget {
  const _UnlockCard({
    required this.course,
    required this.colors,
    required this.hasPreview,
    required this.controller,
    required this.mine,
  });

  final Course course;
  final PawCourseColor colors;
  final bool hasPreview;
  final CoursesController controller;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final price = nairaFromKobo(course.priceKobo);
    final free = course.lessons.where((l) => l.preview).length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.soft,
        borderRadius: BorderRadius.circular(PawRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PawIcon(PawIconData.lock, color: colors.text, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Unlock this course for $price',
                  style: PawText.heading22.copyWith(color: colors.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'One payment, yours to keep. No subscription. '
            '${hasPreview ? '$free ${free == 1 ? 'lesson is' : 'lessons are'} free to try first.' : ''}',
            style: PawText.body14.copyWith(color: PawColors.ink),
          ),
          if (mine && controller.buyNotice != null) ...[
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Text(
                controller.buyNotice!,
                style: PawText.body14.copyWith(color: PawColors.ink),
              ),
            ),
          ],
          if (mine && controller.buyError != null) ...[
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Text(
                controller.buyError!,
                style: PawText.body14Strong.copyWith(color: PawColors.danger),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.course,
    required this.lesson,
    required this.done,
    required this.colors,
    required this.onLocked,
  });

  final Course course;
  final Lesson lesson;
  final bool done;
  final PawCourseColor colors;
  final VoidCallback onLocked;

  @override
  Widget build(BuildContext context) {
    final locked = lesson.locked;
    void open() => locked
        ? onLocked()
        : context.push('/courses/${course.id}/lesson/${lesson.id}');
    final state = locked
        ? 'Locked.'
        : done
        ? 'Done.'
        : lesson.preview && course.isPaid
        ? 'Free preview.'
        : 'Not done yet.';
    return Semantics(
      button: true,
      excludeSemantics: true,
      label:
          'Lesson ${lesson.position}, ${lesson.title}, ${minutesLabel(lesson.minutes)}. $state',
      onTap: open,
      child: InkWell(
        borderRadius: BorderRadius.circular(PawRadius.cardSmall),
        onTap: open,
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
                  child: locked
                      ? PawIcon(
                          PawIconData.lock,
                          size: 18,
                          color: colors.text,
                          strokeWidth: 2.2,
                        )
                      : done
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
                      Text(
                        lesson.title,
                        style: PawText.body15Strong.copyWith(
                          color: locked ? PawColors.ink2 : PawColors.ink,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            minutesLabel(lesson.minutes),
                            style: PawText.meta13.copyWith(
                              color: PawColors.muted,
                            ),
                          ),
                          if (lesson.preview && course.isPaid) ...[
                            const SizedBox(width: 8),
                            CoursePill('Free preview', color: colors),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (!locked)
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
