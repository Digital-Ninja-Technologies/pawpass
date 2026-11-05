import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/core/money.dart';

void main() {
  test('formats with thousands separators', () {
    expect(formatNaira(15000), '₦15,000');
  });
  test('rounds to whole naira', () {
    expect(formatNaira(999.6), '₦1,000');
  });
  test('handles small amounts', () {
    expect(formatNaira(0), '₦0');
  });
}
