import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../config/ui_style.dart';

/// Shared measurements for the glass look.
class GlassTokens {
  const GlassTokens._();

  static const double radius = 24;
  static const double navHeight = 64;

  /// Space to leave at the bottom of scrollable content so it can pass under
  /// the floating tab bar / action bar and still scroll fully into view.
  static double bottomInset(BuildContext context) =>
      MediaQuery.viewPaddingOf(context).bottom + 96;
}

/// Soft colored backdrop. Glass only reads as glass when there is something
/// colorful behind it to blur, so every screen sits on this. With
/// `GLASS_UI=false` it is a plain flat background instead.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!UiStyle.glass) {
      return ColoredBox(color: AppTheme.materialBackground, child: child);
    }
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8F1FF), Color(0xFFF1EEFF), Color(0xFFE4F6F2)],
        ),
      ),
      child: Stack(
        children: [
          const _Blob(Alignment(-1.1, -0.95), Color(0xFF5AA9FF), 360),
          const _Blob(Alignment(1.25, -0.15), Color(0xFFB39BFF), 320),
          const _Blob(Alignment(-0.95, 1.05), Color(0xFF6FDCC4), 340),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob(this.alignment, this.color, this.size);

  final Alignment alignment;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: alignment,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.55),
                  color.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A Scaffold that paints the app backdrop behind itself, so each pushed
/// route is opaque and page transitions never show a screen through another.
class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.extendBody = false,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;

  /// Lets [body] draw underneath a floating [bottomNavigationBar]. Ignored in
  /// the Material style, where the bar is a normal docked bar.
  final bool extendBody;

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: UiStyle.glass && extendBody,
        appBar: appBar,
        body: body,
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}

/// Frosted panel: background blur, translucent tinted fill with a light-to-
/// clear sheen, a thin bright rim (the "specular" edge) and a faint shadow.
///
/// In the Material style it becomes a plain bordered surface (no blur, no
/// shadow) that is at least 90% opaque, so text stays readable on top of it.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.radius = GlassTokens.radius,
    this.padding,
    this.blur = 22,
    this.tint = Colors.white,
    this.tintAlpha = 0.5,
    this.rimAlpha = 0.75,
    this.elevated = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;

  /// Blur sigma; 0 skips the (relatively costly) backdrop filter.
  final double blur;
  final Color tint;
  final double tintAlpha;
  final double rimAlpha;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final content =
        padding == null ? child : Padding(padding: padding!, child: child);

    if (!UiStyle.glass) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: tint.withValues(alpha: tintAlpha < 0.9 ? 0.9 : tintAlpha),
          borderRadius: borderRadius,
          border: Border.all(color: AppTheme.border),
        ),
        child: content,
      );
    }

    Widget panel = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tint.withValues(
              alpha: (tintAlpha + 0.2).clamp(0.0, 1.0).toDouble(),
            ),
            tint.withValues(alpha: tintAlpha),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: rimAlpha),
        ),
      ),
      child: content,
    );

    if (blur > 0) {
      panel = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: panel,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: elevated
            ? const [
                BoxShadow(
                  color: Color(0x141B3A6B),
                  blurRadius: 28,
                  offset: Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: ClipRRect(borderRadius: borderRadius, child: panel),
    );
  }
}

class GlassNavItem {
  const GlassNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Bottom navigation. Glass style: a floating capsule with a tinted glass pill
/// behind the selected tab. Material style: a standard [NavigationBar].
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<GlassNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (!UiStyle.glass) {
      return NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        destinations: [
          for (final item in items)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: item.label,
            ),
        ],
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: GlassContainer(
          radius: 34,
          blur: 30,
          tintAlpha: 0.45,
          padding: const EdgeInsets.all(5),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: items[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final color = selected ? primary : const Color(0xFF4A5A6C);

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: GlassTokens.navHeight - 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: selected ? Colors.white.withValues(alpha: 0.7) : null,
            border: selected
                ? Border.all(color: Colors.white.withValues(alpha: 0.9))
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? item.selectedIcon : item.icon, color: color),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
