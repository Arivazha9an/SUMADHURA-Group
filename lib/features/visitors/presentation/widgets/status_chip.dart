import 'package:flutter/material.dart';

import '../../domain/visitor.dart';

/// Status colors are defined once so the list, details and dashboard agree:
/// amber = waiting to enter, green = on site, slate = finished.
class StatusStyle {
  const StatusStyle(this.color, this.background, this.icon);

  final Color color;
  final Color background;
  final IconData icon;

  static StatusStyle of(VisitorStatus status) => switch (status) {
        VisitorStatus.registered => const StatusStyle(
            Color(0xFF9A5B00),
            Color(0xFFFFF1D6),
            Icons.schedule,
          ),
        VisitorStatus.checkedIn => const StatusStyle(
            Color(0xFF1B7A3A),
            Color(0xFFDDF3E4),
            Icons.login,
          ),
        VisitorStatus.checkedOut => const StatusStyle(
            Color(0xFF55616B),
            Color(0xFFE6EAEE),
            Icons.logout,
          ),
      };
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final VisitorStatus status;

  @override
  Widget build(BuildContext context) {
    final style = StatusStyle.of(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: style.color,
            ),
          ),
        ],
      ),
    );
  }
}
