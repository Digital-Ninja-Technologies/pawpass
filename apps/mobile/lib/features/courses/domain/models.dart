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
  });

  final String id;
  final int position;
  final String title;
  final String body;
  final int minutes;
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

  int get minutes => lessons.fold(0, (sum, l) => sum + l.minutes);
}
