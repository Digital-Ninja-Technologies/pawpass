import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/features/community/domain/community_logic.dart';

final _now = DateTime.utc(2026, 11, 5, 8);

void main() {
  test('short times on post cards', () {
    expect(timeAgoShort(_now, _now), 'just now');
    expect(timeAgoShort(_now.subtract(const Duration(minutes: 5)), _now), '5m');
    expect(
      timeAgoShort(_now.subtract(const Duration(hours: 1, minutes: 30)), _now),
      '1h',
    );
    expect(timeAgoShort(_now.subtract(const Duration(hours: 23)), _now), '23h');
    expect(timeAgoShort(_now.subtract(const Duration(days: 2)), _now), '2d');
    expect(timeAgoShort(DateTime.utc(2026, 10, 20, 9), _now), 'Tue 20 Oct');
  });

  test('longer times on lost alerts', () {
    expect(
      timeAgoLong(_now.subtract(const Duration(minutes: 40)), _now),
      '40 min ago',
    );
    expect(
      timeAgoLong(_now.subtract(const Duration(hours: 1)), _now),
      '1 hr ago',
    );
    expect(
      timeAgoLong(_now.subtract(const Duration(hours: 2)), _now),
      '2 hrs ago',
    );
    expect(
      timeAgoLong(_now.subtract(const Duration(hours: 30)), _now),
      'yesterday',
    );
    expect(
      timeAgoLong(_now.subtract(const Duration(days: 4)), _now),
      '4 days ago',
    );
    expect(
      lostHeadline(_now.subtract(const Duration(hours: 2)), _now),
      'LOST · 2 HRS AGO',
    );
  });

  test('ages', () {
    expect(ageLabel(null), '');
    expect(ageLabel(0), 'newborn');
    expect(ageLabel(1), '1 month');
    expect(ageLabel(8), '8 months');
    expect(ageLabel(24), '2 yrs');
    expect(ageLabel(36), '3 yrs');
  });

  test('counts', () {
    expect(countLabel(86), '86');
    expect(countLabel(248), '248');
    expect(countLabel(1000), '1k');
    expect(countLabel(1200), '1.2k');
    expect(countLabel(15400), '15k');
  });

  test('what kind of pet', () {
    expect(petKind('Persian', 'cat'), 'Persian cat');
    expect(petKind('Domestic shorthair cat', 'cat'), 'Domestic shorthair cat');
    expect(petKind(null, 'dog'), 'dog');
    expect(petKind('  ', 'dog'), 'dog');
    expect(petKind('Boerboel', null), 'Boerboel pet');
  });

  test('a shared place opens in maps', () {
    final u = mapsUri(6.4474, 3.4723);
    expect(u.host, 'www.google.com');
    expect(u.queryParameters['query'], '6.4474,3.4723');
  });
}
