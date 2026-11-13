import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/app.dart';
import 'package:pawpass/features/adopt/data/in_memory_adopt.dart';
import 'package:pawpass/features/booking/data/in_memory_bookings.dart';
import 'package:pawpass/features/community/data/in_memory_community.dart';
import 'package:pawpass/features/courses/data/course_seed.dart';
import 'package:pawpass/features/courses/data/in_memory_courses.dart';
import 'package:pawpass/features/courses/domain/models.dart';
import 'package:pawpass/features/health/data/in_memory_health.dart';
import 'package:pawpass/features/onboarding/data/in_memory.dart';
import 'package:pawpass/features/onboarding/data/repositories.dart';
import 'package:pawpass/features/onboarding/domain/models.dart';
import 'package:pawpass/features/courses/ui/course_screen.dart';
import 'package:pawpass/features/courses/ui/courses_widgets.dart';
import 'package:pawpass/features/onboarding/state/app_scope.dart';
import 'package:pawpass/features/partner/data/in_memory_partner.dart';
import 'package:pawpass/ui/ui.dart';

final _today = DateTime.utc(2026, 11, 5, 8);

class _Rig {
  _Rig({List<Course>? courses, Set<String>? done}) {
    profiles = InMemoryProfileRepository();
    pets = InMemoryPetRepository(profiles: profiles, now: () => _today);
    bookings = InMemoryBookingsRepository(now: () => _today);
    adopt = InMemoryAdoptRepository(now: () => _today);
    this.courses = InMemoryCoursesRepository(courses: courses, done: done);
    services = AppServices(
      auth: InMemoryAuthRepository(signedInAs: 'tolu@example.com'),
      profiles: profiles,
      pets: pets,
      photos: NoPhotoPicker(),
      emailApp: NoEmailApp(),
      health: InMemoryHealthRepository(now: () => _today),
      notifications: InMemoryNotificationsRepository(),
      vets: InMemoryVetsRepository(),
      location: FakeLocationService(),
      links: FakeLinkLauncher(),
      bookings: bookings,
      payments: InMemoryPaymentsRepository(bookings, others: [adopt.markPaid]),
      community: InMemoryCommunityRepository(now: () => _today),
      adopt: adopt,
      partner: InMemoryPartnerRepository(now: () => _today),
      courses: this.courses,
      now: () => _today,
    );
  }

  late final InMemoryProfileRepository profiles;
  late final InMemoryPetRepository pets;
  late final InMemoryBookingsRepository bookings;
  late final InMemoryAdoptRepository adopt;
  late final InMemoryCoursesRepository courses;
  late final AppServices services;

