import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/features/courses/data/course_seed.dart';
import 'package:pawpass/features/courses/domain/course_logic.dart';
import 'package:pawpass/features/courses/domain/models.dart';

Lesson _lesson(String id, int position, {int minutes = 2}) => Lesson(
  id: id,
  position: position,
  title: 'Lesson $position',
  body: 'Text',
  minutes: minutes,
);

Course _course({
  String id = 'c1',
  CourseAudience audience = CourseAudience.both,
  List<Lesson>? lessons,
}) => Course(
  id: id,
  slug: id,
  title: 'Course $id',
  summary: 'A course',
  audience: audience,
  level: CourseLevel.beginner,
  accent: 'sunny',
  art: 'paw',
  lessons: lessons ?? [_lesson('a', 1), _lesson('b', 2), _lesson('c', 3)],
);

void main() {
  group('parseLessonBody', () {
    test('splits paragraphs on blank lines', () {
      final blocks = parseLessonBody('First.\n\nSecond line\nstill second.');
      expect(blocks, hasLength(2));
      expect((blocks[0] as ParagraphBlock).text, 'First.');
      expect((blocks[1] as ParagraphBlock).text, 'Second line still second.');
    });

    test('groups bullet lines, including right after a paragraph', () {
      final blocks = parseLessonBody('Do these:\n- One\n- Two\n\nDone.');
      expect(blocks, hasLength(3));
      expect((blocks[0] as ParagraphBlock).text, 'Do these:');
      expect((blocks[1] as BulletsBlock).items, ['One', 'Two']);
      expect((blocks[2] as ParagraphBlock).text, 'Done.');
    });

    test('a paragraph starting Tip: becomes a tip without the prefix', () {
      final blocks = parseLessonBody('Hello.\n\nTip: keep it short.');
      expect((blocks.last as TipBlock).text, 'keep it short.');
    });

    test(
      'an empty tip stays a plain paragraph, and empty text gives nothing',
      () {
        expect(parseLessonBody('Tip:').single, isA<ParagraphBlock>());
        expect(parseLessonBody('   \n\n  '), isEmpty);
      },
    );

    test('handles Windows line endings and stray spaces', () {
      final blocks = parseLessonBody('  One  \r\n\r\n- A \r\n- B\r\n');
      expect(blocks, hasLength(2));
      expect((blocks[1] as BulletsBlock).items, ['A', 'B']);
    });

    test('every starter lesson parses into something readable', () {
      for (final c in starterCourses) {
        for (final l in c.lessons) {
          expect(parseLessonBody(l.body!), isNotEmpty, reason: l.title);
        }
      }
    });
  });

  group('filterCourses', () {
    final puppy = _course(id: 'p', audience: CourseAudience.puppy);
    final dog = _course(id: 'd', audience: CourseAudience.dog);
    final both = _course(id: 'b');
    final all = [puppy, dog, both];

    test('all keeps everything', () {
      expect(filterCourses(all, CourseFilter.all), all);
    });

    test('puppies keeps puppy and both', () {
      expect(filterCourses(all, CourseFilter.puppies), [puppy, both]);
    });

    test('dogs keeps dog and both', () {
      expect(filterCourses(all, CourseFilter.dogs), [dog, both]);
    });
  });

  group('progress', () {
    final course = _course();

    test('counts only lessons that are in the course', () {
      final p = courseProgress(course, {'a', 'c', 'gone'});
      expect(p.done, 2);
      expect(p.total, 3);
    });

    test('started, complete and next lesson', () {
      expect(isCourseStarted(course, {}), isFalse);
      expect(nextLesson(course, {})!.id, 'a');
      expect(isCourseStarted(course, {'b'}), isTrue);
      expect(nextLesson(course, {'a', 'b'})!.id, 'c');
      expect(isCourseComplete(course, {'a', 'b'}), isFalse);
      expect(isCourseComplete(course, {'a', 'b', 'c'}), isTrue);
      expect(nextLesson(course, {'a', 'b', 'c'}), isNull);
    });

    test('next lesson skips ahead of a gap', () {
      expect(nextLesson(course, {'b'})!.id, 'a');
    });

    test('a course with no lessons is never complete', () {
      final empty = _course(lessons: const []);
      expect(isCourseComplete(empty, {}), isFalse);
      expect(nextLesson(empty, {}), isNull);
    });

    test('lessonAfter follows the order and stops at the end', () {
      expect(lessonAfter(course, course.lessons[0])!.id, 'b');
      expect(lessonAfter(course, course.lessons[2]), isNull);
      expect(lessonAfter(course, _lesson('zzz', 9)), isNull);
    });

    test('courseInProgress is the first started, unfinished course', () {
      final c1 = _course(id: 'one');
      final c2 = Course(
        id: 'two',
        slug: 'two',
        title: 'Two',
        summary: 'Two',
        audience: CourseAudience.dog,
        level: CourseLevel.beginner,
        accent: 'sky',
        art: 'paw',
        lessons: [_lesson('x', 1), _lesson('y', 2)],
      );
      expect(courseInProgress([c1, c2], {}), isNull);
      expect(courseInProgress([c1, c2], {'x'}), c2);
      expect(courseInProgress([c1, c2], {'x', 'y'}), isNull);
    });
  });

  group('labels', () {
    test('minutes are never zero and say min or mins', () {
      expect(minutesLabel(0), '1 min');
      expect(minutesLabel(1), '1 min');
      expect(minutesLabel(12), '12 mins');
    });

    test('lesson counts', () {
      expect(lessonCountLabel(1), '1 lesson');
      expect(lessonCountLabel(5), '5 lessons');
    });

    test('a course adds up its lessons', () {
      expect(_course().minutes, 6);
    });
  });

  group('starter courses', () {
    test('there are eleven, each with lessons, in a set order', () {
      expect(starterCourses, hasLength(11));
      expect(starterCourses.every((c) => c.lessons.isNotEmpty), isTrue);
      final orders = starterCourses.map((c) => c.sortOrder).toList();
      expect(orders, [...orders]..sort());
      expect(orders.toSet(), hasLength(11));
    });

    test('there are courses for puppies and for grown dogs', () {
      expect(
        filterCourses(starterCourses, CourseFilter.puppies).length,
        greaterThan(5),
      );
      expect(
        filterCourses(starterCourses, CourseFilter.dogs).length,
        greaterThan(5),
      );
    });

    test('ids are unique and no copy has an em dash', () {
      final ids = {
        for (final c in starterCourses) c.id,
        for (final c in starterCourses)
          for (final l in c.lessons) l.id,
      };
      expect(
        ids.length,
        starterCourses.length +
            starterCourses.fold<int>(0, (n, c) => n + c.lessons.length),
      );
      for (final c in starterCourses) {
        expect('${c.title}${c.summary}'.contains('—'), isFalse);
        for (final l in c.lessons) {
          expect('${l.title}${l.body}'.contains('—'), isFalse, reason: l.title);
        }
      }
    });
  });

  group('free and paid', () {
    Course paid({List<Lesson>? lessons}) => Course(
      id: 'paid',
      slug: 'paid',
      title: 'Paid course',
      summary: 'A paid course',
      audience: CourseAudience.both,
      level: CourseLevel.beginner,
      accent: 'sky',
      art: 'paw',
      priceKobo: 250000,
      lessons:
          lessons ??
          [
            const Lesson(
              id: 'p1',
              position: 1,
              title: 'Free taste',
              body: 'Open',
              minutes: 2,
              preview: true,
            ),
            const Lesson(
              id: 'p2',
              position: 2,
              title: 'Locked',
              body: null,
              minutes: 2,
            ),
          ],
    );

    test('a course with no price is free', () {
      expect(_course().isFree, isTrue);
      expect(_course().isPaid, isFalse);
      expect(paid().isPaid, isTrue);
      expect(paid().isFree, isFalse);
    });

    test('a lesson with no text is locked', () {
      final c = paid();
      expect(c.lessons[0].locked, isFalse);
      expect(c.lessons[1].locked, isTrue);
      expect(lockedLessonCount(c), 1);
      expect(lockedLessonCount(_course()), 0);
    });

    test('access: free courses always, paid courses once bought', () {
      expect(hasAccess(_course(), {}), isTrue);
      expect(hasAccess(paid(), {}), isFalse);
      expect(hasAccess(paid(), {'other'}), isFalse);
      expect(hasAccess(paid(), {'paid'}), isTrue);
    });

    test('price labels', () {
      expect(priceLabel(_course(), owned: true), 'Free');
      expect(priceLabel(paid(), owned: false), '₦2,500');
      expect(priceLabel(paid(), owned: true), 'Unlocked');
    });

    test(
      'the price filter keeps free or paid, alongside the audience filter',
      () {
        final free = _course(id: 'f');
        final dogPaid = Course(
          id: 'dp',
          slug: 'dp',
          title: 'Dog paid',
          summary: 'x',
          audience: CourseAudience.dog,
          level: CourseLevel.beginner,
          accent: 'sky',
          art: 'paw',
          priceKobo: 100000,
          lessons: const [],
        );
        final all = [free, paid(), dogPaid];
        expect(filterCourses(all, CourseFilter.all), hasLength(3));
        expect(filterCourses(all, CourseFilter.all, price: PriceFilter.free), [
          free,
        ]);
        expect(
          filterCourses(
            all,
            CourseFilter.all,
            price: PriceFilter.paid,
          ).map((c) => c.id),
          ['paid', 'dp'],
        );
        expect(
          filterCourses(
            all,
            CourseFilter.puppies,
            price: PriceFilter.paid,
          ).map((c) => c.id),
          ['paid'],
        );
      },
    );

    test('keep going never offers a lesson that is still locked', () {
      final c = paid();
      // Only the free preview is done: the next lesson is locked, so there is nothing to continue.
      expect(courseInProgress([c], {'p1'}), isNull);
      // Once the lesson text is there (bought), it is offered.
      final bought = paid(
        lessons: [
          c.lessons[0],
          const Lesson(
            id: 'p2',
            position: 2,
            title: 'Now open',
            body: 'Open',
            minutes: 2,
          ),
        ],
      );
      expect(courseInProgress([bought], {'p1'}), bought);
    });
  });
}
