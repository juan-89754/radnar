import 'package:flutter_test/flutter_test.dart';
import 'package:radnar/models/cliente.dart';

void main() {
  group('Cliente Phone Validation Tests', () {
    test('Valid E.164 phone numbers should pass through unchanged', () {
      const phone = '+573206672858';
      expect(Cliente.cleanAndValidatePhone(phone), equals(phone));
    });

    test('10-digit Colombian numbers starting with 3 should automatically get +57 prefix', () {
      const phone = '3206672858';
      expect(Cliente.cleanAndValidatePhone(phone), equals('+573206672858'));
    });

    test('Numbers with spaces or dashes should be cleaned correctly', () {
      const phone = ' +57 320-667-2858 ';
      expect(Cliente.cleanAndValidatePhone(phone), equals('+573206672858'));
    });

    test('Invalid numbers should throw FormatException', () {
      expect(() => Cliente.cleanAndValidatePhone('12345'), throwsFormatException);
      expect(() => Cliente.cleanAndValidatePhone('abc3001234'), throwsFormatException);
    });
  });
}
