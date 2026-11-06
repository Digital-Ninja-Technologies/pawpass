import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/features/account/domain/account_logic.dart';
import 'package:pawpass/features/account/domain/help_content.dart';
import 'package:pawpass/features/account/domain/models.dart';
import 'package:pawpass/features/health/domain/models.dart' show ShareScope;
import 'package:pawpass/features/partner/domain/models.dart';
import 'package:pawpass/features/partner/domain/partner_logic.dart';

void main() {
  group('tag order validation', () {
    test('address needs a real street address', () {
      expect(validateTagAddress(''), isNotNull);
      expect(validateTagAddress('Ab'), isNotNull);
      expect(validateTagAddress('14 Admiralty Way'), isNull);
      expect(validateTagAddress('x' * 201), isNotNull);
    });
    test('area needs a name', () {
      expect(validateTagArea(' '), isNotNull);
      expect(validateTagArea('Lekki'), isNull);
    });
    test('prices add up', () {
      const p = TagPrices(priceKobo: 350000, deliveryKobo: 100000);
      expect(p.totalKobo, 450000);
    });
  });

  group('shares', () {
    final now = DateTime.utc(2026, 11, 5, 8);
    test('end labels are plain words', () {
      expect(shareEndsLabel(now.add(const Duration(minutes: 30)), now), 'ends in 30 minutes');
      expect(shareEndsLabel(now.add(const Duration(hours: 2)), now), 'ends in 2 hours');
      expect(shareEndsLabel(now.add(const Duration(hours: 30)), now), 'ends tomorrow');
      expect(shareEndsLabel(now.add(const Duration(days: 3)), now), 'ends in 3 days');
      expect(shareEndsLabel(now.subtract(const Duration(minutes: 1)), now), 'ending now');
    });
    test('summary says whether a vet can add records', () {
      final ro = ActiveShare(
        id: 's',
        petId: 'p',
        petName: 'Bingo',
        scopes: {ShareScope.health},
        expiresAt: now,
      );
      expect(shareScopeSummary(ro), contains('read only'));
      final rw = ActiveShare(
        id: 's',
        petId: 'p',
        petName: 'Bingo',
        scopes: {ShareScope.health, ShareScope.write},
        expiresAt: now,
      );
      expect(shareScopeSummary(rw), contains('can add records'));
    });
  });

  group('help content', () {
    test('ids are unique and related articles exist', () {
      final ids = helpDocs.map((d) => d.id).toSet();
      expect(ids.length, helpDocs.length);
      for (final d in helpDocs) {
        for (final r in d.related) {
          expect(ids, contains(r), reason: '${d.id} -> $r');
        }
      }
    });
    test('every topic has an article and copy follows the rules', () {
      for (final t in HelpTopic.values) {
        expect(helpForTopic(t), isNotEmpty, reason: t.label);
      }
      final text = helpDocs.map((d) => d.searchText).join(' ');
      expect(text, isNot(contains('—')));
      expect(text, isNot(contains(r'$')));
    });
    test('search finds by words, title matches first, empty matches nothing', () {
      expect(searchHelp(''), isEmpty);
      expect(searchHelp('zzzz'), isEmpty);
      final r = searchHelp('escrow');
      expect(r, isNotEmpty);
      expect(r.first.id, 'escrow');
    });
  });

  group('calendar logic (Lagos time)', () {
    // Thursday 5 Nov 2026, 09:00 in Lagos.
    final thu = DateTime.utc(2026, 11, 5, 8);
    test('the week starts on Monday 00:00 Lagos', () {
      final w = lagosWeekStart(thu);
      expect(w, DateTime.utc(2026, 11, 1, 23)); // Mon 2 Nov 00:00 Lagos
      expect(weekRangeLabel(w), '2 to 8 Nov 2026');
      expect(dayHeading(lagosDayStart(thu)), 'Thursday 5 Nov');
      expect(weekDays(w), hasLength(7));
    });
    test('a late evening visit belongs to the Lagos day, not the UTC day', () {
      final day = lagosDayStart(thu);
      final late = DateTime.utc(2026, 11, 5, 23, 30); // 00:30 Fri in Lagos
      expect(sameLagosDay(late, day), isFalse);
    });
    test('a week across two months is labelled with both', () {
      expect(
        weekRangeLabel(lagosWeekStart(DateTime.utc(2026, 11, 30, 10))),
        '30 Nov to 6 Dec 2026',
      );
    });
    test('entries for a day are ordered and mixed', () {
      final day = lagosDayStart(thu);
      final cal = PartnerCalendar(
        visits: [
          VisitItem(
            bookingId: 'b',
            startsAt: DateTime.utc(2026, 11, 5, 15, 30),
            service: 'Rabies vaccine',
            petName: 'Bingo',
            petId: 'p',
            ownerName: 'Tolu',
            status: 'confirmed',
            passportShared: true,
          ),
        ],
        open: [
          OpenSlot(
            slotId: 's2',
            startsAt: DateTime.utc(2026, 11, 5, 17, 30),
            endsAt: DateTime.utc(2026, 11, 5, 18, 30),
          ),
          OpenSlot(
            slotId: 's1',
            startsAt: DateTime.utc(2026, 11, 5, 16, 30),
            endsAt: DateTime.utc(2026, 11, 5, 17, 30),
          ),
          OpenSlot(
            slotId: 'other',
            startsAt: DateTime.utc(2026, 11, 6, 10),
            endsAt: DateTime.utc(2026, 11, 6, 11),
          ),
        ],
      );
      final list = entriesForDay(cal, day);
      expect(list.map((e) => e.visit?.bookingId ?? e.slot!.slotId), ['b', 's1', 's2']);
      expect(visitsOn(cal, day), 1);
    });
  });

  group('application filters', () {
    ShelterApplication app(String id, String who, String pet, ApplicationState s) =>
        ShelterApplication(
          id: id,
          listingId: 'l$id',
          petName: pet,
          applicantName: who,
          state: s,
          createdAt: DateTime.utc(2026, 11, 5),
        );
    final all = [
      app('1', 'Tolu', 'Ada', ApplicationState.submitted),
      app('2', 'Seun', 'Kofi', ApplicationState.homeVisit),
      app('3', 'Kemi', 'Biscuit', ApplicationState.approved),
    ];
    test('tabs and counts', () {
      expect(applicationCount(all, ApplicationFilter.all), 3);
      expect(applicationCount(all, ApplicationFilter.fresh), 1);
      expect(filterApplications(all, ApplicationFilter.homeVisit).single.id, '2');
    });
    test('search matches applicant or pet', () {
      expect(filterApplications(all, ApplicationFilter.all, query: 'kofi').single.id, '2');
      expect(filterApplications(all, ApplicationFilter.all, query: 'KEMI').single.id, '3');
      expect(filterApplications(all, ApplicationFilter.fresh, query: 'kemi'), isEmpty);
    });
  });
}
