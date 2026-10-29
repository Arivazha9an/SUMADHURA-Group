import 'package:dio/dio.dart';

import '../../../core/config/api_config.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/utils/date_time_utils.dart';
import '../domain/visitor.dart';

/// Remote data access for visitors and their visit sessions. Every method
/// either returns data from the server or throws an [AppException]; nothing is
/// faked locally.
///
/// Two REST resources are involved: `visitors` (identity) and `visits` (one
/// record per session, linked by `visitor_id`). The repository joins them so
/// the rest of the app only sees a [Visitor] with its [Visitor.visits].
abstract class VisitorRepository {
  Future<List<Visitor>> fetchAll();

  /// The visitor with all of their visits, read fresh from the server.
  Future<Visitor> fetchById(String id);

  /// Creates the visitor and their first visit (status Registered).
  Future<Visitor> create(VisitorDraft draft, {required DateTime createdAt});

  /// Updates identity fields. When [activeVisitId] is given, that unfinished
  /// visit's project and purpose are updated too. Finished visits are never
  /// touched.
  Future<Visitor> update(
    String id,
    VisitorDraft draft, {
    String? activeVisitId,
  });

  /// Deletes the visitor and all of their visits.
  Future<void> delete(String id);

  /// Creates a NEW visit (status Registered) for an existing visitor.
  Future<Visit> startVisit(
    String visitorId, {
    required String project,
    required String purpose,
    required DateTime createdAt,
  });

  Future<Visit> checkIn(String visitId, DateTime at);
  Future<Visit> checkOut(String visitId, DateTime at);
}

class ApiVisitorRepository implements VisitorRepository {
  ApiVisitorRepository(this._dio);

  final Dio _dio;

  String _visitorPath(String id) =>
      '${ApiConfig.visitorsPath}/${Uri.encodeComponent(id)}';

  String _visitPath(String id) =>
      '${ApiConfig.visitsPath}/${Uri.encodeComponent(id)}';

  @override
  Future<List<Visitor>> fetchAll() {
    return _guard(() async {
      final responses = await Future.wait([
        _dio.get<Object?>(ApiConfig.visitorsPath),
        _dio.get<Object?>(ApiConfig.visitsPath),
      ]);
      final visitorRows = _listFrom(responses[0].data, 'visitors');
      final visits = _listFrom(responses[1].data, 'visits').map(_visitFrom);

      final byVisitor = <String, List<Visit>>{};
      for (final visit in visits) {
        byVisitor.putIfAbsent(visit.visitorId, () => []).add(visit);
      }
      return [for (final row in visitorRows) _visitorFrom(row, byVisitor)];
    });
  }

  @override
  Future<Visitor> fetchById(String id) {
    return _guard(() => _loadVisitor(id));
  }

  /// One visitor row plus that visitor's visits (two sequential GETs).
  Future<Visitor> _loadVisitor(String id) async {
    final response = await _dio.get<Object?>(_visitorPath(id));
    final visitor = _visitorRowFrom(response.data);
    return visitor.withVisits(await _visitsOf(id));
  }

  @override
  Future<Visitor> create(VisitorDraft draft, {required DateTime createdAt}) {
    return _guard(() async {
      final visitorResponse = await _dio.post<Object?>(
        ApiConfig.visitorsPath,
        data: draft.toVisitorCreateJson(createdAt),
      );
      final visitor = _visitorRowFrom(visitorResponse.data);
      try {
        final visit = await _postVisit(
          visitor.id,
          project: draft.project,
          purpose: draft.purpose,
          createdAt: createdAt,
        );
        return visitor.withVisit(visit);
      } catch (_) {
        // Do not leave a person without a visit behind; undo the first step.
        await _tryDelete(_visitorPath(visitor.id));
        rethrow;
      }
    });
  }

