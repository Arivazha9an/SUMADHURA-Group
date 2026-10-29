import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visitor_management/core/error/app_exception.dart';
import 'package:visitor_management/features/visitors/data/visitor_repository.dart';
import 'package:visitor_management/features/visitors/domain/visitor.dart';

import 'support/test_data.dart';

/// A tiny in-memory REST server behind Dio's HttpClientAdapter, shaped like a
/// MockAPI project with two resources (visitors, visits). It lets the real
/// [ApiVisitorRepository] run: URLs, JSON bodies and joins are exercised
/// without any network.
class _FakeServer implements HttpClientAdapter {
  final Map<String, Map<String, Map<String, dynamic>>> tables = {
    'visitors': {},
    'visits': {},
  };
  final List<String> requests = [];
  int _nextId = 100;

  /// When true, POST /visits answers 500.
  bool failVisitPost = false;

  /// When set, GET /visits answers with this raw JSON text.
  String? rawVisitsResponse;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final segments =
        options.uri.pathSegments.where((s) => s.isNotEmpty).toList();
    requests.add('${options.method} ${options.uri.path}'
        '${options.uri.hasQuery ? '?${options.uri.query}' : ''}');
    final table = tables[segments.first]!;
    final id = segments.length > 1 ? segments[1] : null;