  Future<void> seed() async {
    await profiles.save(firstName: 'Tolu', lastName: 'Adeyemi', area: 'Lekki');
    profiles.markOnboarded(_today);
    await pets.createPassport(
      pet: PetInput(
        name: 'Bingo',
        species: Species.dog,
        breed: 'Boerboel',
        sex: PetSex.male,
        dateOfBirth: DateTime(2024, 8, 14),
      ),
      records: const [],
      channels: {ReminderChannel.push},
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Rig rig, {
  Size size = const Size(390, 844),
  double scale = 1.0,
}) async {
  await rig.seed();
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
      child: PawPassApp(services: rig.services),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  await _see(tester, text);
  await tester.ensureVisible(find.text(text).first);
  await tester.pump();
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

/// Taps a course on the list (not the "Keep going" card, which has the same title).
Future<void> _openCourse(WidgetTester tester, String title) async {
  final card = find.descendant(
    of: find.byType(CourseCard),
    matching: find.text(title),
  );
  for (var i = 0; i < 40 && card.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pump();
  }
  await tester.ensureVisible(card.first);
  await tester.pump();
  await tester.tap(card.first);
  await tester.pumpAndSettle();
}

/// Scrolls the first list back to the top.
Future<void> _top(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Scrolls the first list until [text] is built and on screen.
Future<void> _see(WidgetTester tester, String text) async {
  for (var i = 0; i < 40 && find.text(text).evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byType(PawBackButton).first);
  await tester.pumpAndSettle();
}

Future<void> _openCourses(WidgetTester tester) =>
    _tap(tester, 'Courses for happy dogs');

Course _course(
  String id,
  String title, {
  CourseAudience a = CourseAudience.both,
  int lessons = 2,
}) => Course(
  id: id,
  slug: id,
  title: title,
  summary: 'About $title',
  audience: a,
  level: CourseLevel.beginner,
  accent: 'mint',
  art: 'paw',
  lessons: [
    for (var i = 1; i <= lessons; i++)
      Lesson(
        id: '$id-l$i',
        position: i,
        title: '$title lesson $i',
        body:
            'Body $i.\n\n- First point\n- Second point\n\nTip: a helpful tip $i.',
        minutes: 3,
      ),
  ],
);

void main() {
  group('Courses list', () {
    testWidgets('opens from Home and lists the starter courses', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      expect(find.text('Courses for happy dogs'), findsOneWidget);
      await _openCourses(tester);
      expect(find.text('Courses'), findsOneWidget);
      expect(find.text('Little lessons, big tail wags'), findsOneWidget);
      expect(find.text('Welcome home, puppy'), findsOneWidget);
      // The rest are further down the list.
      await tester.scrollUntilVisible(
        find.text('Happy and healthy'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Happy and healthy'), findsOneWidget);
      await _see(
        tester,
        'These courses are friendly guides, not a replacement for your vet or a trainer.',
      );
    });

    testWidgets(
      'the Dogs filter hides puppy only courses and All brings them back',
      (tester) async {
        final rig = _Rig();
        await _pump(tester, rig);
        await _openCourses(tester);
        await _tap(tester, 'Dogs');
        expect(find.text('Welcome home, puppy'), findsNothing);
        await _see(tester, 'Come when called');
        expect(find.text('Come when called'), findsOneWidget);
        await _top(tester);
        await _tap(tester, 'Puppies');
        expect(find.text('Welcome home, puppy'), findsOneWidget);
        expect(find.text('Come when called'), findsNothing);
        await _tap(tester, 'All');
        expect(find.text('Welcome home, puppy'), findsOneWidget);
      },
    );

    testWidgets('an empty filter says so and Show all recovers', (
      tester,
    ) async {
      final rig = _Rig(
        courses: [_course('a', 'Only for dogs', a: CourseAudience.dog)],
      );
      await _pump(tester, rig);
      await _openCourses(tester);
      await _tap(tester, 'Puppies');
      expect(find.text('No courses for that'), findsOneWidget);
      await _tap(tester, 'Show all');
      expect(find.text('Only for dogs'), findsOneWidget);
    });

    testWidgets('no courses at all is an honest empty state', (tester) async {
      final rig = _Rig(courses: const []);
      await _pump(tester, rig);
      await _openCourses(tester);
      expect(find.text('No courses yet'), findsOneWidget);
    });

    testWidgets('a failed load shows the reason and Try again works', (
      tester,
    ) async {
      final rig = _Rig();
      rig.courses.failWith =
          'No connection. Check your internet and try again.';
      await _pump(tester, rig);
      await _openCourses(tester);
      expect(find.text('We could not load the courses'), findsOneWidget);
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );
      rig.courses.failWith = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome home, puppy'), findsOneWidget);
    });
  });

  group('A course and its lessons', () {
    testWidgets(
      'start, finish a lesson, see progress, and keep going from the list',
      (tester) async {
        final rig = _Rig(courses: [_course('a', 'Sit and stay', lessons: 3)]);
        await _pump(tester, rig);
        await _openCourses(tester);
        await _openCourse(tester, 'Sit and stay');
        expect(find.text('3 lessons · 9 mins'), findsOneWidget);
        expect(find.text('Sit and stay lesson 2'), findsOneWidget);
        expect(find.text('Start course'), findsOneWidget);

        await _tap(tester, 'Start course');
        expect(find.text('LESSON 1 OF 3'), findsOneWidget);
        expect(find.text('Body 1.'), findsOneWidget);
        expect(find.text('First point'), findsOneWidget);
        expect(find.textContaining('a helpful tip 1.'), findsOneWidget);

        await _tap(tester, 'Done, next lesson');
        expect(rig.courses.done, {'a-l1'});
        expect(find.text('LESSON 2 OF 3'), findsOneWidget);

        await _back(tester);
        expect(find.text('1 of 3 lessons done'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);
        await _back(tester);
        expect(find.text('KEEP GOING'), findsOneWidget);
        expect(find.text('Next: Sit and stay lesson 2'), findsOneWidget);
        expect(find.text('1 of 3 lessons done'), findsWidgets);
      },
    );

    testWidgets(
      'finishing the last lesson celebrates and returns to the course',
      (tester) async {
        final rig = _Rig(
          courses: [_course('a', 'Sit and stay', lessons: 2)],
          done: {'a-l1'},
        );
        await _pump(tester, rig);
        await _openCourses(tester);
        await _openCourse(tester, 'Sit and stay');
        await _tap(tester, 'Continue');
        expect(find.text('LESSON 2 OF 2'), findsOneWidget);
        expect(find.text('Finish course'), findsOneWidget);
        await _tap(tester, 'Finish course');
        expect(find.text('Course complete!'), findsOneWidget);
        await _tap(tester, 'Lovely');
        expect(rig.courses.done, {'a-l1', 'a-l2'});
        expect(
          find.text('You finished this course. Well done!'),
          findsOneWidget,
        );
        expect(find.text('Read it again'), findsOneWidget);
      },
    );

    testWidgets('a lesson can be marked not done again', (tester) async {
      final rig = _Rig(courses: [_course('a', 'Sit and stay')], done: {'a-l1'});
      await _pump(tester, rig);
      await _openCourses(tester);
      await _openCourse(tester, 'Sit and stay');
      await _tap(tester, 'Sit and stay lesson 1');
      expect(find.text('Done'), findsOneWidget);
      await _tap(tester, 'Mark as not done');
      expect(rig.courses.done, isEmpty);
      expect(find.text('Done, next lesson'), findsOneWidget);
    });

    testWidgets('a failed save goes back and says why', (tester) async {
      final rig = _Rig(courses: [_course('a', 'Sit and stay')]);
      await _pump(tester, rig);
      await _openCourses(tester);
      await _openCourse(tester, 'Sit and stay');
      await _tap(tester, 'Start course');
      rig.courses.failWith =
          'No connection. Check your internet and try again.';
      await _tap(tester, 'Done, next lesson');
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );
      expect(rig.courses.done, isEmpty);
      expect(find.text('LESSON 1 OF 2'), findsOneWidget);
    });

    testWidgets('a course taken down while open says so instead of breaking', (
      tester,
    ) async {
      final rig = _Rig(courses: [_course('a', 'Sit and stay')]);
      await _pump(tester, rig);
      await _openCourses(tester);
      await _openCourse(tester, 'Sit and stay');
      rig.courses.setCourses(const []);
      // The next refresh (here forced) no longer has the course.
      final scope = AppScope.of(tester.element(find.byType(CourseScreen)));
      await scope.courses.load();
      await tester.pumpAndSettle();
      expect(find.text('This course is not available'), findsOneWidget);
      await _tap(tester, 'See all courses');
      expect(find.text('No courses yet'), findsOneWidget);
    });
  });

  group('small phone with large text', () {
    testWidgets('the list, a course and a lesson fit', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig, size: const Size(320, 568), scale: 1.3);
      await _openCourses(tester);
      expect(tester.takeException(), isNull);
      await _openCourse(tester, 'Welcome home, puppy');
      expect(tester.takeException(), isNull);
      await _tap(tester, 'Start course');
      expect(find.text('LESSON 1 OF 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _tap(tester, 'Done, next lesson');
      expect(tester.takeException(), isNull);
    });
  });

  group('every starter course opens', () {
    testWidgets('and each lesson shows its title', (tester) async {
      final rig = _Rig(courses: starterCourses);
      await _pump(tester, rig);
      await _openCourses(tester);
      for (final c in starterCourses.take(3)) {
        await _openCourse(tester, c.title);
        for (final l in c.lessons) {
          expect(find.text(l.title), findsWidgets);
        }
        await _back(tester);
      }
    });
  });
}
