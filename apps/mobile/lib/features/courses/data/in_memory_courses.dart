import '../../onboarding/domain/models.dart' show AppFailure;
import '../domain/models.dart';
import 'course_seed.dart';
import 'courses_repository.dart';

/// Stand in for the demo build and tests: the ten starter courses, with progress kept in memory.
class InMemoryCoursesRepository implements CoursesRepository {
  InMemoryCoursesRepository({List<Course>? courses, Set<String>? done})
    : _courses = courses ?? starterCourses,
      _done = {...?done};

  List<Course> _courses;
  final Set<String> _done;

  /// Make loading fail with this message (tests).
  String? failWith;

  /// Replace the list, as if the team had changed it in the console (tests).
  void setCourses(List<Course> courses) => _courses = courses;

  Set<String> get done => {..._done};

  @override
  Future<List<Course>> courses() async {
    final message = failWith;
    if (message != null) {
      throw AppFailure(message);
    }
    return List.of(_courses);
  }

  @override
  Future<Set<String>> doneLessonIds() async => {..._done};

  @override
  Future<void> setLessonDone(String lessonId, bool done) async {
    final message = failWith;
    if (message != null) {
      throw AppFailure(message);
    }
    if (done) {
      _done.add(lessonId);
    } else {
      _done.remove(lessonId);
    }
  }
}
