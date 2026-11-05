import '../../../core/dates.dart';

/// A birth date from "about 2 years and 3 months old". Null when there is nothing to work with
/// (zero age, negative numbers or an unreasonable age).
DateTime? approximateBirthDate({
  required int years,
  required int months,
  required DateTime today,
}) {
  if (years < 0 || months < 0 || months > 11 || years > 40) return null;
  if (years == 0 && months == 0) return null;
  return addMonths(dateOnly(today), -(years * 12 + months));
}

/// "3 wks", "5 mos", "1 yr", "2 yrs" from a birth date. Under 8 weeks counts weeks, under a year counts
/// months, then whole years.
String ageLabel(DateTime birth, DateTime today) {
  final b = dateOnly(birth);
  final t = dateOnly(today);
  if (!b.isBefore(t)) return 'Newborn';
  final days = daysBetween(b, t);
  if (days < 56) {
    final w = (days / 7).ceil().clamp(1, 8);
    return '$w ${w == 1 ? 'wk' : 'wks'}';
  }
  var months = (t.year - b.year) * 12 + (t.month - b.month);
  if (t.day < b.day) months -= 1;
  if (months < 12) return '$months ${months == 1 ? 'mo' : 'mos'}';
  final years = months ~/ 12;
  return '$years ${years == 1 ? 'yr' : 'yrs'}';
}
