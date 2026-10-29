import 'package:flutter_test/flutter_test.dart';
import 'package:visitor_management/features/dashboard/domain/dashboard_stats.dart';
import 'package:visitor_management/features/visitors/domain/visitor.dart';

import 'support/test_data.dart';

void main() {
  final now = DateTime(2026, 10, 27, 12);
  final yesterday = DateTime(2026, 10, 26, 15);
  final earlierToday = DateTime(2026, 10, 27, 9);

  test('counts come from the records, using the local day', () {
    final visitors = [
      // Registered today, still waiting.
      buildVisitor(id: '1', createdAt: earlierToday),
      // Registered yesterday, still inside: counts as checked in, not "today".
      buildVisitor(
        id: '2',
        createdAt: yesterday,
        status: VisitorStatus.checkedIn,
        checkInTime: yesterday,
      ),
      // Registered today, checked out today.
      buildVisitor(
        id: '3',
        createdAt: earlierToday,
        status: VisitorStatus.checkedOut,
        checkInTime: earlierToday,
        checkOutTime: DateTime(2026, 10, 27, 11),
      ),
      // Checked out yesterday: must not count as checked out today.
      buildVisitor(
        id: '4',
        createdAt: yesterday,
        status: VisitorStatus.checkedOut,
        checkInTime: yesterday,
        checkOutTime: DateTime(2026, 10, 26, 17),
      ),
    ];

    final stats = DashboardStats.fromVisitors(visitors, now);

    expect(stats.registeredToday, 2);
    expect(stats.currentlyCheckedIn, 1);
    expect(stats.checkedOutToday, 1);
  });

  test('empty data gives zeros and no activity', () {
    final stats = DashboardStats.fromVisitors(const [], now);
    expect(stats.registeredToday, 0);
    expect(stats.currentlyCheckedIn, 0);
    expect(stats.checkedOutToday, 0);
    expect(stats.recentActivity, isEmpty);
  });

  test('recent activity is newest first, one entry per visitor, capped', () {
    final visitors = [
      for (var i = 0; i < 8; i++)
        buildVisitor(id: '$i', createdAt: DateTime(2026, 10, 27, 1 + i)),
      buildVisitor(
        id: 'out',
        createdAt: DateTime(2026, 10, 27, 0, 30),
        status: VisitorStatus.checkedOut,
        checkInTime: DateTime(2026, 10, 27, 0, 40),
        checkOutTime: DateTime(2026, 10, 27, 11, 30),
      ),
    ];

    final stats = DashboardStats.fromVisitors(visitors, now);

    expect(stats.recentActivity.length, DashboardStats.recentLimit);
    expect(stats.recentActivity.first.visitor.id, 'out');
    expect(stats.recentActivity.first.type, ActivityType.checkedOut);
    final times = stats.recentActivity.map((a) => a.at).toList();
    expect([...times]..sort((a, b) => b.compareTo(a)), times);
  });
}
