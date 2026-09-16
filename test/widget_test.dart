import 'package:flutter_test/flutter_test.dart';
import 'package:arad_messenger/main.dart';

void main() {
  test('OTP digits normalize correctly', () {
    expect(normalizeOtpDigits('۱۲۳۴۵۶'), '123456');
    expect(normalizeOtpDigits('١٢٣٤٥٦'), '123456');
    expect(normalizeOtpDigits('123456'), '123456');
  });
}
