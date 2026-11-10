import '../../booking/domain/booking_logic.dart';

/// "1h", "3h", "2d", "just now". Short, for post cards.
String timeAgoShort(DateTime t, DateTime now) {
  final d = now.toUtc().difference(t.toUtc());
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return dayLabel(t);
}

/// "2 hrs ago", "40 min ago", "yesterday". Longer, for lost alerts.
String timeAgoLong(DateTime t, DateTime now) {
  final d = now.toUtc().difference(t.toUtc());
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) {
    return d.inHours == 1 ? '1 hr ago' : '${d.inHours} hrs ago';
  }
  if (d.inDays == 1) return 'yesterday';
  return '${d.inDays} days ago';
}

/// "3 yrs", "8 months", "5 weeks"-free: months under two years, years after.
String ageLabel(int? months) {
  if (months == null) return '';
  if (months < 1) return 'newborn';
  if (months < 24) return months == 1 ? '1 month' : '$months months';
  final years = months ~/ 12;
  return '$years yrs';
}

/// "1.2k", "248", "86".
String countLabel(int n) {
  if (n < 1000) return '$n';
  final k = n / 1000;
  return '${k.toStringAsFixed(k >= 10 || k == k.roundToDouble() ? 0 : 1)}k';
}

/// "Persian cat", "Boerboel dog", "dog" when the breed is unknown.
String petKind(String? breed, String? species) {
  final s = species ?? 'pet';
  final b = (breed ?? '').trim();
  if (b.isEmpty) return s;
  if (b.toLowerCase().contains(s)) return b;
  return '$b $s';
}

/// The line over the alert: "LOST · 2 HRS AGO".
String lostHeadline(DateTime lastSeen, DateTime now) =>
    'LOST · ${timeAgoLong(lastSeen, now).toUpperCase()}';

/// Maps link for a shared place.
Uri mapsUri(double lat, double lng) => Uri.https(
  'www.google.com',
  '/maps/search/',
  {'api': '1', 'query': '$lat,$lng'},
);

/// The text shared with a post: who posted, a short quote, and where to get the app.
String postShareText({
  required String authorName,
  required String body,
  required String url,
  String? petName,
}) {
  final who = petName == null ? authorName : "$authorName's $petName";
  final quote = body.trim().isEmpty
      ? ''
      : ': "${body.trim().length > 140 ? '${body.trim().substring(0, 137)}...' : body.trim()}"';
  return 'See $who on OurPawPass$quote. Get the app: $url';
}

/// The comment count as a short label: "No comments", "1 comment", "12 comments".
String commentsLabel(int n) =>
    n == 0 ? 'No comments' : (n == 1 ? '1 comment' : '${countLabel(n)} comments');
