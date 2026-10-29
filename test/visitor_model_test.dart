import 'package:flutter_test/flutter_test.dart';
import 'package:visitor_management/core/utils/date_time_utils.dart';
import 'package:visitor_management/features/visitors/domain/visitor.dart';

import 'support/test_data.dart';

void main() {
  group('Visitor JSON', () {
    // The sample record from the assignment brief.
    final sample = <String, dynamic>{
      'id': 'VIS001',
      'name': 'Rahul Sharma',
      'mobile': '9876543210',
      'email': 'rahul@example.com',
      'visitor_type': 'Customer',
      'project': 'Project A',
      'purpose': 'Site Visit',
      'status': 'Registered',
      'created_at': '2026-10-26T10:00:00+05:30',
      'check_in_time': null,
      'check_out_time': null,
    };

    test('parses the visitor identity and ignores old single-visit fields', () {
      final visitor = Visitor.fromJson(sample);
      expect(visitor.id, 'VIS001');
      expect(visitor.visitorType, VisitorType.customer);
      expect(visitor.visits, isEmpty);
      expect(
        visitor.createdAt.toUtc(),
        DateTime.utc(2026, 10, 26, 4, 30),
      );
    });

    test('accepts numeric ids and treats blank email as null', () {
      final visitor = Visitor.fromJson({...sample, 'id': 7, 'email': ''});
      expect(visitor.id, '7');
      expect(visitor.email, isNull);
    });

    test('toJson holds identity only and round-trips', () {
      final original = Visitor.fromJson(sample);
      final json = original.toJson();
      expect(json.containsKey('status'), isFalse);
      expect(json.containsKey('project'), isFalse);
      expect(Visitor.fromJson(json), original);
    });

    test('rejects malformed records instead of guessing', () {
      expect(
        () => Visitor.fromJson({...sample, 'created_at': 'yesterday'}),
        throwsFormatException,
      );
      expect(() => Visitor.fromJson({...sample, 'name': null}), throwsFormatException);
      expect(() => Visitor.fromJson({...sample, 'id': null}), throwsFormatException);
    });
  });

  group('Visit JSON', () {
    final sampleVisit = <String, dynamic>{
      'id': '5',
      'visitor_id': 'VIS001',
      'project': 'Project A',
      'purpose': 'Site Visit',
      'status': 'Checked In',
      'created_at': '2026-10-26T10:00:00+05:30',
      'check_in_time': '2026-10-26T10:30:00+05:30',
      'check_out_time': null,
    };

    test('parses a visit and converts times to local DateTime', () {
      final visit = Visit.fromJson(sampleVisit);
      expect(visit.visitorId, 'VIS001');
      expect(visit.status, VisitorStatus.checkedIn);
      expect(visit.isActive, isTrue);
      expect(visit.checkInTime!.toUtc(), DateTime.utc(2026, 10, 26, 5));
      expect(visit.checkOutTime, isNull);
    });

    test('round-trips through toJson', () {
      final visit = Visit.fromJson(sampleVisit);
      expect(Visit.fromJson(visit.toJson()), visit);
    });

    test('rejects an unknown status or a missing visitor_id', () {
      expect(
        () => Visit.fromJson({...sampleVisit, 'status': 'Teleported'}),
        throwsFormatException,
      );
      expect(
        () => Visit.fromJson({...sampleVisit, 'visitor_id': null}),
        throwsFormatException,
      );
    });

    test('create body is a new Registered session without check times', () {
      final body = Visit.createJson(
        visitorId: '1',
        project: 'Project B',
        purpose: 'Follow-up',
        createdAt: DateTime(2026, 10, 28, 10),
      );
      expect(body['status'], 'Registered');
      expect(body['visitor_id'], '1');
      expect(body['check_in_time'], isNull);
      expect(body['check_out_time'], isNull);
      expect(body.containsKey('id'), isFalse);
    });
  });

  group('Visitor and visits', () {
    test('current visit is the active one, else the latest finished one', () {
      final first = buildVisit(
        id: 'a',
        status: VisitorStatus.checkedOut,
        createdAt: DateTime(2026, 10, 27, 9),
      );
      final second = buildVisit(
        id: 'b',
        createdAt: DateTime(2026, 10, 28, 9),
      );

      final finishedOnly = buildVisitor(visits: [first]);
      expect(finishedOnly.hasActiveVisit, isFalse);
      expect(finishedOnly.currentVisit, first);
      expect(finishedOnly.status, VisitorStatus.checkedOut);

      final returning = buildVisitor(visits: [first, second]);
      expect(returning.activeVisit, second);
      expect(returning.currentVisit, second);
      expect(returning.status, VisitorStatus.registered);
      expect(returning.visitsNewestFirst.map((v) => v.id), ['b', 'a']);
    });

    test('withVisit adds a new visit and replaces a known one', () {
      final visitor = buildVisitor();
      final added = visitor.withVisit(buildVisit(id: 'new'));
      expect(added.visits, hasLength(2));

      final replaced = added.withVisit(
        buildVisit(id: 'new', status: VisitorStatus.checkedIn),
      );
      expect(replaced.visits, hasLength(2));
    });
  });

  group('status workflow', () {
    test('Registered can only check in', () {
      expect(VisitorStatus.registered.canCheckIn, isTrue);
      expect(VisitorStatus.registered.canCheckOut, isFalse);
    });

    test('Checked In can only check out', () {
      expect(VisitorStatus.checkedIn.canCheckIn, isFalse);
      expect(VisitorStatus.checkedIn.canCheckOut, isTrue);
    });

    test('Checked Out allows nothing', () {
      expect(VisitorStatus.checkedOut.canCheckIn, isFalse);
      expect(VisitorStatus.checkedOut.canCheckOut, isFalse);
    });
  });

  group('VisitorDraft', () {
    test('visitor create body is identity plus created_at only', () {
      final body = sampleDraft.toVisitorCreateJson(DateTime(2026, 10, 27, 10));
      expect(body['name'], 'Meera Iyer');
      expect(body.containsKey('created_at'), isTrue);
      expect(body.containsKey('status'), isFalse);
      expect(body.containsKey('project'), isFalse);
      expect(body.containsKey('id'), isFalse);
    });

    test('visitor update body is identity only', () {
      final body = sampleDraft.toVisitorUpdateJson();
      expect(body.containsKey('created_at'), isFalse);
      expect(body.containsKey('status'), isFalse);
      expect(body.containsKey('project'), isFalse);
    });

    test('visit update body never touches status or timestamps', () {
      final body = sampleDraft.toVisitUpdateJson();
      expect(body.keys.toSet(), {'project', 'purpose'});
    });
  });

  group('parseVisitorId', () {
    test('accepts plain ids', () {
      expect(parseVisitorId('42'), '42');
      expect(parseVisitorId('  VIS001 '), 'VIS001');
    });

    test('rejects content that is not a visitor id', () {
      expect(parseVisitorId(null), isNull);
      expect(parseVisitorId(''), isNull);
      expect(parseVisitorId('https://example.com/x'), isNull);
      expect(parseVisitorId('hello world'), isNull);
      expect(parseVisitorId('a' * 65), isNull);
    });
  });

  group('timestamps', () {
    test('ISO string carries an offset and keeps the instant', () {
      final now = DateTime(2026, 10, 27, 14, 5, 9);
      final text = toIso8601WithOffset(now);
      expect(
        RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}$')
            .hasMatch(text),
        isTrue,
      );
      expect(DateTime.parse(text).isAtSameMomentAs(now), isTrue);
    });

    test('same-day check uses the local calendar day', () {
      final morning = DateTime(2026, 10, 27, 0, 1);
      final night = DateTime(2026, 10, 27, 23, 59);
      expect(isSameLocalDay(morning, night), isTrue);
      expect(isSameLocalDay(night, DateTime(2026, 10, 28, 0, 1)), isFalse);
    });
  });
}