    switch (options.method) {
      case 'GET':
        if (id == null) {
          if (segments.first == 'visits' && rawVisitsResponse != null) {
            return _raw(rawVisitsResponse!, 200);
          }
          var rows = table.values.toList();
          // Mock APIs filter by substring: "1" also matches "10".
          options.uri.queryParameters.forEach((key, value) {
            rows = rows
                .where((r) => '${r[key]}'.toLowerCase().contains(value.toLowerCase()))
                .toList();
          });
          return _json(rows, 200);
        }
        return table.containsKey(id) ? _json(table[id], 200) : _json({}, 404);
      case 'POST':
        if (segments.first == 'visits' && failVisitPost) {
          return _json({'error': 'boom'}, 500);
        }
        final row = {...(options.data as Map<String, dynamic>), 'id': '${_nextId++}'};
        table[row['id'] as String] = row;
        return _json(row, 201);
      case 'PATCH':
        if (!table.containsKey(id)) return _json({}, 404);
        table[id!] = {...table[id]!, ...(options.data as Map<String, dynamic>)};
        return _json(table[id], 200);
      case 'DELETE':
        if (!table.containsKey(id)) return _json({}, 404);
        return _json(table.remove(id), 200);
    }
    return _json({}, 405);
  }

  ResponseBody _json(Object? body, int status) =>
      _raw(jsonEncode(body), status);

  ResponseBody _raw(String text, int status) => ResponseBody.fromString(
        text,
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

void main() {
  late _FakeServer server;
  late ApiVisitorRepository repository;

  Map<String, dynamic> visitorRow(String id) => {
        'id': id,
        'name': 'Person $id',
        'mobile': '9876543210',
        'email': null,
        'visitor_type': 'Customer',
        'created_at': '2026-10-27T09:00:00+05:30',
      };

  Map<String, dynamic> visitRow(String id, String visitorId,
          {String status = 'Registered'}) =>
      {
        'id': id,
        'visitor_id': visitorId,
        'project': 'Project A',
        'purpose': 'Site Visit',
        'status': status,
        'created_at': '2026-10-27T09:00:00+05:30',
        'check_in_time': null,
        'check_out_time': null,
      };

  setUp(() {
    server = _FakeServer();
    repository = ApiVisitorRepository(
      Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = server,
    );
  });

  test('create posts the visitor, then a first Registered visit', () async {
    final visitor = await repository.create(
      sampleDraft,
      createdAt: DateTime(2026, 10, 28, 10),
    );

    expect(server.tables['visitors'], hasLength(1));
    expect(server.tables['visits'], hasLength(1));
    final visit = server.tables['visits']!.values.single;
    expect(visit['visitor_id'], visitor.id);
    expect(visit['status'], 'Registered');
    expect(server.tables['visitors']!.values.single.containsKey('status'), isFalse);
    expect(visitor.visits.single.project, 'Project B');
  });

  test('a failed first visit rolls the new visitor back', () async {
    server.failVisitPost = true;

    await expectLater(
      repository.create(sampleDraft, createdAt: DateTime(2026, 10, 28, 10)),
      throwsA(isA<AppException>()),
    );

    expect(server.tables['visitors'], isEmpty);
  });

  test('fetchAll joins visits to their visitor by visitor_id', () async {
    server.tables['visitors']!['1'] = visitorRow('1');
    server.tables['visitors']!['2'] = visitorRow('2');
    server.tables['visits']!['a'] = visitRow('a', '1', status: 'Checked Out');
    server.tables['visits']!['b'] = visitRow('b', '1');
    server.tables['visits']!['c'] = visitRow('c', '2');
    server.tables['visits']!['orphan'] = visitRow('orphan', '999');

    final visitors = await repository.fetchAll();

    expect(visitors.firstWhere((v) => v.id == '1').visits, hasLength(2));
    expect(visitors.firstWhere((v) => v.id == '2').visits, hasLength(1));
  });

  test('fetchById ignores visits of a visitor whose id merely contains it',
      () async {
    server.tables['visitors']!['1'] = visitorRow('1');
    server.tables['visitors']!['10'] = visitorRow('10');
    server.tables['visits']!['a'] = visitRow('a', '1');
    server.tables['visits']!['b'] = visitRow('b', '10');

    final visitor = await repository.fetchById('1');

    expect(visitor.visits.map((v) => v.id), ['a']);
  });

  test('startVisit adds a second visit and leaves the first untouched',
      () async {
    server.tables['visitors']!['1'] = visitorRow('1');
    server.tables['visits']!['a'] = visitRow('a', '1', status: 'Checked Out');
    final before = Map<String, dynamic>.from(server.tables['visits']!['a']!);

    final visit = await repository.startVisit(
      '1',
      project: 'Project C',
      purpose: 'Return',
      createdAt: DateTime(2026, 10, 28, 9),
    );

    expect(visit.status, VisitorStatus.registered);
    expect(server.tables['visits'], hasLength(2));
    expect(server.tables['visits']!['a'], before);
  });

  test('check-in and check-out PATCH only the visit record', () async {
    server.tables['visitors']!['1'] = visitorRow('1');
    server.tables['visits']!['a'] = visitRow('a', '1');
    final visitorBefore = Map<String, dynamic>.from(server.tables['visitors']!['1']!);

    final checkedIn = await repository.checkIn('a', DateTime(2026, 10, 28, 9, 30));
    final checkedOut = await repository.checkOut('a', DateTime(2026, 10, 28, 11));

    expect(checkedIn.status, VisitorStatus.checkedIn);
    expect(checkedOut.status, VisitorStatus.checkedOut);
    expect(checkedOut.checkInTime, isNotNull);
    expect(checkedOut.checkOutTime, isNotNull);
    expect(server.requests.where((r) => r.startsWith('PATCH /visitors')), isEmpty);
    expect(server.tables['visitors']!['1'], visitorBefore);
  });

  test('update edits the active visit only when its id is given', () async {
    server.tables['visitors']!['1'] = visitorRow('1');
    server.tables['visits']!['a'] = visitRow('a', '1', status: 'Checked Out');
    server.tables['visits']!['b'] = visitRow('b', '1');

    await repository.update('1', sampleDraft, activeVisitId: 'b');

    expect(server.tables['visits']!['b']!['project'], 'Project B');
    expect(server.tables['visits']!['a']!['project'], 'Project A');
    expect(server.tables['visitors']!['1']!['name'], 'Meera Iyer');

    server.requests.clear();
    await repository.update('1', sampleDraft);
    expect(server.requests.where((r) => r.startsWith('PATCH /visits')), isEmpty);
  });

  test('delete removes the visits and then the visitor', () async {
    server.tables['visitors']!['1'] = visitorRow('1');
    server.tables['visits']!['a'] = visitRow('a', '1');
    server.tables['visits']!['b'] = visitRow('b', '1');
    server.tables['visits']!['keep'] = visitRow('keep', '2');

    await repository.delete('1');

    expect(server.tables['visitors'], isEmpty);
    expect(server.tables['visits']!.keys, ['keep']);
  });

  test('unreadable visits data becomes a malformed-response error', () async {
    server.rawVisitsResponse = '{"not": "a list"}';

    await expectLater(
      repository.fetchAll(),
      throwsA(
        isA<AppException>().having(
          (e) => e.type,
          'type',
          AppErrorType.malformedResponse,
        ),
      ),
    );
  });

  test('an unknown visitor is reported as not found', () async {
    await expectLater(
      repository.fetchById('missing'),
      throwsA(
        isA<AppException>().having((e) => e.type, 'type', AppErrorType.notFound),
      ),
    );
  });
}
