import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visitor_management/app/app.dart';
import 'package:visitor_management/features/visitors/domain/visitor.dart';
import 'package:visitor_management/features/visitors/presentation/widgets/status_chip.dart';

import 'support/fake_visitor_repository.dart';
import 'support/test_data.dart';

void main() {
  testWidgets('status chip shows the status label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StatusChip(status: VisitorStatus.checkedIn)),
      ),
    );
    expect(find.text('Checked In'), findsOneWidget);
  });

  testWidgets('dashboard shows stats from repository data', (tester) async {
    final today = DateTime.now();
    final repository = FakeVisitorRepository([
      buildVisitor(id: '1', createdAt: today),
      buildVisitor(
        id: '2',
        name: 'Meera Iyer',
        createdAt: today,
        status: VisitorStatus.checkedIn,
        checkInTime: today,
      ),
    ]);

    await tester.pumpWidget(VisitorApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Total Visitors Today'), findsOneWidget);
    expect(find.text('Currently Checked In'), findsOneWidget);
    expect(find.text('Checked Out Today'), findsOneWidget);
    expect(find.text('Register visitor'), findsOneWidget);
    expect(find.text('Scan QR'), findsOneWidget);
    // Two registered today, one inside, none checked out.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('shows an error with retry when the API is unreachable',
      (tester) async {
    final repository = FakeVisitorRepository()
      ..failure = FakeVisitorRepository.offline;

    await tester.pumpWidget(VisitorApp(repository: repository));
    await tester.pumpAndSettle();

    // The fake fails with a network error, so the view says so.
    expect(find.text('No connection'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    repository.failure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('No connection'), findsNothing);
    expect(find.text('Total Visitors Today'), findsOneWidget);
  });

  testWidgets('status filter chips narrow the visitor list', (tester) async {
    final today = DateTime.now();
    final repository = FakeVisitorRepository([
      buildVisitor(id: '1', name: 'Rahul Sharma', createdAt: today),
      buildVisitor(
        id: '2',
        name: 'Meera Iyer',
        createdAt: today,
        status: VisitorStatus.checkedIn,
        checkInTime: today,
      ),
    ]);

    await tester.pumpWidget(VisitorApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Visitors'));
    await tester.pumpAndSettle();

    expect(find.text('Rahul Sharma'), findsOneWidget);
    expect(find.text('Meera Iyer'), findsOneWidget);
    expect(find.text('All · 2'), findsOneWidget);

    await tester.tap(find.text('Checked In · 1'));
    await tester.pumpAndSettle();

    expect(find.text('Rahul Sharma'), findsNothing);
    expect(find.text('Meera Iyer'), findsOneWidget);

    // A filter with no results explains itself and offers a way out.
    await tester.tap(find.text('Checked Out · 0'));
    await tester.pumpAndSettle();
    expect(find.text('No matching visitors'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Rahul Sharma'), findsOneWidget);
  });

  testWidgets('details screen offers share and save for the QR pass',
      (tester) async {
    // Tall viewport so the whole details list is built without scrolling.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repository = FakeVisitorRepository([
      buildVisitor(id: '1', name: 'Rahul Sharma', createdAt: DateTime.now()),
    ]);

    await tester.pumpWidget(VisitorApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Visitors'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rahul Sharma'));
    await tester.pumpAndSettle();

    expect(find.text('Visitor details'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    // Registered visitors are offered check-in only.
    expect(find.text('Check in'), findsOneWidget);
    expect(find.text('Check out'), findsNothing);
  });

  testWidgets('project filter menu narrows the visitor list', (tester) async {
    final today = DateTime.now();
    final repository = FakeVisitorRepository([
      buildVisitor(
        id: '1',
        name: 'Rahul Sharma',
        project: 'Project A',
        createdAt: today,
      ),
      buildVisitor(
        id: '2',
        name: 'Meera Iyer',
        project: 'Project B',
        createdAt: today,
      ),
    ]);

    await tester.pumpWidget(VisitorApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Visitors'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Project'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Project B').last);
    await tester.pumpAndSettle();

    expect(find.text('Rahul Sharma'), findsNothing);
    expect(find.text('Meera Iyer'), findsOneWidget);
  });

  testWidgets('registration form shows validation messages', (tester) async {
    await tester.pumpWidget(VisitorApp(repository: FakeVisitorRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Register visitor'));
    await tester.pumpAndSettle();
    // Button on the form screen (the app bar title is the other match).
    final submit = find.widgetWithText(FilledButton, 'Register visitor');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Visitor name is required'), findsOneWidget);
    expect(find.text('Mobile number is required'), findsOneWidget);
    expect(find.text('Purpose of visit is required'), findsOneWidget);
    expect(find.text('Select a visitor type'), findsOneWidget);
    expect(find.text('Select a project'), findsOneWidget);
  });

  testWidgets('returning visitor: history, then a new visit can be started',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repository = FakeVisitorRepository([
      buildVisitor(
        id: '1',
        name: 'Rahul Sharma',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        status: VisitorStatus.checkedOut,
        checkInTime: DateTime.now().subtract(const Duration(days: 1)),
        checkOutTime: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ]);

    await tester.pumpWidget(VisitorApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Visitors'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rahul Sharma'));
    await tester.pumpAndSettle();

    // Finished visit: only "Start new visit" is offered, history has one entry.
    expect(find.text('Start new visit'), findsOneWidget);
    expect(find.text('Check in'), findsNothing);
    expect(find.text('Visit history (1)'), findsOneWidget);

    await tester.tap(find.text('Start new visit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start visit'));
    await tester.pumpAndSettle();

    expect(find.text('Visit history (2)'), findsOneWidget);
    expect(find.text('Check in'), findsOneWidget);
    expect(find.text('Start new visit'), findsNothing);
    expect(repository.visitsOnServer('1'), hasLength(2));
  });
}
