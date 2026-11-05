import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/core/dates.dart';
import 'package:pawpass/features/onboarding/domain/models.dart';
import 'package:pawpass/features/onboarding/domain/pet_age.dart';
import 'package:pawpass/features/onboarding/domain/reminder_schedule.dart';
import 'package:pawpass/features/onboarding/domain/validators.dart';

void main() {
  group('dates', () {
    test('formats like the designs', () {
      expect(formatDate(DateTime(2024, 8, 14)), '14 Aug 2024');
      expect(monthAbbrUpper(DateTime(2026, 11, 12)), 'NOV');
      expect(isoDate(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('adds months and clamps the day', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2024, 1, 31), 1), DateTime(2024, 2, 29));
      expect(addMonths(DateTime(2025, 11, 12), 12), DateTime(2026, 11, 12));
      expect(addMonths(DateTime(2026, 10, 20), 3), DateTime(2027, 1, 20));
      expect(addMonths(DateTime(2026, 3, 12), -27), DateTime(2023, 12, 12));
    });

    test('counts calendar days, ignoring the time of day', () {
      expect(
        daysBetween(
          DateTime(2026, 11, 5, 23, 59),
          DateTime(2026, 11, 12, 0, 1),
        ),
        7,
      );
      expect(daysBetween(DateTime(2026, 11, 12), DateTime(2026, 11, 5)), -7);
    });
  });

  group('suggested reminder schedule', () {
    // The sample numbers from design/screens/Reminders.dc.html, with "today" as 5 Nov 2026.
    final today = DateTime(2026, 11, 5);
    final given = {
      VaccineKind.core: DateTime(2026, 3, 12),
      VaccineKind.rabies: DateTime(2025, 11, 12),
      VaccineKind.deworming: DateTime(2026, 10, 20),
    };

    test('matches the design: rabies first, then deworming, then DHPP', () {
      final items = buildSchedule(species: Species.dog, given: given);
      expect(items.map((i) => i.label), [
        'Rabies booster',
        'Deworming',
        'DHPP booster',
      ]);
      expect(items.map((i) => i.dueOn), [
        DateTime(2026, 11, 12),
        DateTime(2027, 1, 20),
        DateTime(2027, 3, 12),
      ]);
      expect(items.map((i) => i.subtitle(today)), [
        'Yearly · due in 7 days',
        'Every 3 months',
        'Yearly',
      ]);
      expect(items.map((i) => i.isSoon(today)), [true, false, false]);
    });

    test('names the core vaccine for the species', () {
      expect(
        buildSchedule(
          species: Species.cat,
          given: {VaccineKind.core: DateTime(2026, 6, 1)},
        ).single.label,
        'FVRCP booster',
      );
      expect(VaccineKind.core.nameFor(Species.dog), 'DHPP (5-in-1)');
      expect(VaccineKind.core.nameFor(Species.other), 'Core vaccine');
    });

    test('says when something is due, tomorrow, today or overdue', () {
      ScheduleItem at(DateTime due) => ScheduleItem(
        kind: VaccineKind.rabies,
        label: 'Rabies booster',
        cadence: 'Yearly',
        givenOn: DateTime(2025, 1, 1),
        dueOn: due,
      );
      expect(at(DateTime(2026, 11, 6)).dueText(today), 'due tomorrow');
      expect(at(DateTime(2026, 11, 5)).dueText(today), 'due today');
      expect(at(DateTime(2026, 11, 4)).dueText(today), 'overdue by 1 day');
      expect(at(DateTime(2026, 11, 2)).dueText(today), 'overdue by 3 days');
      expect(at(DateTime(2026, 12, 5)).dueText(today), 'due in 30 days');
      expect(at(DateTime(2026, 12, 6)).dueText(today), isNull);
      expect(at(DateTime(2026, 11, 2)).isSoon(today), isTrue);
    });

    test('an empty history gives an empty schedule', () {
      expect(buildSchedule(species: Species.dog, given: {}), isEmpty);
    });

    test('record drafts carry the database fields, soonest due first', () {
      final json = recordDrafts(
        species: Species.dog,
        given: given,
      ).map((r) => r.toJson()).toList();
      expect(json.first, {
        'type': 'vaccine',
        'name': 'Rabies',
        'given_on': '2025-11-12',
        'next_due_on': '2026-11-12',
      });
      expect(json[1]['type'], 'deworming');
      expect(
        recordDrafts(
          species: Species.dog,
          given: {VaccineKind.tickFlea: DateTime(2026, 10, 1)},
        ).single.toJson()['type'],
        'treatment',
      );
    });
  });

  group('pet age', () {
    final today = DateTime(2026, 11, 5);

    test('builds a birth date from an approximate age', () {
      expect(
        approximateBirthDate(years: 2, months: 3, today: today),
        DateTime(2024, 8, 5),
      );
      expect(
        approximateBirthDate(years: 0, months: 6, today: today),
        DateTime(2026, 5, 5),
      );
      expect(approximateBirthDate(years: 0, months: 0, today: today), isNull);
      expect(approximateBirthDate(years: 1, months: 12, today: today), isNull);
      expect(approximateBirthDate(years: -1, months: 0, today: today), isNull);
      expect(approximateBirthDate(years: 41, months: 0, today: today), isNull);
    });

    test('labels ages the way the passport shows them', () {
      expect(ageLabel(DateTime(2024, 8, 14), today), '2 yrs');
      expect(ageLabel(DateTime(2025, 8, 14), today), '1 yr');
      expect(ageLabel(DateTime(2026, 5, 20), today), '5 mos');
      expect(ageLabel(DateTime(2026, 10, 5), today), '5 wks');
      expect(ageLabel(DateTime(2026, 9, 10), today), '1 mo');
      expect(ageLabel(DateTime(2026, 10, 29), today), '1 wk');
      expect(ageLabel(DateTime(2026, 9, 17), today), '7 wks');
      expect(ageLabel(DateTime(2026, 11, 5), today), 'Newborn');
    });
  });

  group('validators', () {
    test('emails', () {
      expect(isValidEmail('tolu.adeyemi@example.com'), isTrue);
      expect(isValidEmail('  Tolu@Example.com '), isTrue);
      expect(isValidEmail('tolu@example'), isFalse);
      expect(isValidEmail('tolu example@x.com'), isFalse);
      expect(isValidEmail(''), isFalse);
      expect(normaliseEmail('  Tolu@Example.COM '), 'tolu@example.com');
    });

    test('phone numbers become international form', () {
      expect(normalisePhone('0803 123 4567'), '+2348031234567');
      expect(normalisePhone('+234 803 123 4567'), '+2348031234567');
      expect(normalisePhone('2348031234567'), '+2348031234567');
      expect(normalisePhone('803-123-4567'), '+2348031234567');
      expect(normalisePhone('+44 7700 900123'), '+447700900123');
      expect(normalisePhone(''), isNull);
      expect(normalisePhone('12345'), isNull);
      expect(normalisePhone('abc'), isNull);
      expect(normalisePhone('0803 123'), isNull);
    });

    test('codes are exactly six digits', () {
      expect(isValidOtp('482176'), isTrue);
      expect(isValidOtp('48217'), isFalse);
      expect(isValidOtp('4821760'), isFalse);
      expect(isValidOtp('48217a'), isFalse);
    });
  });

  test('profile rows map to the model, with safe defaults', () {
    final p = Profile.fromRow({
      'first_name': 'Tolu',
      'last_name': 'Adeyemi',
      'area': 'Lekki',
      'phone': null,
      'avatar_path': null,
      'account_types': ['owner', 'breeder', 'nonsense'],
      'onboarded_at': '2026-11-05T10:00:00+00:00',
    });
    expect(p.accountTypes, {AccountType.owner, AccountType.breeder});
    expect(p.onboarded, isTrue);
    expect(const Profile().onboarded, isFalse);
    expect(Profile.fromRow({'account_types': []}).accountTypes, {
      AccountType.owner,
    });
  });
}
