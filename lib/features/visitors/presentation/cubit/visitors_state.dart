import 'package:equatable/equatable.dart';

import '../../../../core/error/app_exception.dart';
import '../../domain/visitor.dart';

enum LoadStatus { initial, loading, success, failure }

/// Outcome of a user-triggered operation (register, delete, check-in, ...).
/// Lets the UI show a snackbar without the cubit knowing about widgets.
class ActionResult<T> {
  const ActionResult.success([this.data])
      : error = null,
        isIgnored = false;

  const ActionResult.failure(String this.error)
      : data = null,
        isIgnored = false;

  /// The same action was already running, so nothing was done.
  const ActionResult.ignored()
      : data = null,
        error = null,
        isIgnored = true;

  final T? data;
  final String? error;
  final bool isIgnored;

  bool get isSuccess => error == null && !isIgnored;
}

/// Pure search + filter logic, separate from the state so it is easy to test.
///
/// - Name: case-insensitive, partial.
/// - Mobile: partial match, from the first digit. Only used when the query
///   looks like a phone number (digits, spaces, dashes, "+", brackets), so an
///   ID such as "VIS-7" is not turned into the digit "7" and matched against
///   every mobile containing a 7.
/// - Visitor id: exact match (case-insensitive), never partial, so "VIS" or "1"
///   does not return every id that merely contains it.
/// - [status] / [project]: when set, only visitors with that value are kept.
List<Visitor> searchVisitors(
  List<Visitor> visitors, {
  String query = '',
  VisitorStatus? status,
  String? project,
}) {
  final text = query.trim().toLowerCase();
  final looksLikePhone = RegExp(r'^[\d\s\-+()]+$').hasMatch(text);
  final digits = text.replaceAll(RegExp(r'\D'), '');

  bool matchesText(Visitor visitor) {
    if (text.isEmpty) return true;
    if (visitor.id.toLowerCase() == text) return true;
    if (visitor.name.toLowerCase().contains(text)) return true;
    return looksLikePhone && digits.isNotEmpty && visitor.mobile.contains(digits);
  }

  return visitors
      .where(
        (v) =>
            (status == null || v.status == status) &&
            (project == null || v.project == project) &&
            matchesText(v),
      )
      .toList();
}

class VisitorsState extends Equatable {
  const VisitorsState({
    this.status = LoadStatus.initial,
    this.visitors = const [],
    this.query = '',
    this.statusFilter,
    this.projectFilter,
    this.errorMessage,
    this.errorType,
    this.isSaving = false,
    this.busyIds = const {},
  });

  final LoadStatus status;

  /// All visitors from the API, newest first. Dashboard figures are derived
  /// from this list, so every mutation updates every screen.
  final List<Visitor> visitors;
  final String query;

  /// Null means "All".
  final VisitorStatus? statusFilter;

  /// Null means "All projects".
  final String? projectFilter;
  final String? errorMessage;
  final AppErrorType? errorType;

  /// True while a registration or edit request is in flight.
  final bool isSaving;

  /// Visitor IDs with a delete / check-in / check-out request in flight.
  final Set<String> busyIds;

  bool get isInitialLoading =>
      (status == LoadStatus.loading || status == LoadStatus.initial) &&
      visitors.isEmpty;

  bool get hasFailedWithoutData =>
      status == LoadStatus.failure && visitors.isEmpty;

  bool get hasActiveFilters =>
      query.trim().isNotEmpty || statusFilter != null || projectFilter != null;

  Visitor? byId(String id) {
    for (final visitor in visitors) {
      if (visitor.id == id) return visitor;
    }
    return null;
  }

  /// Visitors after applying the search text and both filters.
  List<Visitor> get filtered => searchVisitors(
        visitors,
        query: query,
        status: statusFilter,
        project: projectFilter,
      );

  /// How many visitors match the search text and project in each status, so
  /// the filter chips show counts that agree with what the list would display.
  int countFor(VisitorStatus? status) => searchVisitors(
        visitors,
        query: query,
        status: status,
        project: projectFilter,
      ).length;

  /// Projects offered in the project filter: the standard ones plus any other
  /// project found in the loaded records.
  List<String> get projectOptions =>
      {...kProjects, ...visitors.map((v) => v.project)}.toList();

  VisitorsState copyWith({
    LoadStatus? status,
    List<Visitor>? visitors,
    String? query,
    VisitorStatus? statusFilter,
    bool clearStatusFilter = false,
    String? projectFilter,
    bool clearProjectFilter = false,
    String? errorMessage,
    AppErrorType? errorType,
    bool clearError = false,
    bool? isSaving,
    Set<String>? busyIds,
  }) {
    return VisitorsState(
      status: status ?? this.status,
      visitors: visitors ?? this.visitors,
      query: query ?? this.query,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      projectFilter:
          clearProjectFilter ? null : (projectFilter ?? this.projectFilter),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorType: clearError ? null : (errorType ?? this.errorType),
      isSaving: isSaving ?? this.isSaving,
      busyIds: busyIds ?? this.busyIds,
    );
  }

  @override
  List<Object?> get props => [
        status,
        visitors,
        query,
        statusFilter,
        projectFilter,
        errorMessage,
        errorType,
        isSaving,
        busyIds,
      ];
}
