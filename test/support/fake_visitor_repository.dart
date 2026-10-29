import 'package:visitor_management/core/error/app_exception.dart';
import 'package:visitor_management/features/visitors/data/visitor_repository.dart';
import 'package:visitor_management/features/visitors/domain/visitor.dart';

/// In-memory stand-in for the REST API that mimics server behaviour with two
/// resources like the real one: `visitors` (identity) and `visits`. It
/// generates ids, stores what is PATCHed, and can be told to fail.
class FakeVisitorRepository implements VisitorRepository {
  FakeVisitorRepository([List<Visitor> seed = const []]) {
    for (final visitor in seed) {
      _storeVisitor(visitor);
    }
  }

  final Map<String, Visitor> _visitors = {};
  final Map<String, Visit> _visits = {};
  int _nextId = 100;

  /// When set, every call throws this instead of succeeding.
  AppException? failure;

  /// Number of check-in / check-out PATCH requests that reached the "server".
  int statusPatchCalls = 0;

  /// Number of POST /visits requests (new sessions created).
  int visitCreateCalls = 0;

  static const AppException offline = AppException(
    AppErrorType.network,
    "Can't reach the server.",
  );

  Future<void> _roundTrip() async {
    await Future<void>.delayed(Duration.zero);
    if (failure != null) throw failure!;
  }

  void _storeVisitor(Visitor visitor) {
    _visitors[visitor.id] = visitor.withVisits(const []);
    _visits.removeWhere((_, v) => v.visitorId == visitor.id);
    for (final visit in visitor.visits) {
      _visits[visit.id] = visit;
    }
  }

  Visitor _joined(String id) {
    final visitor = _visitors[id];
    if (visitor == null) {
      throw const AppException(AppErrorType.notFound, 'Not found');
    }
    return visitor.withVisits(
      _visits.values.where((v) => v.visitorId == id).toList(),
    );
  }

  Visit _requireVisit(String id) {
    final visit = _visits[id];
    if (visit == null) {
      throw const AppException(AppErrorType.notFound, 'Not found');
    }
    return visit;
  }

  /// Replaces a record (identity and visits) behind the app's back, like
  /// another device would.
  void changeOnServer(Visitor visitor) => _storeVisitor(visitor);

  /// Adds a visit behind the app's back, like another device starting one.
  void addVisitOnServer(Visit visit) => _visits[visit.id] = visit;

  Visitor? onServer(String id) => _visitors.containsKey(id) ? _joined(id) : null;

  List<Visit> visitsOnServer(String visitorId) =>
      _visits.values.where((v) => v.visitorId == visitorId).toList();

  @override
  Future<List<Visitor>> fetchAll() async {
    await _roundTrip();
    return [for (final id in _visitors.keys) _joined(id)];
  }

  @override
  Future<Visitor> fetchById(String id) async {
    await _roundTrip();
    return _joined(id);
  }

  @override
  Future<Visitor> create(
    VisitorDraft draft, {
    required DateTime createdAt,
  }) async {
    await _roundTrip();
    final id = '${_nextId++}';
    _visitors[id] = Visitor(
      id: id,
      name: draft.name,
      mobile: draft.mobile,
      email: draft.email,
      visitorType: draft.visitorType,
      createdAt: createdAt,
    );
    final visit = await _insertVisit(
      id,
      project: draft.project,
      purpose: draft.purpose,
      createdAt: createdAt,
    );
    return _joined(id).withVisit(visit);
  }

  @override
  Future<Visitor> update(
    String id,
    VisitorDraft draft, {
    String? activeVisitId,
  }) async {
    await _roundTrip();
    final current = _joined(id);
    _visitors[id] = Visitor(
      id: id,
      name: draft.name,
      mobile: draft.mobile,
      email: draft.email,
      visitorType: draft.visitorType,
      createdAt: current.createdAt,
    );
    if (activeVisitId != null) {
      final visit = _requireVisit(activeVisitId);
      _visits[activeVisitId] = Visit(
        id: visit.id,
        visitorId: visit.visitorId,
        project: draft.project,
        purpose: draft.purpose,
        status: visit.status,
        createdAt: visit.createdAt,
        checkInTime: visit.checkInTime,
        checkOutTime: visit.checkOutTime,
      );
    }
    return _joined(id);
  }

  @override
  Future<void> delete(String id) async {
    await _roundTrip();
    _joined(id);
    _visitors.remove(id);
    _visits.removeWhere((_, v) => v.visitorId == id);
  }

  @override
  Future<Visit> startVisit(
    String visitorId, {
    required String project,
    required String purpose,
    required DateTime createdAt,
  }) async {
    await _roundTrip();
    _joined(visitorId);
    return _insertVisit(
      visitorId,
      project: project,
      purpose: purpose,
      createdAt: createdAt,
    );
  }

  Future<Visit> _insertVisit(
    String visitorId, {
    required String project,
    required String purpose,
    required DateTime createdAt,
  }) async {
    visitCreateCalls++;
    final visit = Visit(
      id: 'v${_nextId++}',
      visitorId: visitorId,
      project: project,
      purpose: purpose,
      status: VisitorStatus.registered,
      createdAt: createdAt,
    );
    _visits[visit.id] = visit;
    return visit;
  }

  @override
  Future<Visit> checkIn(String visitId, DateTime at) async {
    await _roundTrip();
    statusPatchCalls++;
    final visit = _requireVisit(visitId);
    final updated = Visit(
      id: visit.id,
      visitorId: visit.visitorId,
      project: visit.project,
      purpose: visit.purpose,
      status: VisitorStatus.checkedIn,
      createdAt: visit.createdAt,
      checkInTime: at,
    );
    _visits[visitId] = updated;
    return updated;
  }

  @override
  Future<Visit> checkOut(String visitId, DateTime at) async {
    await _roundTrip();
    statusPatchCalls++;
    final visit = _requireVisit(visitId);
    final updated = Visit(
      id: visit.id,
      visitorId: visit.visitorId,
      project: visit.project,
      purpose: visit.purpose,
      status: VisitorStatus.checkedOut,
      createdAt: visit.createdAt,
      checkInTime: visit.checkInTime,
      checkOutTime: at,
    );
    _visits[visitId] = updated;
    return updated;
  }
}
