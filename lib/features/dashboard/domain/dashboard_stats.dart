import 'package:equatable/equatable.dart';

import '../../../core/utils/date_time_utils.dart';
import '../../visitors/domain/visitor.dart';

enum ActivityType { registered, checkedIn, checkedOut }

/// The latest thing that happened to one visitor.
class RecentActivity extends Equatable {
  const RecentActivity({
    required this.visitor,
    required this.type,
    required this.at,
  });

  final Visitor visitor;
  final ActivityType type;
  final DateTime at;

  @override
  List<Object?> get props => [visitor, type, at];
}

/// Dashboard figures, derived purely from the visit sessions retrieved from
/// the API. "Today" is the device's local calendar day.
///
/// - [registeredToday]: distinct visitors who have a visit session created
///   today. A returning visitor counts today even though their profile is
///   older, and two visits by one person on the same day count once.
/// - [currentlyCheckedIn]: visits with status Checked In (any start day: the
///   person is still inside).
/// - [checkedOutToday]: visits checked out today. A check-out from an earlier
///   day is never counted.
/// - [recentActivity]: the latest event of each visit, newest first.
class DashboardStats extends Equatable {
  const DashboardStats({
    required this.registeredToday,
    required this.currentlyCheckedIn,
    required this.checkedOutToday,
    required this.recentActivity,
  });

  final int registeredToday;
  final int currentlyCheckedIn;
  final int checkedOutToday;
  final List<RecentActivity> recentActivity;

  static const int recentLimit = 5;

  factory DashboardStats.fromVisitors(List<Visitor> visitors, DateTime now) {
    final visitorsWithVisitToday = <String>{};
    var currentlyCheckedIn = 0;
    var checkedOutToday = 0;
    final activity = <RecentActivity>[];

    for (final visitor in visitors) {
      for (final visit in visitor.visits) {
        if (isSameLocalDay(visit.createdAt, now)) {
          visitorsWithVisitToday.add(visitor.id);
        }
        if (visit.status == VisitorStatus.checkedIn) currentlyCheckedIn++;
        final checkOut = visit.checkOutTime;
        if (visit.status == VisitorStatus.checkedOut &&
            checkOut != null &&
            isSameLocalDay(checkOut, now)) {
          checkedOutToday++;
        }
        activity.add(_latestActivity(visitor, visit));
      }
    }

    activity.sort((a, b) => b.at.compareTo(a.at));
    return DashboardStats(
      registeredToday: visitorsWithVisitToday.length,
      currentlyCheckedIn: currentlyCheckedIn,
      checkedOutToday: checkedOutToday,
      recentActivity: activity.take(recentLimit).toList(),
    );
  }

  static RecentActivity _latestActivity(Visitor visitor, Visit visit) {
    if (visit.status == VisitorStatus.checkedOut &&
        visit.checkOutTime != null) {
      return RecentActivity(
        visitor: visitor,
        type: ActivityType.checkedOut,
        at: visit.checkOutTime!,
      );
    }
    if (visit.status != VisitorStatus.registered &&
        visit.checkInTime != null) {
      return RecentActivity(
        visitor: visitor,
        type: ActivityType.checkedIn,
        at: visit.checkInTime!,
      );
    }
    return RecentActivity(
      visitor: visitor,
      type: ActivityType.registered,
      at: visit.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        registeredToday,
        currentlyCheckedIn,
        checkedOutToday,
        recentActivity,
      ];
}
