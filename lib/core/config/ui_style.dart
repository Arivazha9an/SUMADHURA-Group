/// Chooses the visual style at build time:
///
///   flutter run --dart-define=GLASS_UI=false    // plain Material look
///   flutter build apk --dart-define=GLASS_UI=true   // default: liquid glass
///
/// The glass widgets in `core/widgets/glass.dart` and the theme in
/// `app/theme/app_theme.dart` both read this flag, so one switch changes the
/// whole app and screens never need to know which style is active.
class UiStyle {
  const UiStyle._();

  static const bool glass = bool.fromEnvironment(
    'GLASS_UI',
    defaultValue: true,
  );
}
