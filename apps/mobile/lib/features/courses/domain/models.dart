/// Who a course is for.
enum CourseAudience {
  puppy('puppy', 'Puppies'),
  dog('dog', 'Dogs'),
  both('both', 'Puppies and dogs');

  const CourseAudience(this.value, this.label);
  final String value;
  final String label;

  static CourseAudience from(String? value) => CourseAudience.values.firstWhere(
    (a) => a.value == value,
    orElse: () => CourseAudience.both,
  );
}

enum CourseLevel {
  beginner('beginner', 'Beginner'),
  intermediate('intermediate', 'Intermediate'),
  advanced('advanced', 'Advanced');

  const CourseLevel(this.value, this.label);
  final String value;
  final String label;

  static CourseLevel from(String? value) => CourseLevel.values.firstWhere(
    (l) => l.value == value,
    orElse: () => CourseLevel.beginner,
  );
}

/// One short lesson. [body] is plain text: paragraphs are separated by a blank line, a line starting with "- " is a
/// bullet and a paragraph starting with "Tip: " is shown as a tip (see parseLessonBody).
class Lesson {
  const Lesson({
    required this.id,
    required this.position,
    required this.title,
    required this.body,
    required this.minutes,
    this.preview = false,
  });

  final String id;
  final int position;
  final String title;

  /// The lesson text. Null means it is locked: it belongs to a paid course the person has not bought (the database
  /// does not send it, so it cannot be read until they have).
  final String? body;
  final int minutes;

  /// A free preview: readable without buying the course.
  final bool preview;

  bool get locked => body == null;
}

/// A published course with its lessons, in order.
class Course {
  const Course({
    required this.id,
    required this.slug,
    required this.title,
    required this.summary,
    required this.audience,
    required this.level,
    required this.accent,
    required this.art,
    required this.lessons,
    this.coverUrl,
    this.sortOrder = 100,
    this.priceKobo = 0,
  });

  final String id;
  final String slug;
  final String title;
  final String summary;
  final CourseAudience audience;
  final CourseLevel level;

  /// A colour key (see PawCourseColors).
  final String accent;

  /// An illustration key (a file in assets/course_art, named after the key).
  final String art;

  /// A picture an admin uploaded. When null (or if it fails to load) the illustration is shown.
  final String? coverUrl;
  final int sortOrder;
  final List<Lesson> lessons;

  /// What it costs in kobo. 0 is free.
  final int priceKobo;

  bool get isFree => priceKobo == 0;
  bool get isPaid => priceKobo > 0;

  int get minutes => lessons.fold(0, (sum, l) => sum + l.minutes);
}

/// A purchase waiting for payment: what the app needs to open Paystack.
class CoursePurchase {
  const CoursePurchase({
    required this.id,
    required this.reference,
    required this.amountKobo,
  });

  final String id;
  final String reference;
  final int amountKobo;
}
