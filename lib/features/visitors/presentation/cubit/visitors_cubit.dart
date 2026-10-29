import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_exception.dart';
import '../../data/visitor_repository.dart';
import '../../domain/visitor.dart';
import 'visitors_state.dart';

/// Single source of truth for visitor data. The list, details and dashboard
/// screens all read from this state, so one successful mutation updates all
/// of them without a restart.
class VisitorsCubit extends Cubit<VisitorsState> {
  VisitorsCubit(this._repository, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now,
        super(const VisitorsState());

  final VisitorRepository _repository;
  final DateTime Function() _now;

  /// Shown when check-in/out is attempted but every visit is already finished.
  static const String noActiveVisitMessage =
      'This visitor has no active visit. Start a new visit first.';

  // ---------------------------------------------------------------- loading

  /// Loads (or reloads) all visitors. If data is already on screen and the
  /// refresh fails, the old data stays visible and the error is returned so
  /// the caller can show a snackbar.
  Future<ActionResult<void>> load() async {
    if (state.status == LoadStatus.loading) return const ActionResult.ignored();
    emit(state.copyWith(status: LoadStatus.loading, clearError: true));
    try {
      final visitors = await _repository.fetchAll();
      _emit(
        state.copyWith(
          status: LoadStatus.success,
          visitors: _newestFirst(visitors),
          clearError: true,
        ),
      );
      return const ActionResult.success();
    } on AppException catch (error) {
      final hasData = state.visitors.isNotEmpty;
      _emit(
        state.copyWith(
          status: hasData ? LoadStatus.success : LoadStatus.failure,
          errorMessage: error.message,
          errorType: error.type,
        ),
      );
      return ActionResult.failure(error.message);
    }
  }

  void setQuery(String query) => emit(state.copyWith(query: query));

  /// Filter the list by status; null shows everyone. Keeps the search text.
  void setStatusFilter(VisitorStatus? status) {
    emit(
      status == null
          ? state.copyWith(clearStatusFilter: true)
          : state.copyWith(statusFilter: status),
    );
  }

  /// Filter the list by project; null shows all projects.
  void setProjectFilter(String? project) {
    emit(
      project == null
          ? state.copyWith(clearProjectFilter: true)
          : state.copyWith(projectFilter: project),
    );
  }

  void clearFilters() {
    emit(
      state.copyWith(
        query: '',
        clearStatusFilter: true,
        clearProjectFilter: true,
      ),
    );
  }

  /// Fetches one visitor straight from the API (used after a QR scan) and
  /// merges it into state, so the list never lags behind the server.
  Future<ActionResult<Visitor>> lookup(String id) async {
    try {
      final visitor = await _repository.fetchById(id);
      _upsert(visitor);
      return ActionResult.success(visitor);
    } on AppException catch (error) {
      if (error.type == AppErrorType.notFound) {
        return ActionResult.failure('No visitor found for ID "$id".');
      }
      return ActionResult.failure(error.message);
    }
  }

  // ------------------------------------------------------- register / edit

  Future<ActionResult<Visitor>> register(VisitorDraft draft) async {
    if (state.isSaving) return const ActionResult.ignored();
    emit(state.copyWith(isSaving: true));
    try {
      // The ID comes from the server response; the QR code is built from it.
      final visitor = await _repository.create(draft, createdAt: _now());
      _upsert(visitor, isSaving: false);
      return ActionResult.success(visitor);
    } on AppException catch (error) {
      _emit(state.copyWith(isSaving: false));
      return ActionResult.failure(error.message);
    }
  }

  Future<ActionResult<Visitor>> updateVisitor(
    String id,
    VisitorDraft draft,
  ) async {
    if (state.isSaving) return const ActionResult.ignored();
    emit(state.copyWith(isSaving: true));
    try {
      // Only an unfinished visit may have its project / purpose edited;
      // completed visits are history and stay exactly as they were.
      final activeVisitId = state.byId(id)?.activeVisit?.id;
      final visitor = await _repository.update(
        id,
        draft,
        activeVisitId: activeVisitId,
      );
      _upsert(visitor, isSaving: false);
      return ActionResult.success(visitor);
    } on AppException catch (error) {
      _emit(state.copyWith(isSaving: false));
      return ActionResult.failure(error.message);
    }
  }

  // ----------------------------------------------------------------- delete

  Future<ActionResult<void>> delete(String id) async {
    if (state.busyIds.contains(id)) return const ActionResult.ignored();
    _setBusy(id, true);
    try {
      await _repository.delete(id);
      _emit(
        state.copyWith(
          visitors: state.visitors.where((v) => v.id != id).toList(),
        ),
      );
      return const ActionResult.success();
    } on AppException catch (error) {
      return ActionResult.failure(error.message);
    } finally {
      _setBusy(id, false);
    }
  }

  // ----------------------------------------------- visits, check-in / check-out

  /// Starts a NEW visit session for a returning visitor. A finished visit is
  /// never reopened or modified.
  ///
  /// If the visitor already has an unfinished visit nothing is created: the
  /// result is a failure that explains why, and the state holds the fresh
  /// record so the screen shows that active visit.
  Future<ActionResult<Visitor>> startNewVisit(
    String visitorId, {
    required String project,
    required String purpose,
  }) async {
    if (state.busyIds.contains(visitorId)) return const ActionResult.ignored();
    _setBusy(visitorId, true);
    try {
      // Re-read first: another device (or an earlier tap) may already have
      // started a visit, and the local list could be stale.
      final fresh = await _repository.fetchById(visitorId);
      final active = fresh.activeVisit;
      if (active != null) {
        _upsert(fresh);
        return ActionResult.failure(
          'This visitor already has an active visit (${active.status.label}). '
          'Finish it before starting a new one.',
        );
      }
      final visit = await _repository.startVisit(
        visitorId,
        project: project,
        purpose: purpose,
        createdAt: _now(),
      );
      final updated = fresh.withVisit(visit);
      _upsert(updated);
      return ActionResult.success(updated);
    } on AppException catch (error) {
      return ActionResult.failure(
        error.type == AppErrorType.notFound
            ? 'This visitor record no longer exists.'
            : error.message,
      );
    } finally {
      _setBusy(visitorId, false);
    }
  }

  Future<ActionResult<Visitor>> checkIn(String id) {
    return _changeStatus(
      id,
      blockedReason: (status) => status.checkInBlockedReason,
      apply: _repository.checkIn,
    );
  }

  Future<ActionResult<Visitor>> checkOut(String id) {
    return _changeStatus(
      id,
      blockedReason: (status) => status.checkOutBlockedReason,
      apply: _repository.checkOut,
    );
  }

  /// Shared flow for both transitions, applied to the visitor's current visit.
  ///
  /// 1. The busy flag is set synchronously, before the first `await`, so rapid
  ///    double taps or repeated scanner callbacks cannot start a second request.
  /// 2. The visitor and their visits are re-read from the server first: the
  ///    list on this device may be stale (another device, or an earlier scan,
  ///    may already have changed the status).
  /// 3. Only if that fresh visit's status allows the transition is the PATCH
  ///    sent, and the local state is updated from the server's response, never
  ///    from optimistic guesses.
  /// 4. A finished visit is never patched: with no unfinished visit the user
  ///    is told to start a new one.
  Future<ActionResult<Visitor>> _changeStatus(
    String id, {
    required String? Function(VisitorStatus status) blockedReason,
    required Future<Visit> Function(String visitId, DateTime at) apply,
  }) async {
    if (state.busyIds.contains(id)) return const ActionResult.ignored();
    _setBusy(id, true);
    try {
      final fresh = await _repository.fetchById(id);
      final visit = fresh.activeVisit;
      if (visit == null) {
        _upsert(fresh);
        return const ActionResult.failure(noActiveVisitMessage);
      }
      final reason = blockedReason(visit.status);
      if (reason != null) {
        _upsert(fresh);
        return ActionResult.failure(reason);
      }
      final updatedVisit = await apply(visit.id, _now());
      final updated = fresh.withVisit(updatedVisit);
      _upsert(updated);
      return ActionResult.success(updated);
    } on AppException catch (error) {
      return ActionResult.failure(
        error.type == AppErrorType.notFound
            ? 'This visitor record no longer exists.'
            : error.message,
      );
    } finally {
      _setBusy(id, false);
    }
  }

  // ---------------------------------------------------------------- helpers

  void _setBusy(String id, bool busy) {
    final ids = {...state.busyIds};
    if (busy) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    _emit(state.copyWith(busyIds: ids));
  }

  void _upsert(Visitor visitor, {bool? isSaving}) {
    final list = [...state.visitors];
    final index = list.indexWhere((v) => v.id == visitor.id);
    if (index == -1) {
      list.add(visitor);
    } else {
      list[index] = visitor;
    }
    _emit(
      state.copyWith(
        visitors: _newestFirst(list),
        isSaving: isSaving,
        status: state.status == LoadStatus.initial ? LoadStatus.success : null,
      ),
    );
  }

  List<Visitor> _newestFirst(List<Visitor> visitors) {
    final sorted = [...visitors];
    sorted.sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
    return sorted;
  }

  /// Avoids "emit after close" errors if a request finishes after disposal.
  void _emit(VisitorsState next) {
    if (!isClosed) emit(next);
  }
}
