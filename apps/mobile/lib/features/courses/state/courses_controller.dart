import 'package:flutter/foundation.dart';

import '../../booking/domain/models.dart' show PaymentOutcome;
import '../../onboarding/data/repositories.dart';
import '../../onboarding/domain/models.dart';
import '../../onboarding/state/session_controller.dart';
import '../domain/course_logic.dart';
import '../domain/models.dart';

enum BuyStage { idle, starting, waiting, checking }

/// The courses list, which lessons the person has finished, which paid courses they own, and the filters on the list.
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

  /// Ids of the paid courses the person has bought.
  Set<String> purchased = const {};
  var filter = CourseFilter.all;
  var priceFilter = PriceFilter.all;
  var loading = false;
  var loaded = false;
  String? loadError;

  /// Shown after a failed tick. Cleared by the next successful one.
  String? actionError;

  List<Course> get visible =>
      filterCourses(courses, filter, price: priceFilter);

  /// Whether the person can read all of this course (free, or bought).
  bool owns(Course course) => hasAccess(course, purchased);

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
      purchased = await _services.courses.purchasedCourseIds();
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

  void setPriceFilter(PriceFilter value) {
    if (priceFilter == value) {
      return;
    }
    priceFilter = value;
    _notify();
  }

  // ----------------------------------------------------------------- buying

  var buyStage = BuyStage.idle;

  /// The course a payment is open for (null when none).
  String? buyingCourseId;
  String? buyError;
  String? buyNotice;
  CoursePurchase? _intent;

  bool get buyBusy => buyStage != BuyStage.idle;

  /// Starts a purchase (once) and opens Paystack. The price is read on the server; nothing is charged until Paystack
  /// confirms.
  Future<void> buy(Course course) async {
    if (buyBusy || !course.isPaid || owns(course)) {
      return;
    }
    buyStage = BuyStage.starting;
    buyingCourseId = course.id;
    buyError = null;
    buyNotice = null;
    _notify();
    try {
      final existing = _intent;
      final intent = existing != null && _intentCourse == course.id
          ? existing
          : await _services.courses.startPurchase(course.id);
      _intent = intent;
      _intentCourse = course.id;
      final checkout = await _services.payments.start(intent.reference);
      final opened = await _services.links.open(checkout.url);
      if (opened) {
        buyStage = BuyStage.waiting;
      } else {
        buyError = 'We could not open the payment page. Please try again.';
        buyStage = BuyStage.idle;
      }
    } on AppFailure catch (e) {
      buyError = e.message;
      buyStage = BuyStage.idle;
    } catch (_) {
      buyError = 'We could not start the payment. Please try again.';
      buyStage = BuyStage.idle;
    }
    _notify();
  }

  String? _intentCourse;

  /// Called when the person comes back from Paystack (or taps "I have paid"). Returns true once the course is unlocked.
  Future<bool> checkPurchase() async {
    final intent = _intent;
    if (intent == null ||
        buyStage == BuyStage.checking ||
        buyStage == BuyStage.idle) {
      return false;
    }
    buyStage = BuyStage.checking;
    buyError = null;
    buyNotice = null;
    _notify();
    var unlocked = false;
    try {
      final outcome = await _services.payments.verify(intent.reference);
      switch (outcome) {
        case PaymentOutcome.paid:
          // Reload so the lesson text, which the server only sends to owners, arrives.
          courses = await _services.courses.courses();
          purchased = await _services.courses.purchasedCourseIds();
          buyStage = BuyStage.idle;
          buyingCourseId = null;
          _intent = null;
          unlocked = true;
        case PaymentOutcome.pending:
          buyStage = BuyStage.waiting;
          buyNotice = 'We have not received your payment yet. If you have paid, wait a moment and check again.';
        case PaymentOutcome.failed:
          buyStage = BuyStage.idle;
          _intent = null;
          buyError =
              'The payment did not go through. You have not been charged.';
      }
    } on AppFailure catch (e) {
      buyStage = BuyStage.waiting;
      buyError = e.message;
    } catch (_) {
      buyStage = BuyStage.waiting;
      buyError = 'We could not check the payment. Please try again.';
    }
    _notify();
    return unlocked;
  }

  /// Gives up waiting on a payment that is open on Paystack. The open purchase is kept, so Buy picks it up again.
  void cancelBuying() {
    if (buyStage == BuyStage.waiting) {
      buyStage = BuyStage.idle;
      buyingCourseId = null;
      buyNotice = null;
      buyError = null;
      _notify();
    }
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
    purchased = const {};
    filter = CourseFilter.all;
    priceFilter = PriceFilter.all;
    buyStage = BuyStage.idle;
    buyingCourseId = null;
    buyError = null;
    buyNotice = null;
    _intent = null;
    _intentCourse = null;
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
