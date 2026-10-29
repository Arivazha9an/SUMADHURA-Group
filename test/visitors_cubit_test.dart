import 'package:flutter_test/flutter_test.dart';
import 'package:visitor_management/features/visitors/domain/visitor.dart';
import 'package:visitor_management/features/visitors/presentation/cubit/visitors_cubit.dart';
import 'package:visitor_management/features/visitors/presentation/cubit/visitors_state.dart';

import 'support/fake_visitor_repository.dart';
import 'support/test_data.dart';

void main() {
  final fixedNow = DateTime(2026, 10, 27, 10, 30);

  late FakeVisitorRepository repository;
  late VisitorsCubit cubit;

  Future<void> start(List<Visitor> seed) async {
    repository = FakeVisitorRepository(seed);
    cubit = VisitorsCubit(repository, clock: () => fixedNow);
    await cubit.load();
  }

  tearDown(() => cubit.close());

  group('loading', () {
    test('loads visitors newest first', () async {
      await start([
        buildVisitor(id: 'old', createdAt: DateTime(2026, 10, 25)),
        buildVisitor(id: 'new', createdAt: DateTime(2026, 10, 27)),
      ]);
      expect(cubit.state.status, LoadStatus.success);
      expect(cubit.state.visitors.map((v) => v.id), ['new', 'old']);
    });

    test('reports failure without inventing data', () async {
      repository = FakeVisitorRepository()..failure = FakeVisitorRepository.offline;
      cubit = VisitorsCubit(repository);
      final result = await cubit.load();

      expect(result.isSuccess, isFalse);
      expect(cubit.state.status, LoadStatus.failure);
      expect(cubit.state.visitors, isEmpty);
      expect(cubit.state.errorMessage, isNotNull);
    });

    test('a failed refresh keeps the data already on screen', () async {
      await start([buildVisitor()]);
      repository.failure = FakeVisitorRepository.offline;

      final result = await cubit.load();

      expect(result.error, isNotNull);
      expect(cubit.state.visitors, hasLength(1));
      expect(cubit.state.status, LoadStatus.success);
    });
  });

  group('search', () {
    setUp(() async {
      await start([
        buildVisitor(id: '1', name: 'Rahul Sharma', mobile: '9876543210'),
        buildVisitor(id: '2', name: 'Meera Iyer', mobile: '9845012345'),
      ]);
    });

    test('matches name case-insensitively', () {
      cubit.setQuery('meera');
      expect(cubit.state.filtered.map((v) => v.id), ['2']);
    });

    test('matches part of the mobile number', () {
      cubit.setQuery('98765');
      expect(cubit.state.filtered.map((v) => v.id), ['1']);
    });

    test('empty query shows everyone, no match shows nobody', () {
      cubit.setQuery('');
      expect(cubit.state.filtered, hasLength(2));
      cubit.setQuery('zzz');
      expect(cubit.state.filtered, isEmpty);
    });
  });

  group('registration and editing', () {
    test('register stores the server-generated id and starts as Registered',
        () async {
      await start([]);
      final result = await cubit.register(sampleDraft);

      expect(result.isSuccess, isTrue);
      expect(result.data!.id, '100');
      expect(result.data!.status, VisitorStatus.registered);
      expect(cubit.state.byId('100'), isNotNull);
      expect(cubit.state.isSaving, isFalse);
    });

    test('failed registration adds nothing and reports the error', () async {
      await start([]);
      repository.failure = FakeVisitorRepository.offline;

      final result = await cubit.register(sampleDraft);

      expect(result.isSuccess, isFalse);
      expect(result.error, isNotNull);
      expect(cubit.state.visitors, isEmpty);
      expect(cubit.state.isSaving, isFalse);
    });

    test('a second submit while the first is running is ignored', () async {
      await start([]);
      final first = cubit.register(sampleDraft);
      final second = cubit.register(sampleDraft);

      expect((await second).isIgnored, isTrue);
      expect((await first).isSuccess, isTrue);
      expect(cubit.state.visitors, hasLength(1));
    });

    test('edit changes the details but not the status', () async {
      await start([buildVisitor(status: VisitorStatus.checkedIn)]);
      final result = await cubit.updateVisitor('1', sampleDraft);

      expect(result.isSuccess, isTrue);
      expect(cubit.state.byId('1')!.name, 'Meera Iyer');
      expect(cubit.state.byId('1')!.status, VisitorStatus.checkedIn);
    });
  });

  group('deletion', () {
    test('removes the record after the server confirms', () async {
      await start([buildVisitor()]);
      final result = await cubit.delete('1');

      expect(result.isSuccess, isTrue);
      expect(cubit.state.visitors, isEmpty);
      expect(repository.onServer('1'), isNull);
    });

    test('keeps the record when deletion fails', () async {
      await start([buildVisitor()]);
      repository.failure = FakeVisitorRepository.offline;

      final result = await cubit.delete('1');

      expect(result.isSuccess, isFalse);
      expect(cubit.state.visitors, hasLength(1));
      expect(cubit.state.busyIds, isEmpty);
    });
  });

  group('check-in / check-out rules', () {
    test('Registered → Checked In records the check-in time', () async {
      await start([buildVisitor()]);
      final result = await cubit.checkIn('1');

      expect(result.isSuccess, isTrue);
      final visitor = cubit.state.byId('1')!;
      expect(visitor.status, VisitorStatus.checkedIn);
      expect(visitor.checkInTime, fixedNow);
      expect(visitor.checkOutTime, isNull);
    });

    test('Checked In → Checked Out records the check-out time', () async {
      await start([buildVisitor()]);
      await cubit.checkIn('1');
      final result = await cubit.checkOut('1');

      expect(result.isSuccess, isTrue);
      final visitor = cubit.state.byId('1')!;
      expect(visitor.status, VisitorStatus.checkedOut);
      expect(visitor.checkOutTime, fixedNow);
    });

    test('cannot check out before checking in', () async {
      await start([buildVisitor()]);
      final result = await cubit.checkOut('1');

      expect(result.isSuccess, isFalse);
      expect(result.error, VisitorStatus.registered.checkOutBlockedReason);
      expect(repository.statusPatchCalls, 0);
      expect(cubit.state.byId('1')!.status, VisitorStatus.registered);
    });

    test('cannot check in twice', () async {
      await start([buildVisitor()]);
      await cubit.checkIn('1');
      final second = await cubit.checkIn('1');

      expect(second.isSuccess, isFalse);
      expect(second.error, VisitorStatus.checkedIn.checkInBlockedReason);
      expect(repository.statusPatchCalls, 1);
    });

    test('a completed visit cannot be checked in again', () async {
      await start([
        buildVisitor(
          status: VisitorStatus.checkedOut,
          checkInTime: DateTime(2026, 10, 27, 9),
          checkOutTime: DateTime(2026, 10, 27, 10),
        ),
      ]);
      final result = await cubit.checkIn('1');

      expect(result.isSuccess, isFalse);
      expect(repository.statusPatchCalls, 0);
    });

    test('rapid repeated taps send only one request', () async {
      await start([buildVisitor()]);

      final results = await Future.wait([
        cubit.checkIn('1'),
        cubit.checkIn('1'),
        cubit.checkIn('1'),
      ]);

      expect(results.where((r) => r.isSuccess), hasLength(1));
      expect(results.where((r) => r.isIgnored), hasLength(2));
      expect(repository.statusPatchCalls, 1);
      expect(cubit.state.busyIds, isEmpty);
    });

    test('uses the server state, not a stale local copy', () async {
      await start([buildVisitor()]);
      // Another device checks the visitor in after this device loaded the list.
      repository.changeOnServer(
        buildVisitor(
          status: VisitorStatus.checkedIn,
          checkInTime: DateTime(2026, 10, 27, 9, 50),
        ),
      );

      final result = await cubit.checkIn('1');

      expect(result.isSuccess, isFalse);
      expect(repository.statusPatchCalls, 0);
      // The local list is corrected from the server.
      expect(cubit.state.byId('1')!.status, VisitorStatus.checkedIn);
    });

    test('API failure is not reported as success', () async {
      await start([buildVisitor()]);
      repository.failure = FakeVisitorRepository.offline;

      final result = await cubit.checkIn('1');

      expect(result.isSuccess, isFalse);
      expect(cubit.state.byId('1')!.status, VisitorStatus.registered);
      expect(cubit.state.busyIds, isEmpty);
    });
  });

  group('lookup (QR scan)', () {
    test('returns the visitor and merges it into state', () async {
      await start([]);
      repository.changeOnServer(buildVisitor(id: '55'));

      final result = await cubit.lookup('55');

      expect(result.isSuccess, isTrue);
      expect(cubit.state.byId('55'), isNotNull);
    });

    test('unknown visitor gives a clear message', () async {
      await start([]);
      final result = await cubit.lookup('999');

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('999'));
    });
  });
}
