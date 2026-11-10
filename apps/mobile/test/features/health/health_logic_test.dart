import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/core/dates.dart';
import 'package:pawpass/features/health/domain/health_logic.dart';
import 'package:pawpass/features/health/domain/models.dart';
import 'package:pawpass/features/onboarding/domain/models.dart';

final today = DateTime(2026, 11, 5);

Reminder rem(
  String label,
  DateTime due, {
  String pet = 'Bingo',
  String? cadence,
  bool done = false,
  String? id,
}) => Reminder(
  id: id ?? '$pet-$label',
  petId: pet,
  petName: pet,
  label: label,
  dueOn: due,
  cadence: cadence,
  done: done,
);

HealthRecord rec(
  String name, {
  RecordType type = RecordType.vaccine,
  DateTime? given,
  DateTime? next,
  String? value,
  bool verified = false,
  String? verifier,
  String? by,
  bool mine = true,
}) => HealthRecord(
  id: name,
  petId: 'p',
  type: type,
  name: name,
  givenOn: given,
  nextDueOn: next,
  value: value,
  verified: verified,
  verifiedByName: verifier,
  givenByName: by,
  addedByMe: mine,
);

void main() {
  group('schedule', () {
    // The sample schedule from design/screens/Schedule.dc.html, with "today" as 5 Nov 2026.
    final all = [
      rem('Rabies booster', DateTime(2026, 11, 12)),
      rem(
        'Flea & tick treatment',
        DateTime(2026, 11, 28),
        pet: 'Mimi',
        cadence: 'monthly',
      ),
      rem('Deworming', DateTime(2027, 1, 20), cadence: 'every 3 months'),
      rem(
        'FVRCP booster',
        DateTime(2027, 2, 3),
        pet: 'Mimi',
        cadence: 'yearly',
      ),
      rem('DHPP booster', DateTime(2027, 3, 12), cadence: 'yearly'),
    ];

    test('groups like the design: this month, then coming up', () {
      final g = groupReminders(all, today);
      expect(g.overdue, isEmpty);
      expect(g.thisMonth.map((r) => r.label), [
        'Rabies booster',
        'Flea & tick treatment',
      ]);
      expect(g.later.map((r) => r.label), [
        'Deworming',
        'FVRCP booster',
        'DHPP booster',
      ]);
    });

    test('overdue comes first, oldest first, and done ones vanish', () {
      final g = groupReminders([
        rem('B', DateTime(2026, 11, 1)),
        rem('A', DateTime(2026, 10, 2)),
        rem('Done', DateTime(2026, 10, 1), done: true),
        rem('Today', DateTime(2026, 11, 5)),
      ], today);
      expect(g.overdue.map((r) => r.label), ['A', 'B']);
      expect(g.thisMonth.map((r) => r.label), ['Today']);
      expect(g.isEmpty, isFalse);
      expect(groupReminders([], today).isEmpty, isTrue);
    });

    test('subtitles match the design', () {
      expect(reminderSubtitle(all[0], today), 'Bingo · in 7 days');
      expect(reminderSubtitle(all[1], today), 'Mimi · monthly');
      expect(reminderSubtitle(all[2], today), 'Bingo · every 3 months');
      expect(reminderSubtitle(all[4], today), 'Bingo · yearly');
    });

    test('when text covers today, tomorrow and overdue', () {
      expect(whenText(rem('x', DateTime(2026, 11, 5)), today), 'today');
      expect(whenText(rem('x', DateTime(2026, 11, 6)), today), 'tomorrow');
      expect(
        whenText(rem('x', DateTime(2026, 11, 4)), today),
        'overdue by 1 day',
      );
      expect(
        whenText(rem('x', DateTime(2026, 11, 2)), today),
        'overdue by 3 days',
      );
      expect(
        reminderSubtitle(
          rem('x', DateTime(2026, 11, 2), cadence: 'yearly'),
          today,
        ),
        'Bingo · overdue by 3 days',
      );
    });

    test('only what is close gets the full card', () {
      expect(isSoon(all[0], today), isTrue);
      expect(isSoon(all[1], today), isFalse);
      expect(isSoon(rem('x', DateTime(2026, 11, 19)), today), isTrue);
      expect(isSoon(rem('x', DateTime(2026, 11, 20)), today), isFalse);
    });
  });

  group('passport', () {
    test('status', () {
      expect(passportStatus([], today).state, PassportState.upToDate);
      expect(passportStatus([], today).label, 'Passport up to date');
      expect(
        passportStatus([rem('x', DateTime(2027, 3, 1))], today).state,
        PassportState.upToDate,
      );
      final soon = passportStatus([rem('x', DateTime(2026, 11, 12))], today);
      expect(soon.state, PassportState.dueSoon);
      expect(soon.next?.label, 'x');
      final late = passportStatus([
        rem('a', DateTime(2026, 11, 1)),
        rem('b', DateTime(2026, 10, 1)),
      ], today);
      expect(late.state, PassportState.overdue);
      expect(late.label, '2 reminders overdue');
      expect(
        passportStatus([rem('a', DateTime(2026, 11, 1))], today).label,
        '1 reminder overdue',
      );
    });

    test(
      'entries: upcoming first, then given latest first; weights stay out',
      () {
        final entries = passportEntries(
          [
            rec(
              'DHPP vaccine',
              given: DateTime(2026, 3, 12),
              verified: true,
              verifier: 'Dr. Amina Bello',
            ),
            rec(
              'Deworming',
              type: RecordType.deworming,
              given: DateTime(2026, 10, 20),
            ),
            rec(
              'Weight',
              type: RecordType.weight,
              given: DateTime(2026, 10, 1),
              value: '41',
            ),
            rec('Undated', type: RecordType.allergy),
          ],
          [
            rem('Rabies booster', DateTime(2026, 11, 12)),
            rem('Old', DateTime(2026, 1, 1), done: true),
          ],
        );
        expect(
          entries.map((e) => e.isUpcoming ? e.reminder!.label : e.record!.name),
          ['Rabies booster', 'Deworming', 'DHPP vaccine', 'Undated'],
        );
      },
    );

    test('where a record came from', () {
      expect(
        rec('x', verified: true, verifier: 'Dr. Amina Bello').sourceLabel,
        'Dr. Amina Bello',
      );
      expect(rec('x', by: 'Paws and Claws').sourceLabel, 'Paws and Claws');
      expect(rec('x').sourceLabel, 'added by you');
      expect(rec('x', mine: false).sourceLabel, 'added by a clinic');
      expect(rec('x', verified: true).sourceLabel, 'added by you');
    });

    test('labels and cadence', () {
      expect(reminderLabel(RecordType.vaccine, 'Rabies'), 'Rabies booster');
      expect(
        reminderLabel(RecordType.vaccine, 'Rabies booster'),
        'Rabies booster',
      );
      expect(reminderLabel(RecordType.vaccine, 'DHPP vaccine'), 'DHPP vaccine');
      expect(reminderLabel(RecordType.deworming, 'Deworming'), 'Deworming');
      expect(
        cadenceLabel(DateTime(2025, 11, 12), DateTime(2026, 11, 12)),
        'yearly',
      );
      expect(
        cadenceLabel(DateTime(2026, 10, 20), DateTime(2027, 1, 20)),
        'every 3 months',
      );
      expect(
        cadenceLabel(DateTime(2026, 10, 1), DateTime(2026, 11, 1)),
        'monthly',
      );
      expect(
        cadenceLabel(DateTime(2024, 1, 1), DateTime(2026, 1, 1)),
        'every 2 years',
      );
      expect(cadenceLabel(DateTime(2026, 1, 1), DateTime(2026, 1, 10)), isNull);
      expect(cadenceLabel(null, DateTime(2026, 1, 10)), isNull);
    });

    test('rows map from the database, including the verifying clinic', () {
      final r = HealthRecord.fromRow({
        'id': '1',
        'pet_id': 'p',
        'type': 'vaccine',
        'name': 'DHPP vaccine',
        'given_on': '2026-03-12',
        'next_due_on': '2027-03-12',
        'value': null,
        'given_by_name': null,
        'verified_at': '2026-03-12T10:00:00+00:00',
        'verifier': {'business_name': 'Paws & Claws Vet Clinic'},
        'added_by_user_id': 'vet-user',
        'attachment_path': null,
      }, me: 'me');
      expect(r.verified, isTrue);
      expect(r.sourceLabel, 'Paws & Claws Vet Clinic');
      expect(r.addedByMe, isFalse);
      expect(r.givenOn, DateTime(2026, 3, 12));

      final rem = Reminder.fromRow({
        'id': 'r1',
        'pet_id': 'p',
        'health_record_id': '1',
        'due_on': '2027-03-12',
        'status': 'scheduled',
        'health_records': {
          'type': 'vaccine',
          'name': 'Rabies',
          'given_on': '2025-11-12',
          'next_due_on': '2026-11-12',
        },
      }, petName: 'Bingo');
      expect(rem.label, 'Rabies booster');
      expect(rem.cadence, 'yearly');
      expect(rem.done, isFalse);
    });
  });

  group('add a record', () {
    test('next due is filled in for things that repeat', () {
      final given = DateTime(2026, 11, 5);
      expect(
        suggestedNextDue(RecordType.vaccine, 'Rabies', given),
        DateTime(2027, 11, 5),
      );
      expect(
        suggestedNextDue(RecordType.deworming, 'Deworming', given),
        DateTime(2027, 2, 5),
      );
      expect(
        suggestedNextDue(RecordType.treatment, 'Tick & flea treatment', given),
        DateTime(2026, 12, 5),
      );
      expect(
        suggestedNextDue(RecordType.treatment, 'Antibiotics', given),
        isNull,
      );
      expect(suggestedNextDue(RecordType.vetVisit, 'Check up', given), isNull);
      expect(suggestedNextDue(RecordType.weight, 'Weight', given), isNull);
      expect(suggestedNextDue(RecordType.allergy, 'Chicken', given), isNull);
      expect(RecordType.vaccine.repeats, isTrue);
      expect(RecordType.weight.repeats, isFalse);
    });

    test('suggestions follow the species', () {
      expect(
        nameSuggestions(RecordType.vaccine, Species.dog),
        contains('DHPP (5-in-1)'),
      );
      expect(
        nameSuggestions(RecordType.vaccine, Species.cat),
        contains('FVRCP (3-in-1)'),
      );
      expect(
        nameSuggestions(RecordType.vaccine, Species.cat),
        isNot(contains('DHPP (5-in-1)')),
      );
      expect(nameSuggestions(RecordType.allergy, Species.dog), isEmpty);
    });

    test('weights are read from what people type', () {
      expect(parseWeightKg('41'), 41);
      expect(parseWeightKg('41.5 kg'), 41.5);
      expect(parseWeightKg('41,5'), 41.5);
      expect(parseWeightKg('about 12kg'), 12);
      expect(parseWeightKg('0'), isNull);
      expect(parseWeightKg('250'), isNull);
      expect(parseWeightKg('heavy'), isNull);
      expect(parseWeightKg(null), isNull);
      expect(kgText(41), '41 kg');
      expect(kgText(41.5), '41.5 kg');
    });

    test('a record is checked before saving', () {
      String? check({
        RecordType type = RecordType.vaccine,
        String name = 'Rabies',
        DateTime? given,
        DateTime? next,
        DateTime? born,
        String? weight,
      }) => recordProblem(
        type: type,
        name: name,
        givenOn: given ?? DateTime(2026, 11, 5),
        nextDueOn: next,
        today: today,
        petBirthDate: born,
        weightText: weight,
      );
      expect(check(), isNull);
      expect(check(name: '  '), contains('Enter a name'));
      expect(check(given: DateTime(2026, 11, 6)), contains('future'));
      expect(
        check(born: DateTime(2026, 11, 6), given: DateTime(2026, 11, 5)),
        contains('before the pet was born'),
      );
      expect(
        check(next: DateTime(2026, 11, 5)),
        contains('after the date given'),
      );
      expect(check(next: DateTime(2027, 11, 5)), isNull);
      expect(check(type: RecordType.weight, weight: 'x'), contains('weight'));
      expect(check(type: RecordType.weight, weight: '12', name: ''), isNull);
      expect(
        recordProblem(
          type: RecordType.vaccine,
          name: 'x',
          givenOn: null,
          nextDueOn: null,
          today: today,
        ),
        'Choose the date.',
      );
    });
  });

  group('weight chart', () {
    test('uses the last six, oldest first, scaled to the tallest', () {
      final records = [
        for (var i = 0; i < 8; i++)
          rec(
            'w$i',
            type: RecordType.weight,
            given: DateTime(2026, 3 + i, 1),
            value: '${30 + i * 2}',
          ),
        rec('Rabies', given: DateTime(2026, 9, 1)),
        rec(
          'Bad',
          type: RecordType.weight,
          given: DateTime(2026, 10, 1),
          value: 'abc',
        ),
      ];
      final s = weightSeries(records);
      expect(s.points.length, 6);
      expect(s.points.first.kg, 34);
      expect(s.latestKg, 44);
      expect(s.heights.last, 1.0);
      expect(s.heights.first, closeTo(34 / 44, 0.001));
      expect(s.description, 'Weight rising from 34 kg to 44 kg over 6 entries');
    });

    test('few or no weights', () {
      expect(weightSeries([]).isEmpty, isTrue);
      expect(weightSeries([]).description, 'No weights yet');
      final one = weightSeries([
        rec(
          'w',
          type: RecordType.weight,
          given: DateTime(2026, 1, 1),
          value: '12',
        ),
      ]);
      expect(one.description, 'Weight 12 kg');
      expect(one.heights, [1.0]);
    });
  });

  group('share with a vet', () {
    test('the token goes after a # so a web server never sees it', () {
      expect(
        shareUrl('https://example.test/s', 'abc'),
        'https://example.test/s#abc',
      );
      expect(
        shareUrl('https://example.test/s/', 'abc'),
        'https://example.test/s#abc',
      );
    });

    test('expiry wording', () {
      final now = DateTime(2026, 11, 5, 9);
      expect(
        expiryText(now.add(const Duration(hours: 24)), now),
        'Link expires in 24 hours',
      );
      expect(
        expiryText(now.add(const Duration(hours: 3, minutes: 10)), now),
        'Link expires in 3 hours',
      );
      expect(
        expiryText(now.add(const Duration(minutes: 40)), now),
        'Link expires in 40 minutes',
      );
      expect(
        expiryText(now.add(const Duration(seconds: 20)), now),
        'Link expires in 1 minute',
      );
      expect(
        expiryText(now.subtract(const Duration(seconds: 1)), now),
        'Link has expired',
      );
    });

    test('the WhatsApp message and link', () {
      final text = whatsAppShareText(
        petName: 'Bingo',
        url: 'https://x.test/s#t',
      );
      expect(text, contains("Bingo's OurPawPass passport"));
      expect(text, endsWith('https://x.test/s#t'));
      final uri = whatsAppUri(text);
      expect(uri.host, 'wa.me');
      expect(uri.queryParameters['text'], text);
    });

    test('scopes map both ways', () {
      expect(ShareScope.fromValue('write'), ShareScope.write);
      expect(ShareScope.fromValue('nope'), isNull);
      final link = ShareLink.fromJson({
        'id': 's',
        'token': 't',
        'expires_at': '2026-11-06T09:00:00+00:00',
        'scopes': ['health', 'origin', 'bogus'],
      });
      expect(link.scopes, {ShareScope.health, ShareScope.origin});
    });
  });

  group('emergency vets', () {
    test('distance', () {
      expect(distanceText(null), isNull);
      expect(distanceText(850), '850 m');
      expect(distanceText(4), '10 m');
      expect(distanceText(999), '990 m');
      expect(distanceText(3400), '3.4 km');
      expect(distanceText(12000), '12.0 km');
    });

    test('closing time', () {
      expect(closingText('20:00'), '8pm');
      expect(closingText('20:30:00'), '8:30pm');
      expect(closingText('12:00'), '12pm');
      expect(closingText('00:00'), 'midnight');
      expect(closingText('07:05'), '7:05am');
    });

    test('open status', () {
      EmergencyVet vet({bool h24 = false, bool open = false, String? closes}) =>
          EmergencyVet(
            id: 'v',
            name: 'V',
            open24h: h24,
            openNow: open,
            homeVisits: false,
            closesAt: closes,
          );
      expect(openStatus(vet(h24: true, open: true)), 'Open 24 hours');
      expect(openStatus(vet(open: true, closes: '20:00:00')), 'Open till 8pm');
      expect(openStatus(vet(open: true)), 'Open now');
      expect(openStatus(vet()), 'Closed now');
    });

    test('call, directions and share location links', () {
      expect(telUri('+234 800 000 0001').toString(), 'tel:+2348000000001');
      final d = directionsUri(6.44, 3.472);
      expect(d.host, 'www.google.com');
      expect(d.queryParameters['destination'], '6.44,3.472');
      expect(locationUri(6.44, 3.472).queryParameters['query'], '6.44,3.472');
    });

    test('rows map from the database', () {
      final v = EmergencyVet.fromRow({
        'id': 'v',
        'business_name': 'Lekki Animal Hospital',
        'area': 'Lekki',
        'phone': '+2340000000002',
        'open_24h': true,
        'open_now': true,
        'home_visits': false,
        'closes_at': null,
        'distance_m': 3400,
        'lat': 6.44,
        'lng': 3.472,
      });
      expect(v.name, 'Lekki Animal Hospital');
      expect(v.distanceMeters, 3400);
      expect(openStatus(v), 'Open 24 hours');
    });
  });

  group('notifications', () {
    final now = DateTime(2026, 11, 5, 10, 0);
    AppNotification n(String id, DateTime at, {bool read = false}) =>
        AppNotification(
          id: id,
          kind: NotificationKind.reminderDue,
          title: id,
          createdAt: at,
          read: read,
        );

    test('grouped into today and earlier, newest first', () {
      final g = groupNotifications([
        n('old', DateTime(2026, 11, 3, 9)),
        n('a', DateTime(2026, 11, 5, 8)),
        n('b', DateTime(2026, 11, 5, 9, 30)),
        n('yesterday', DateTime(2026, 11, 4, 23)),
      ], now);
      expect(g.today.map((x) => x.id), ['b', 'a']);
      expect(g.earlier.map((x) => x.id), ['yesterday', 'old']);
      expect(groupNotifications([], now).isEmpty, isTrue);
    });

    test('relative time', () {
      expect(relativeTime(now, now), 'Just now');
      expect(
        relativeTime(now.subtract(const Duration(minutes: 12)), now),
        '12 min ago',
      );
      expect(
        relativeTime(now.subtract(const Duration(hours: 2)), now),
        '2h ago',
      );
      expect(relativeTime(DateTime(2026, 11, 4, 23), now), 'Yesterday');
      expect(relativeTime(DateTime(2026, 11, 3, 9), now), '2 days ago');
      expect(relativeTime(DateTime(2026, 10, 1, 9), now), '1 Oct 2026');
    });

    test('unread count and marking read', () {
      final list = [n('a', now), n('b', now, read: true), n('c', now)];
      expect(unreadCount(list), 2);
      expect(list.first.asRead().read, isTrue);
      expect(list.first.read, isFalse);
    });

    test('rows map from the database', () {
      final x = AppNotification.fromRow({
        'id': '1',
        'kind': 'record_verified',
        'title': 'Record verified',
        'body': 'Paws & Claws verified it.',
        'link': '/passport',
        'created_at': '2026-11-04T10:00:00+00:00',
        'read_at': null,
      });
      expect(x.kind, NotificationKind.recordVerified);
      expect(x.read, isFalse);
      expect(NotificationKind.fromValue('weird'), NotificationKind.community);
    });
  });

  test('long date and greeting', () {
    expect(formatLongDate(DateTime(2026, 11, 5)), 'Thursday, 5 November');
    expect(greetingFor(DateTime(2026, 11, 5, 8)), 'Good morning');
    expect(greetingFor(DateTime(2026, 11, 5, 13)), 'Good afternoon');
    expect(greetingFor(DateTime(2026, 11, 5, 19)), 'Good evening');
  });
}
