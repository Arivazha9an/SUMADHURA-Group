import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Labeled form text field with the app's decoration and sensible defaults.
/// Thin wrapper over [TextFormField] so every form field looks and behaves the
/// same; styling itself comes from `InputDecorationTheme` in the app theme.
class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.helperText,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.enabled = true,
    this.autocorrect = true,
    this.minLines,
    this.maxLines = 1,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final String? helperText;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final bool autocorrect;

  /// For multi-line fields (set [minLines] and [maxLines]).
  final int? minLines;
  final int? maxLines;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      autocorrect: autocorrect,
      minLines: minLines,
      maxLines: maxLines,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        alignLabelWithHint: (maxLines ?? 1) > 1,
      ),
    );
  }
}
