final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

String normaliseEmail(String input) => input.trim().toLowerCase();

bool isValidEmail(String input) => _email.hasMatch(normaliseEmail(input));

/// A phone number in international form (+2348031234567), or null if it does not look like one.
/// Accepts Nigerian numbers written locally (0803 123 4567), with the country code (234 803 ...)
/// or with a plus, and other countries only when they start with a plus.
String? normalisePhone(String input) {
  final raw = input.trim();
  if (raw.isEmpty) return null;
  final hasPlus = raw.startsWith('+');
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;

  if (hasPlus) {
    return digits.length >= 8 && digits.length <= 15 ? '+$digits' : null;
  }
  if (digits.startsWith('234') && digits.length == 13) return '+$digits';
  if (digits.startsWith('0') && digits.length == 11) {
    return '+234${digits.substring(1)}';
  }
  if (digits.length == 10 && RegExp(r'^[789]').hasMatch(digits)) {
    return '+234$digits';
  }
  return null;
}

/// Six digits, nothing else.
bool isValidOtp(String code) => RegExp(r'^\d{6}$').hasMatch(code);