  @override
  Future<Visitor> update(
    String id,
    VisitorDraft draft, {
    String? activeVisitId,
  }) {
    return _guard(() async {
      await _dio.patch<Object?>(
        _visitorPath(id),
        data: draft.toVisitorUpdateJson(),
      );
      if (activeVisitId != null) {
        await _dio.patch<Object?>(
          _visitPath(activeVisitId),
          data: draft.toVisitUpdateJson(),
        );
      }
      return _loadVisitor(id);
    });
  }

  @override
  Future<void> delete(String id) {
    return _guard(() async {
      final visits = await _visitsOf(id);
      for (final visit in visits) {
        await _tryDelete(_visitPath(visit.id));
      }
      await _dio.delete<Object?>(_visitorPath(id));
    });
  }

  @override
  Future<Visit> startVisit(
    String visitorId, {
    required String project,
    required String purpose,
    required DateTime createdAt,
  }) {
    return _guard(
      () => _postVisit(
        visitorId,
        project: project,
        purpose: purpose,
        createdAt: createdAt,
      ),
    );
  }

  @override
  Future<Visit> checkIn(String visitId, DateTime at) {
    return _patchStatus(visitId, {
      'status': VisitorStatus.checkedIn.label,
      'check_in_time': toIso8601WithOffset(at),
    });
  }

  @override
  Future<Visit> checkOut(String visitId, DateTime at) {
    return _patchStatus(visitId, {
      'status': VisitorStatus.checkedOut.label,
      'check_out_time': toIso8601WithOffset(at),
    });
  }

  Future<Visit> _patchStatus(String visitId, Map<String, dynamic> body) {
    return _guard(() async {
      final response = await _dio.patch<Object?>(_visitPath(visitId), data: body);
      return _visitFrom(response.data);
    });
  }

  Future<Visit> _postVisit(
    String visitorId, {
    required String project,
    required String purpose,
    required DateTime createdAt,
  }) async {
    final response = await _dio.post<Object?>(
      ApiConfig.visitsPath,
      data: Visit.createJson(
        visitorId: visitorId,
        project: project,
        purpose: purpose,
        createdAt: createdAt,
      ),
    );
    return _visitFrom(response.data);
  }

  /// Visits of one visitor. The server-side `visitor_id` filter only narrows
  /// the download (mock APIs match it as a substring, so "1" also returns
  /// "10"); the exact comparison below is what decides.
  Future<List<Visit>> _visitsOf(String visitorId) async {
    final response = await _dio.get<Object?>(
      ApiConfig.visitsPath,
      queryParameters: {'visitor_id': visitorId},
    );
    return _listFrom(response.data, 'visits')
        .map(_visitFrom)
        .where((visit) => visit.visitorId == visitorId)
        .toList();
  }

  /// Deletes a record, treating "already gone" as success.
  Future<void> _tryDelete(String path) async {
    try {
      await _dio.delete<Object?>(path);
    } on DioException catch (error) {
      if (error.response?.statusCode != 404) rethrow;
    }
  }

  List<Object?> _listFrom(Object? data, String what) {
    if (data is List) return data;
    throw FormatException('Expected a JSON array of $what');
  }

  Visitor _visitorFrom(Object? row, Map<String, List<Visit>> byVisitor) {
    final visitor = _visitorRowFrom(row);
    return visitor.withVisits(byVisitor[visitor.id] ?? const []);
  }

  Visitor _visitorRowFrom(Object? data) {
    if (data is Map<String, dynamic>) return Visitor.fromJson(data);
    throw const FormatException('Expected a JSON object for a visitor');
  }

  Visit _visitFrom(Object? data) {
    if (data is Map<String, dynamic>) return Visit.fromJson(data);
    throw const FormatException('Expected a JSON object for a visit');
  }

  /// Converts every low-level failure into an [AppException].
  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw AppException.fromDio(error);
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException(
        AppErrorType.malformedResponse,
        'The server sent data the app could not read.',
      );
    } on TypeError {
      throw const AppException(
        AppErrorType.malformedResponse,
        'The server sent data the app could not read.',
      );
    }
  }
}
