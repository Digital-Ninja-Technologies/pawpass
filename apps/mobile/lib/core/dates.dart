const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "14 Aug 2024"
String formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// "NOV", for the schedule date badge.
String monthAbbrUpper(DateTime d) => _months[d.month - 1].toUpperCase();

/// "2024-08-14", what Postgres `date` columns take.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The calendar day, with no time of day.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Adds whole months, clamping the day (31 Jan + 1 month is 28 or 29 Feb).
DateTime addMonths(DateTime d, int months) {
  final total = d.year * 12 + (d.month - 1) + months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, d.day > lastDay ? lastDay : d.day);
}

/// Whole days from [from] to [to] by calendar day (positive when [to] is later).
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "Thursday, 5 November"
String formatLongDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_monthNames[d.month - 1]}';

/// "Good morning", "Good afternoon" or "Good evening" for the hour of day.
String greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 17) return 'Good afternoon';
  return 'Good evening';
}
