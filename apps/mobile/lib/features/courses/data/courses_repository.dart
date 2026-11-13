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

  /// Ids of the paid courses the person has bought.
  Future<Set<String>> purchasedCourseIds();

  /// Starts a purchase that waits for payment (the same open one if there is one). The price is read on the server.
  /// Throws an AppFailure with a readable message if the course cannot be bought.
  Future<CoursePurchase> startPurchase(String courseId);
}
