import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/core/analytics.dart';
import 'package:pawpass/features/adopt/state/adopt_controller.dart';
import 'package:pawpass/features/booking/state/booking_controller.dart';
import 'package:pawpass/features/health/state/health_controller.dart';
import 'package:pawpass/features/onboarding/data/in_memory.dart';
import 'package:pawpass/features/onboarding/data/repositories.dart';
import 'package:pawpass/features/onboarding/domain/models.dart';
import 'package:pawpass/features/onboarding/state/session_controller.dart';
import 'package:pawpass/features/health/domain/models.dart';
import 'package:pawpass/features/partner/domain/models.dart';
import 'package:pawpass/features/partner/state/partner_controller.dart';

final _today = DateTime.utc(2026, 11, 5, 8);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late RecordingAnalytics analytics;
  late AppServices services;

  setUp(() async {
    analytics = RecordingAnalytics();
    services = inMemoryServices(
      now: () => _today,
      signedInAs: 'tolu@example.com',
      analytics: analytics,
    );
    final profiles = services.profiles as InMemoryProfileRepository;
    await profiles.save(firstName: 'Tolu');
    profiles.markOnboarded(_today);
    await services.pets.createPassport(
      pet: const PetInput(
        name: 'Bingo',
        species: Species.dog,
        sex: PetSex.male,
      ),
      records: const [],
      channels: {ReminderChannel.push},
    );
  });

  test('every event has the name the database accepts', () {
    expect(
      [for (final e in AppEvent.values) e.value],
      [
        'app_open',
        'booking_started',
        'checkout_started',
        'share_started',
        'partner_started',
        'help_opened',
      ],
    );
  });

  test('signing in counts as opening the app, once', () async {
    final session = SessionController(services);
    await _settle();
    await session.refreshProfile();
    expect(analytics.events.where((e) => e == AppEvent.appOpen), hasLength(1));
  });

  test('not signed in: nothing is reported', () async {
    final out = RecordingAnalytics();
    final s = inMemoryServices(now: () => _today, analytics: out);
    SessionController(s);
    await _settle();
    expect(out.events, isEmpty);
  });

  test(
    'starting a share, a checkout and a partner application are counted',
    () async {
      final session = SessionController(services);
      await _settle();
      final health = HealthController(services, session);
      await _settle();
      await health.load();
      await health.createShare({ShareScope.health});
      expect(analytics.events, contains(AppEvent.shareStarted));

      final adopt = AdoptController(services, session);
      await adopt.payDeposit('l-duke');
      expect(analytics.events, contains(AppEvent.checkoutStarted));

      final partner = PartnerController(services, session);
      await partner.saveBusiness(
        type: PartnerType.vet,
        name: 'Paws',
        area: 'Lekki',
      );
      expect(analytics.events, contains(AppEvent.partnerStarted));
    },
  );

  test('no events carry a name, a place or a message', () {
    // The interface takes an event, and nothing else: there is nowhere to put personal details.
    final a = RecordingAnalytics()..track(AppEvent.helpOpened);
    expect(a.events, [AppEvent.helpOpened]);
    expect(const NoAnalytics().track, isNotNull);
  });

  test('a booking is counted when payment starts', () async {
    final c = BookingController(services, SessionController(services));
    await c.openProvider('p1');
    c.chooseService('s2');
    c.chooseSlot(
      c.slots.firstWhere(
        (s) =>
            s.isFree &&
            s.startsAt.isAfter(_today.add(const Duration(hours: 5))),
      ),
    );
    c.choosePet('pet1');
    expect(analytics.events, isNot(contains(AppEvent.bookingStarted)));
    await c.pay();
    expect(analytics.events, contains(AppEvent.bookingStarted));
  });
}
