import 'package:flutter/material.dart';

enum CustomButtonVariant {
  /// Main action on a screen (filled).
  primary,

  /// Secondary action such as Cancel or Scan (outlined).
  secondary,
}

/// App-wide button: optional leading icon, a loading state and one consistent
/// shape from the theme.
///
/// While [isLoading] is true the button shows a spinner and ignores taps but
/// keeps its normal colors (a disabled button would grey the spinner out).
/// Pass `onPressed: null` for a genuinely disabled button.
class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = CustomButtonVariant.primary,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final CustomButtonVariant variant;

  /// Fill the available width. Set false for an intrinsic-width button.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPrimary = variant == CustomButtonVariant.primary;

    final VoidCallback? effectiveOnPressed =
        isLoading ? () {} : onPressed;

    final Widget leading = isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isPrimary ? scheme.onPrimary : scheme.primary,
            ),
          )
        : icon == null
            ? const SizedBox.shrink()
            : Icon(icon, size: 20);

    final hasLeading = isLoading || icon != null;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hasLeading) ...[leading, const SizedBox(width: 8)],
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    final button = isPrimary
        ? FilledButton(onPressed: effectiveOnPressed, child: content)
        : OutlinedButton(onPressed: effectiveOnPressed, child: content);

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
