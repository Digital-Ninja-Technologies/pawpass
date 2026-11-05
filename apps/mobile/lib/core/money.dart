/// Formats whole naira as ₦15,000.
String formatNaira(num amount) {
  final digits = amount.round().abs().toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${amount < 0 ? '-' : ''}₦$grouped';
}
