import 'package:flutter/foundation.dart';

import '../../onboarding/data/repositories.dart';
import '../../onboarding/domain/models.dart';
import '../../onboarding/state/session_controller.dart';
import '../domain/course_logic.dart';
import '../domain/models.dart';

/// The courses list, which lessons the person has finished, and the filter on the list.
/// One of these is shared by the list, course and lesson screens, so a tick shows up everywhere at once.
/// Forgets everything on sign out.
class CoursesController extends ChangeNotifier {
  CoursesController(this._services, this._session) {
    _session.addListener(_onSession);
  }

  final AppServices _services;
  final SessionController _session;
  var _disposed = false;

  List<Course> courses = const [];
  Set<String> done = const {};
  var filter = CourseFilter.all;
  var loading = false;
  var loaded = false;
  String? loadError;

  /// Shown after a failed tick. Cleared by the next successful one.
  String? actionError;

  List<Course> get visible => filterCourses(courses, filter);

  Course? byId(String id) {
    for (final c in courses) {
      if (c.id == id) {
        return c;
      }
    }
    return null;
  }

  Lesson? lessonById(Course course, String lessonId) {
    for (final l in course.lessons) {
      if (l.id == lessonId) {
        return l;
      }
    }
    return null;
  }

  bool isDone(String lessonId) => done.contains(lessonId);

  ({int done, int total}) progressOf(Course course) =>
      courseProgress(course, done);

  /// Loads courses and progress. Keeps what is on screen while refreshing, and only shows the error when there is
  /// nothing to show.
  Future<void> load() async {
    if (loading) {
      return;
    }
    loading = true;
    loadError = null;
    _notify();
    try {
      courses = await _services.courses.courses();
      done = await _services.courses.doneLessonIds();
      loaded = true;
    } on AppFailure catch (e) {
      loadError = e.message;
    } catch (_) {
      loadError = 'We could not load the courses. Please try again.';
    } finally {
      loading = false;
      _notify();
    }
  }

  void setFilter(CourseFilter value) {
    if (filter == value) {
      return;
    }
    filter = value;
    _notify();
  }

  /// Ticks or unticks a lesson. The tick shows at once and goes back if saving fails.
  Future<bool> setLessonDone(String lessonId, bool value) async {
    if (isDone(lessonId) == value) {
      return true;
    }
    final before = done;
    done = value ? {...done, lessonId} : ({...done}..remove(lessonId));
    actionError = null;
    _notify();
    try {
      await _services.courses.setLessonDone(lessonId, value);
      return true;
    } on AppFailure catch (e) {
      done = before;
      actionError = e.message;
      _notify();
      return false;
    } catch (_) {
      done = before;
      actionError = 'We could not save that. Please try again.';
      _notify();
      return false;
    }
  }

  void _onSession() {
    if (_disposed) {
      return;
    }
    if (_session.status == SessionStatus.signedOut) {
      reset();
    }
  }

  void reset() {
    courses = const [];
    done = const {};
    filter = CourseFilter.all;
    loading = false;
    loaded = false;
    loadError = null;
    actionError = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _session.removeListener(_onSession);
    super.dispose();
  }
}
