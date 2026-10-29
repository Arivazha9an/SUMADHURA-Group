import 'package:flutter_test/flutter_test.dart';
import 'package:visitor_management/features/visitors/domain/visitor.dart';
import 'package:visitor_management/features/visitors/presentation/cubit/visitors_cubit.dart';

import 'support/fake_visitor_repository.dart';
import 'support/test_data.dart';

/// Every (status × action) combination, checked at both layers that enforce
/// the rules: the domain enum and the cubit that the details screen, the list
/// and the QR flow all call.
void main() {
  final checkedInAt = DateTime(2026, 10, 27, 9);
  final now = DateTime(2026, 10, 27, 10);

  Visitor visitorIn(VisitorStatus status) => buildVisitor(
        status: status,
        checkInTime: status == VisitorStatus.registered ? null : checkedInAt,
        checkOutTime: status == VisitorStatus.checkedOut ? checkedInAt : null,
      );

  const allowedCheckIn = {VisitorStatus.registered};
  const allowedCheckOut = {VisitorStatus.checkedIn};

  group('domain rules', () {
    for (final status in VisitorStatus.values) {
      test('${status.label}: check-in/out permissions', () {
        expect(status.canCheckIn, allowedCheckIn.contains(status));
        expect(status.canCheckOut, allowedCheckOut.contains(status));
        // A blocked action always explains why; an allowed one never does.
        expect(status.checkInBlockedReason == null, status.canCheckIn);
        expect(status.checkOutBlockedReason == null, status.canCheckOut);
      });
    }

    test('only one forward action exists from each state', () {
      expect(VisitorStatus.registered.canCheckOut, isFalse);
      expect(VisitorStatus.checkedIn.canCheckIn, isFalse);
      expect(VisitorStatus.checkedOut.canCheckIn, isFalse);
      expect(VisitorStatus.checkedOut.canCheckOut, isFalse);
    });
  });

  group('cubit enforces the same rules', () {
    for (final status in VisitorStatus.values) {
      test('check-in from ${status.label}', () async {
        final repository = FakeVisitorRepository([visitorIn(status)]);
        final cubit = VisitorsCubit(repository, clock: () => now);
        addTearDown(cubit.close);
        await cubit.load();

        final result = await cubit.checkIn('1');

        expect(result.isSuccess, allowedCheckIn.contains(status));
        expect(
          repository.statusPatchCalls,
          allowedCheckIn.contains(status) ? 1 : 0,
          reason: 'blocked actions must never reach the API',
        );
        if (!result.isSuccess) {
          // A finished visit has no active visit left to check in.
          expect(
            result.error,
            status == VisitorStatus.checkedOut
                ? VisitorsCubit.noActiveVisitMessage
                : status.checkInBlockedReason,
          );
          expect(cubit.state.byId('1')!.status, status);
        }
      });

      test('check-out from ${status.label}', () async {
        final repository = FakeVisitorRepository([visitorIn(status)]);
        final cubit = VisitorsCubit(repository, clock: () => now);
        addTearDown(cubit.close);
        await cubit.load();

        final result = await cubit.checkOut('1');

        expect(result.isSuccess, allowedCheckOut.contains(status));
        expect(
          repository.statusPatchCalls,
          allowedCheckOut.contains(status) ? 1 : 0,
        );
        if (!result.isSuccess) {
          expect(
            result.error,
            status == VisitorStatus.checkedOut
                ? VisitorsCubit.noActiveVisitMessage
                : status.checkOutBlockedReason,
          );
        }
      });
    }

    test('a scanned visitor goes through the very same check-in path',
        () async {
      // QR flow: lookup() then checkIn(); manual flow: checkIn() from the
      // list. Both must end in the same state with the same timestamp.
      final repository = FakeVisitorRepository([buildVisitor()]);
      final scan = VisitorsCubit(repository, clock: () => now);
      addTearDown(scan.close);

      final found = await scan.lookup('1');
      final checkedIn = await scan.checkIn(found.data!.id);

      expect(checkedIn.isSuccess, isTrue);
      expect(checkedIn.data!.status, VisitorStatus.checkedIn);
      expect(checkedIn.data!.checkInTime, now);

      final again = await scan.checkIn('1');
      expect(again.isSuccess, isFalse);
      expect(repository.statusPatchCalls, 1);
    });

    test('full lifecycle Registered → Checked In → Checked Out → blocked',
        () async {
      final repository = FakeVisitorRepository([buildVisitor()]);
      final cubit = VisitorsCubit(repository, clock: () => now);
      addTearDown(cubit.close);
      await cubit.load();

      expect((await cubit.checkIn('1')).isSuccess, isTrue);
      expect((await cubit.checkOut('1')).isSuccess, isTrue);
      expect((await cubit.checkIn('1')).isSuccess, isFalse);
      expect((await cubit.checkOut('1')).isSuccess, isFalse);

      final done = cubit.state.byId('1')!;
      expect(done.status, VisitorStatus.checkedOut);
      expect(done.checkInTime, isNotNull);
      expect(done.checkOutTime, isNotNull);
      expect(repository.statusPatchCalls, 2);
    });
  });
}
