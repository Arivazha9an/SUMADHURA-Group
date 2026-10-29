import 'package:flutter_test/flutter_test.dart';
import 'package:visitor_management/features/dashboard/domain/dashboard_stats.dart';
import 'package:visitor_management/features/visitors/domain/visitor.dart';
import 'package:visitor_management/features/visitors/presentation/cubit/visitors_cubit.dart';

import 'support/fake_visitor_repository.dart';
import 'support/test_data.dart';

/// Repeat visits: one person, many visit sessions. Finished sessions are
/// history and must never be changed, reopened or duplicated.
void main() {
  final oct27 = DateTime(2026, 10, 27, 9);
  final oct28 = DateTime(2026, 10, 28, 9);
  final oct30 = DateTime(2026, 10, 30, 9);

  late FakeVisitorRepository repository;
  late VisitorsCubit cubit;
  late DateTime clock;

  Future<void> start(List<Visitor> seed, {required DateTime now}) async {
    clock = now;
    repository = FakeVisitorRepository(seed);
    cubit = VisitorsCubit(repository, clock: () => clock);
    addTearDown(cubit.close);
    await cubit.load();
  }

  /// A person whose only visit (on Oct 27) is finished.
  Visitor finishedVisitor() => buildVisitor(
        status: VisitorStatus.checkedOut,
        createdAt: oct27,
        checkInTime: DateTime(2026, 10, 27, 9, 5),
        checkOutTime: DateTime(2026, 10, 27, 10),
      );

  group('first visit', () {
    test('registering creates the person and one Registered visit', () async {
      await start([], now: oct27);
      final result = await cubit.register(sampleDraft);

      final visitor = result.data!;
      expect(visitor.visits, hasLength(1));
      expect(visitor.activeVisit!.status, VisitorStatus.registered);
      expect(visitor.activeVisit!.visitorId, visitor.id);
      expect(repository.visitsOnServer(visitor.id), hasLength(1));
    });
  });

  group('returning visitor', () {
    test('a new session is created and the old one is untouched', () async {
      await start([finishedVisitor()], now: oct28);
      final before = cubit.state.byId('1')!.visits.single;

      final result = await cubit.startNewVisit(
        '1',
        project: 'Project B',
        purpose: 'Agreement signing',
      );

      expect(result.isSuccess, isTrue);
      final visitor = cubit.state.byId('1')!;
      expect(visitor.visits, hasLength(2));
      expect(visitor.visits.where((v) => v.id == before.id).single, before);
      expect(visitor.activeVisit!.status, VisitorStatus.registered);
      expect(visitor.activeVisit!.createdAt, oct28);
      expect(visitor.activeVisit!.project, 'Project B');
      expect(visitor.status, VisitorStatus.registered);
      expect(repository.visitsOnServer('1'), hasLength(2));
    });

    test('the new session can be checked in and out', () async {
      await start([finishedVisitor()], now: oct28);
      await cubit.startNewVisit('1', project: 'Project A', purpose: 'Return');

      clock = DateTime(2026, 10, 28, 9, 30);
      expect((await cubit.checkIn('1')).isSuccess, isTrue);
      clock = DateTime(2026, 10, 28, 11);
      expect((await cubit.checkOut('1')).isSuccess, isTrue);

      final visitor = cubit.state.byId('1')!;
      expect(visitor.status, VisitorStatus.checkedOut);
      expect(visitor.visits, hasLength(2));
    });

    test('visits A, B and C on different days keep their own history',
        () async {
      await start([], now: oct27);
      final registered = await cubit.register(sampleDraft);
      final id = registered.data!.id;

      // Visit A on Oct 27.
      clock = DateTime(2026, 10, 27, 9, 10);
      await cubit.checkIn(id);
      clock = DateTime(2026, 10, 27, 10);
      await cubit.checkOut(id);

      // Visit B on Oct 28.
      clock = oct28;
      await cubit.startNewVisit(id, project: 'Project A', purpose: 'B');
      clock = DateTime(2026, 10, 28, 9, 15);
      await cubit.checkIn(id);
      clock = DateTime(2026, 10, 28, 12);
      await cubit.checkOut(id);

      // Visit C on Oct 30 only starts.
      clock = oct30;
      await cubit.startNewVisit(id, project: 'Project C', purpose: 'C');

      final visits = cubit.state.byId(id)!.visitsNewestFirst;
      expect(visits, hasLength(3));
      final c = visits[0];
      final b = visits[1];
      final a = visits[2];

      expect(a.status, VisitorStatus.checkedOut);
      expect(a.checkInTime, DateTime(2026, 10, 27, 9, 10));
      expect(a.checkOutTime, DateTime(2026, 10, 27, 10));
      expect(b.status, VisitorStatus.checkedOut);
      expect(b.checkInTime, DateTime(2026, 10, 28, 9, 15));
      expect(b.checkOutTime, DateTime(2026, 10, 28, 12));
      expect(c.status, VisitorStatus.registered);
      expect(c.checkInTime, isNull);
      expect({a.id, b.id, c.id}, hasLength(3));
    });
  });

  group('no duplicate or invalid sessions', () {
    for (final status in [VisitorStatus.registered, VisitorStatus.checkedIn]) {
      test('cannot start a visit while one is ${status.label}', () async {
        await start([
          buildVisitor(
            status: status,
            checkInTime:
                status == VisitorStatus.checkedIn ? oct27 : null,
          ),
        ], now: oct28);

        final result = await cubit.startNewVisit(
          '1',
          project: 'Project A',
          purpose: 'Again',
        );

        expect(result.isSuccess, isFalse);
        expect(result.error, contains('already has an active visit'));
        expect(repository.visitCreateCalls, 0);
        expect(cubit.state.byId('1')!.visits, hasLength(1));
      });
    }

    test('rapid repeated taps create only one session', () async {
      await start([finishedVisitor()], now: oct28);

      final results = await Future.wait([
        for (var i = 0; i < 3; i++)
          cubit.startNewVisit('1', project: 'Project A', purpose: 'Tap'),
      ]);

      expect(results.where((r) => r.isSuccess), hasLength(1));
      expect(results.where((r) => r.isIgnored), hasLength(2));
      expect(repository.visitCreateCalls, 1);
      expect(cubit.state.byId('1')!.visits, hasLength(2));
      expect(cubit.state.busyIds, isEmpty);
    });

    test('a visit started on another device is detected, not duplicated',
        () async {
      await start([finishedVisitor()], now: oct28);
      // Another device starts a visit after this device loaded its list.
      repository.addVisitOnServer(
        buildVisit(id: 'other', createdAt: oct28),
      );

      final result = await cubit.startNewVisit(
        '1',
        project: 'Project A',
        purpose: 'Mine',
      );

      expect(result.isSuccess, isFalse);
      expect(repository.visitCreateCalls, 0);
      // The screen now shows the visit that already exists.
      expect(cubit.state.byId('1')!.activeVisit!.id, 'other');
    });

    test('repeated scanner lookups never create a session', () async {
      await start([finishedVisitor()], now: oct28);

      await Future.wait([
        cubit.lookup('1'),
        cubit.lookup('1'),
        cubit.lookup('1'),
      ]);

      expect(repository.visitCreateCalls, 0);
      expect(cubit.state.byId('1')!.visits, hasLength(1));
    });

    test('a finished visit is never reopened by check-in or check-out',
        () async {
      await start([finishedVisitor()], now: oct28);
      final before = cubit.state.byId('1')!.visits.single;

      final checkIn = await cubit.checkIn('1');
      final checkOut = await cubit.checkOut('1');

      expect(checkIn.error, VisitorsCubit.noActiveVisitMessage);
      expect(checkOut.error, VisitorsCubit.noActiveVisitMessage);
      expect(repository.statusPatchCalls, 0);
      expect(cubit.state.byId('1')!.visits.single, before);
    });

    test('cannot check out a new session before it is checked in', () async {
      await start([finishedVisitor()], now: oct28);
      await cubit.startNewVisit('1', project: 'Project A', purpose: 'Return');

      final result = await cubit.checkOut('1');

      expect(result.error, VisitorStatus.registered.checkOutBlockedReason);
      expect(repository.statusPatchCalls, 0);
    });

    test('an unknown visitor cannot get a visit', () async {
      await start([], now: oct28);
      final result = await cubit.startNewVisit(
        'nope',
        project: 'Project A',
        purpose: 'x',
      );
      expect(result.isSuccess, isFalse);
      expect(repository.visitCreateCalls, 0);
    });
  });

  group('API failures and synchronization', () {
    test('a failed start is not reported as success and changes nothing',
        () async {
      await start([finishedVisitor()], now: oct28);
      repository.failure = FakeVisitorRepository.offline;

      final result = await cubit.startNewVisit(
        '1',
        project: 'Project A',
        purpose: 'Return',
      );

      expect(result.isSuccess, isFalse);
      expect(cubit.state.byId('1')!.visits, hasLength(1));
      expect(cubit.state.busyIds, isEmpty);
    });

    test('starting a visit moves the visitor to the top of the list',
        () async {
      await start([
        buildVisitor(id: '1', name: 'Old', status: VisitorStatus.checkedOut,
            createdAt: oct27, checkOutTime: oct27),
        buildVisitor(id: '2', name: 'Newer', createdAt: DateTime(2026, 10, 27, 12)),
      ], now: oct28);
      expect(cubit.state.visitors.first.id, '2');

      await cubit.startNewVisit('1', project: 'Project A', purpose: 'Return');

      expect(cubit.state.visitors.first.id, '1');
    });

    test('editing the person never changes a finished visit', () async {
      await start([finishedVisitor()], now: oct28);
      final before = cubit.state.byId('1')!.visits.single;

      final result = await cubit.updateVisitor('1', sampleDraft);

      expect(result.isSuccess, isTrue);
      final visitor = cubit.state.byId('1')!;
      expect(visitor.name, 'Meera Iyer');
      expect(visitor.visits.single, before);
    });

    test('editing changes project and purpose of the active visit only',
        () async {
      await start([finishedVisitor()], now: oct28);
      await cubit.startNewVisit('1', project: 'Project A', purpose: 'Return');
      final finished = cubit.state.byId('1')!.visitsNewestFirst.last;

      await cubit.updateVisitor('1', sampleDraft);

      final visitor = cubit.state.byId('1')!;
      expect(visitor.activeVisit!.project, 'Project B');
      expect(visitor.activeVisit!.purpose, 'Agreement signing');
      expect(visitor.visitsNewestFirst.last, finished);
    });

    test('deleting the person removes all of their visits', () async {
      await start([finishedVisitor()], now: oct28);
      await cubit.startNewVisit('1', project: 'Project A', purpose: 'Return');

      final result = await cubit.delete('1');

      expect(result.isSuccess, isTrue);
      expect(repository.visitsOnServer('1'), isEmpty);
      expect(repository.onServer('1'), isNull);
    });

    test('data survives a restart: a new cubit reads the same visits',
        () async {
      await start([finishedVisitor()], now: oct28);
      await cubit.startNewVisit('1', project: 'Project A', purpose: 'Return');

      final restarted = VisitorsCubit(repository, clock: () => clock);
      addTearDown(restarted.close);
      await restarted.load();

      expect(restarted.state.byId('1')!.visits, hasLength(2));
    });
  });

  group('dashboard with visit sessions', () {
    final now = DateTime(2026, 10, 28, 15);

    test('a returning visitor counts today, once, even with two visits', () {
      final visitor = buildVisitor(
        createdAt: oct27,
        visits: [
          buildVisit(
            id: 'a',
            status: VisitorStatus.checkedOut,
            createdAt: DateTime(2026, 10, 27, 9),
            checkInTime: DateTime(2026, 10, 27, 9, 5),
            checkOutTime: DateTime(2026, 10, 27, 10),
          ),
          buildVisit(
            id: 'b',
            status: VisitorStatus.checkedOut,
            createdAt: DateTime(2026, 10, 28, 8),
            checkInTime: DateTime(2026, 10, 28, 8, 5),
            checkOutTime: DateTime(2026, 10, 28, 9),
          ),
          buildVisit(id: 'c', createdAt: DateTime(2026, 10, 28, 13)),
        ],
      );

      final stats = DashboardStats.fromVisitors([visitor], now);

      expect(stats.registeredToday, 1);
      expect(stats.checkedOutToday, 1, reason: "yesterday's check-out is not today's");
      expect(stats.currentlyCheckedIn, 0);
      expect(stats.recentActivity, hasLength(3));
    });

    test('a visit checked in yesterday and still inside is currently in', () {
      final visitor = buildVisitor(
        status: VisitorStatus.checkedIn,
        createdAt: oct27,
        checkInTime: DateTime(2026, 10, 27, 9, 5),
      );

      final stats = DashboardStats.fromVisitors([visitor], now);

      expect(stats.currentlyCheckedIn, 1);
      expect(stats.registeredToday, 0);
      expect(stats.checkedOutToday, 0);
    });

    test('a person registered earlier but with no visit today is not counted',
        () {
      final stats = DashboardStats.fromVisitors([finishedVisitor()], now);
      expect(stats.registeredToday, 0);
    });
  });
}
