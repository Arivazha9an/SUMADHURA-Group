/// Form validators, kept as pure functions so they can be unit-tested.
class Validators {
  const Validators._();

  static final RegExp _mobilePattern = RegExp(r'^\d{10}$');
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static String? requiredText(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? mobile(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Mobile number is required';
    if (!_mobilePattern.hasMatch(text)) return 'Enter exactly 10 digits';
    return null;
  }

  /// Email is optional; it is only checked when something was entered.
  static String? optionalEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (!_emailPattern.hasMatch(text)) return 'Enter a valid email address';
    return null;
  }

  static String? selection(Object? value, String fieldName) {
    if (value == null) return 'Select a $fieldName';
    return null;
  }
}
