/// Timestamp helpers. All "today" logic uses the device's local calendar day.

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// ISO-8601 with the local UTC offset, e.g. `2026-10-26T10:30:00+05:30`,
/// matching the format in the assignment's sample JSON.
String toIso8601WithOffset(DateTime value) {
  final local = value.toLocal();
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  final date = '${local.year.toString().padLeft(4, '0')}-${_two(local.month)}-'
      '${_two(local.day)}';
  final time = '${_two(local.hour)}:${_two(local.minute)}:${_two(local.second)}';
  return '${date}T$time$sign${_two(minutes ~/ 60)}:${_two(minutes % 60)}';
}

bool isSameLocalDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

String formatTime(DateTime value) {
  final local = value.toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final suffix = local.hour < 12 ? 'AM' : 'PM';
  return '$hour12:${_two(local.minute)} $suffix';
}

/// `27 Oct 2026, 10:30 AM`
String formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}, '
      '${formatTime(local)}';
}

/// Time when the value is from [now]'s day, otherwise `26 Oct, 10:30 AM`.
String formatRelativeToDay(DateTime value, DateTime now) {
  if (isSameLocalDay(value, now)) return formatTime(value);
  final local = value.toLocal();
  return '${local.day} ${_months[local.month - 1]}, ${formatTime(local)}';
}

/// `Tuesday, 27 October`-style heading for the dashboard.
String formatDayHeading(DateTime value) {
  final local = value.toLocal();
  return '${_weekdays[local.weekday - 1]}, ${local.day} '
      '${_months[local.month - 1]} ${local.year}';
}
