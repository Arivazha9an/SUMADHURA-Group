import 'package:flutter/material.dart';

/// Shows one snackbar at a time. Safe to call right before navigating away,
/// because the messenger belongs to the app, not to the current screen.
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: isError ? scheme.onError : null),
        ),
        backgroundColor: isError ? scheme.error : null,
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
}
