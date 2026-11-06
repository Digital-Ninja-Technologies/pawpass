import 'models.dart';

String? validateTagAddress(String value) {
  final v = value.trim();
  if (v.isEmpty) {
    return 'Enter the street address.';
  }
  if (v.length < 5) {
    return 'Add a bit more, such as the house number and street.';
  }
  if (v.length > 200) {
    return 'That is too long. Keep it under 200 characters.';
  }
  return null;
}

String? validateTagArea(String value) {
  final v = value.trim();
  if (v.isEmpty) {
    return 'Enter the area.';
  }
  if (v.length < 2) {
    return 'Enter the area, for example Lekki.';
  }
  if (v.length > 80) {
    return 'That is too long. Keep it under 80 characters.';
  }
  return null;
}

/// How long a share has left, in plain words: "ends in 2 hours", "ends tomorrow", "ends in 3 days".
String shareEndsLabel(DateTime expiresAt, DateTime now) {
  final left = expiresAt.difference(now);
  if (left.isNegative || left.inMinutes < 1) {
    return 'ending now';
  }
  if (left.inMinutes < 60) {
    final m = left.inMinutes;
    return 'ends in $m ${m == 1 ? 'minute' : 'minutes'}';
  }
  if (left.inHours < 24) {
    final h = left.inHours;
    return 'ends in $h ${h == 1 ? 'hour' : 'hours'}';
  }
  final days = left.inHours ~/ 24;
  if (days == 1) {
    return 'ends tomorrow';
  }
  return 'ends in $days days';
}

/// "Records, read only" or "Records, can add" for what a share allows (never colour alone).
String shareScopeSummary(ActiveShare s) {
  final names = <String>[
    if (s.scopes.any((x) => x.value == 'health')) 'health records',
    if (s.scopes.any((x) => x.value == 'origin')) 'origin',
  ];
  final what = names.isEmpty ? 'passport' : names.join(' and ');
  final canWrite = s.scopes.any((x) => x.value == 'write');
  return '${s.petName}\'s $what, ${canWrite ? 'vet can add records' : 'read only'}';
}
