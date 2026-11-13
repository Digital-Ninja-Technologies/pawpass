import 'models.dart';

/// A piece of a lesson, ready to draw.
sealed class LessonBlock {
  const LessonBlock();
}

class ParagraphBlock extends LessonBlock {
  const ParagraphBlock(this.text);
  final String text;
}

class BulletsBlock extends LessonBlock {
  const BulletsBlock(this.items);
  final List<String> items;
}

class TipBlock extends LessonBlock {
  const TipBlock(this.text);
  final String text;
}

const _tipPrefix = 'Tip:';

/// Turns a lesson's plain text into blocks: paragraphs (blank line between), bullets (lines starting "- ") and tips
/// (a paragraph starting "Tip:"). Anything else is a paragraph, so odd text from the console still reads fine.
List<LessonBlock> parseLessonBody(String body) {
  final blocks = <LessonBlock>[];
  final paragraph = <String>[];
  final bullets = <String>[];

  void flushParagraph() {
    if (paragraph.isEmpty) {
      return;
    }
    final text = paragraph.join(' ').trim();
    paragraph.clear();
    if (text.isEmpty) {
      return;
    }
    if (text.startsWith(_tipPrefix)) {
      final tip = text.substring(_tipPrefix.length).trim();
      blocks.add(tip.isEmpty ? ParagraphBlock(text) : TipBlock(tip));
    } else {
      blocks.add(ParagraphBlock(text));
    }
  }

  void flushBullets() {
    if (bullets.isNotEmpty) {
      blocks.add(BulletsBlock(List.of(bullets)));
      bullets.clear();
    }
  }

  for (final raw in body.replaceAll('\r\n', '\n').split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) {
      flushParagraph();
      flushBullets();
    } else if (line.startsWith('- ')) {
      flushParagraph();
      final item = line.substring(2).trim();
      if (item.isNotEmpty) {
        bullets.add(item);
      }
    } else {
      flushBullets();
      paragraph.add(line);
    }
  }
  flushParagraph();
  flushBullets();
  return blocks;
}

/// Which courses to show.
enum CourseFilter {
  all('All'),
  puppies('Puppies'),
  dogs('Dogs');

  const CourseFilter(this.label);
  final String label;
}

/// A course "for puppies" also suits a course for both, and the same for dogs.
List<Course> filterCourses(List<Course> courses, CourseFilter filter) {
  return [
    for (final c in courses)
      if (switch (filter) {
        CourseFilter.all => true,
        CourseFilter.puppies => c.audience != CourseAudience.dog,
        CourseFilter.dogs => c.audience != CourseAudience.puppy,
      })
        c,
  ];
}

/// How far through a course someone is. Lessons that were removed from the course never count.
({int done, int total}) courseProgress(
  Course course,
  Set<String> doneLessonIds,
) {
  final done = course.lessons.where((l) => doneLessonIds.contains(l.id)).length;
  return (done: done, total: course.lessons.length);
}

bool isCourseComplete(Course course, Set<String> doneLessonIds) {
  final p = courseProgress(course, doneLessonIds);
  return p.total > 0 && p.done == p.total;
}

bool isCourseStarted(Course course, Set<String> doneLessonIds) =>
    courseProgress(course, doneLessonIds).done > 0;

/// The first lesson not done yet, or null when the course is finished (or empty).
Lesson? nextLesson(Course course, Set<String> doneLessonIds) {
  for (final l in course.lessons) {
    if (!doneLessonIds.contains(l.id)) {
      return l;
    }
  }
  return null;
}

/// The lesson after [lesson] in the course, or null if it is the last.
Lesson? lessonAfter(Course course, Lesson lesson) {
  final i = course.lessons.indexWhere((l) => l.id == lesson.id);
  if (i < 0 || i + 1 >= course.lessons.length) {
    return null;
  }
  return course.lessons[i + 1];
}

/// "1 min", "12 mins". Never "0 mins".
String minutesLabel(int minutes) {
  final m = minutes < 1 ? 1 : minutes;
  return m == 1 ? '1 min' : '$m mins';
}

String lessonCountLabel(int count) =>
    count == 1 ? '1 lesson' : '$count lessons';

/// The course to offer under "Keep going": the one started most recently is not tracked, so this is the first course in
/// the list that is started but not finished.
Course? courseInProgress(List<Course> courses, Set<String> doneLessonIds) {
  for (final c in courses) {
    if (isCourseStarted(c, doneLessonIds) &&
        !isCourseComplete(c, doneLessonIds)) {
      return c;
    }
  }
  return null;
}
