import 'package:flutter_test/flutter_test.dart';
import 'package:visitor_management/core/utils/validators.dart';

void main() {
  group('required text', () {
    test('rejects empty and whitespace', () {
      expect(Validators.requiredText(null, 'Name'), 'Name is required');
      expect(Validators.requiredText('   ', 'Name'), 'Name is required');
    });

    test('accepts real text', () {
      expect(Validators.requiredText('Asha', 'Name'), isNull);
    });
  });

  group('mobile', () {
    test('requires exactly 10 digits', () {
      expect(Validators.mobile(''), isNotNull);
      expect(Validators.mobile('98765'), 'Enter exactly 10 digits');
      expect(Validators.mobile('98765432101'), 'Enter exactly 10 digits');
      expect(Validators.mobile('98765abcde'), 'Enter exactly 10 digits');
      expect(Validators.mobile('9876543210'), isNull);
    });
  });

  group('optional email', () {
    test('is fine when empty', () {
      expect(Validators.optionalEmail(null), isNull);
      expect(Validators.optionalEmail('  '), isNull);
    });

    test('is validated when entered', () {
      expect(Validators.optionalEmail('rahul'), isNotNull);
      expect(Validators.optionalEmail('rahul@'), isNotNull);
      expect(Validators.optionalEmail('rahul@example'), isNotNull);
      expect(Validators.optionalEmail('rahul@example.com'), isNull);
    });
  });

  test('selection requires a value', () {
    expect(Validators.selection(null, 'project'), 'Select a project');
    expect(Validators.selection('Project A', 'project'), isNull);
  });
}
