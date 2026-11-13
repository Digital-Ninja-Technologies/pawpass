import '../../onboarding/domain/models.dart' show AppFailure;
import '../domain/models.dart';
import 'course_seed.dart';
import 'courses_repository.dart';

/// Stand in for the demo build and tests: the starter courses, with progress and purchases kept in memory.
/// Like the database, it holds back the text of a paid course's lessons until the course is bought (free previews
/// stay open).
class InMemoryCoursesRepository implements CoursesRepository {
  InMemoryCoursesRepository({
    List<Course>? courses,
    Set<String>? done,
    Set<String>? purchased,
  }) : _courses = courses ?? starterCourses,
       _done = {...?done},
       _purchased = {...?purchased};

  List<Course> _courses;
  final Set<String> _done;
  final Set<String> _purchased;
  final _pending = <String, String>{};
  var _counter = 0;

  /// Make loading and saving fail with this message (tests).
  String? failWith;

  /// Make starting a purchase fail once with this message (tests).
  String? failNextStart;

  /// Every purchase started, in order (tests).
  final started = <CoursePurchase>[];

  /// Replace the list, as if the team had changed it in the console (tests).
  void setCourses(List<Course> courses) => _courses = courses;

  Set<String> get done => {..._done};
  Set<String> get purchased => {..._purchased};

  void _check() {
    final message = failWith;
    if (message != null) {
      throw AppFailure(message);
    }
  }

  bool _open(Course c, Lesson l) =>
      c.isFree || l.preview || _purchased.contains(c.id);

  @override
  Future<List<Course>> courses() async {
    _check();
    return [
      for (final c in _courses)
        Course(
          id: c.id,
          slug: c.slug,
          title: c.title,
          summary: c.summary,
          audience: c.audience,
          level: c.level,
          accent: c.accent,
          art: c.art,
          coverUrl: c.coverUrl,
          sortOrder: c.sortOrder,
          priceKobo: c.priceKobo,
          lessons: [
            for (final l in c.lessons)
              Lesson(
                id: l.id,
                position: l.position,
                title: l.title,
                body: _open(c, l) ? l.body : null,
                minutes: l.minutes,
                preview: l.preview,
              ),
          ],
        ),
    ];
  }

  @override
  Future<Set<String>> doneLessonIds() async => {..._done};

  @override
  Future<void> setLessonDone(String lessonId, bool done) async {
    _check();
    for (final c in _courses) {
      for (final l in c.lessons) {
        if (l.id == lessonId && !_open(c, l)) {
          throw const AppFailure('Unlock this course to read this lesson.');
        }
      }
    }
    if (done) {
      _done.add(lessonId);
    } else {
      _done.remove(lessonId);
    }
  }

  @override
  Future<Set<String>> purchasedCourseIds() async => {..._purchased};

  @override
  Future<CoursePurchase> startPurchase(String courseId) async {
    final f = failNextStart;
    if (f != null) {
      failNextStart = null;
      throw AppFailure(f);
    }
    _check();
    final course = _courses.where((c) => c.id == courseId).firstOrNull;
    if (course == null) {
      throw const AppFailure('That course is not available.');
    }
    if (course.isFree) {
      throw const AppFailure('This course is free, there is nothing to buy.');
    }
    if (_purchased.contains(courseId)) {
      throw const AppFailure('You already have this course.');
    }
    // The same open payment is reused, so tapping Buy twice never makes two.
    final open = started
        .where(
          (p) =>
              _pending[p.reference] == courseId &&
              p.amountKobo == course.priceKobo,
        )
        .lastOrNull;
    if (open != null) {
      return open;
    }
    _counter++;
    final purchase = CoursePurchase(
      id: 'purchase-$_counter',
      reference: 'pc_${_counter.toRadixString(16).padLeft(32, '0')}',
      amountKobo: course.priceKobo,
    );
    _pending[purchase.reference] = courseId;
    started.add(purchase);
    return purchase;
  }

  /// What the payments webhook does once Paystack confirms the money. False if the reference is not a course purchase.
  bool markPaid(String reference) {
    final courseId = _pending[reference];
    if (courseId == null) {
      return false;
    }
    _purchased.add(courseId);
    return true;
  }
}
