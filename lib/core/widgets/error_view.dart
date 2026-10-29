import 'package:flutter/material.dart';

import '../error/app_exception.dart';
import 'empty_state.dart';

/// Full-area failure state with a retry action. The icon and headline depend
/// on what went wrong, so "no connection" reads differently from "server error".
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.type,
  });

  final String message;
  final VoidCallback onRetry;
  final AppErrorType? type;

  @override
  Widget build(BuildContext context) {
    final (icon, title) = switch (type) {
      AppErrorType.network => (Icons.wifi_off_outlined, 'No connection'),
      AppErrorType.timeout => (Icons.timer_off_outlined, 'Server is slow'),
      AppErrorType.server => (Icons.cloud_off_outlined, 'Server problem'),
      AppErrorType.malformedResponse => (
          Icons.report_gmailerrorred_outlined,
          'Unexpected data',
        ),
      _ => (Icons.error_outline, "Couldn't load visitors"),
    };

    return EmptyState(
      icon: icon,
      title: title,
      message: message,
      actionLabel: 'Try again',
      onAction: onRetry,
    );
  }
}
