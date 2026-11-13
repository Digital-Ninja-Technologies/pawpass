import '../domain/models.dart';

/// Published courses and the signed in person's progress through them.
/// Every rule lives in the database; this only asks. Failures are AppFailures with a readable message.
abstract class CoursesRepository {
  /// Published courses with their lessons, in the order the team chose.
  Future<List<Course>> courses();

  /// Ids of the lessons the person has marked done.
  Future<Set<String>> doneLessonIds();

  /// Marks a lesson done (or not done). Saying the same thing twice is harmless.
  Future<void> setLessonDone(String lessonId, bool done);
}
