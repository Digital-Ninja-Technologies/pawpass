import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../onboarding/domain/models.dart';
import '../domain/models.dart';
import 'courses_repository.dart';

AppFailure _failure(Object e, String fallback) {
  if (e is AppFailure) {
    return e;
  }
  if (e is SocketException || e is HttpException) {
    return const AppFailure(
      'No connection. Check your internet and try again.',
    );
  }
  if (e is PostgrestException && (e.code == 'P0002' || e.code == '42501')) {
    return const AppFailure('That lesson is not available any more.');
  }
  return AppFailure(fallback);
}

class SupabaseCoursesRepository implements CoursesRepository {
  SupabaseCoursesRepository(this._client);
  final SupabaseClient _client;

  static const _bucket = 'course-covers';

  @override
  Future<List<Course>> courses() async {
    try {
      final rows = await _client
          .from('courses')
          .select(
            'id, slug, title, summary, audience, level, accent, art, cover_path, sort_order, '
            'course_lessons(id, position, title, body, minutes)',
          )
          .eq('status', 'published')
          .order('sort_order')
          .order('created_at');
      return [
        for (final r in rows as List)
          _course(Map<String, dynamic>.from(r as Map)),
      ];
    } catch (e) {
      throw _failure(e, 'We could not load the courses. Please try again.');
    }
  }

  Course _course(Map<String, dynamic> r) {
    final lessons = [
      for (final l in (r['course_lessons'] as List? ?? const []))
        _lesson(Map<String, dynamic>.from(l as Map)),
    ]..sort((a, b) => a.position.compareTo(b.position));
    final cover = r['cover_path'] as String?;
    return Course(
      id: r['id'] as String,
      slug: r['slug'] as String,
      title: r['title'] as String,
      summary: r['summary'] as String,
      audience: CourseAudience.from(r['audience'] as String?),
      level: CourseLevel.from(r['level'] as String?),
      accent: r['accent'] as String? ?? 'sunny',
      art: r['art'] as String? ?? 'paw',
      coverUrl: cover == null || cover.isEmpty
          ? null
          : _client.storage.from(_bucket).getPublicUrl(cover),
      sortOrder: (r['sort_order'] as num?)?.toInt() ?? 100,
      lessons: lessons,
    );
  }

  Lesson _lesson(Map<String, dynamic> l) => Lesson(
    id: l['id'] as String,
    position: (l['position'] as num).toInt(),
    title: l['title'] as String,
    body: l['body'] as String,
    minutes: (l['minutes'] as num?)?.toInt() ?? 2,
  );

  @override
  Future<Set<String>> doneLessonIds() async {
    try {
      final rows = await _client.from('course_progress').select('lesson_id');
      return {for (final r in rows as List) (r as Map)['lesson_id'] as String};
    } catch (e) {
      throw _failure(e, 'We could not load your progress. Please try again.');
    }
  }

  @override
  Future<void> setLessonDone(String lessonId, bool done) async {
    try {
      await _client.rpc(
        'set_lesson_done',
        params: {'p_lesson': lessonId, 'p_done': done},
      );
    } catch (e) {
      throw _failure(e, 'We could not save that. Please try again.');
    }
  }
}
