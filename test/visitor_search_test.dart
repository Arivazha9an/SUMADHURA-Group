import 'package:flutter_test/flutter_test.dart';
import 'package:visitor_management/features/visitors/domain/visitor.dart';
import 'package:visitor_management/features/visitors/presentation/cubit/visitors_cubit.dart';
import 'package:visitor_management/features/visitors/presentation/cubit/visitors_state.dart';

import 'support/fake_visitor_repository.dart';
import 'support/test_data.dart';

void main() {
  final visitors = [
    buildVisitor(id: '1', name: 'Rahul Sharma', mobile: '9876543210'),
    buildVisitor(id: '12', name: 'Meera Iyer', mobile: '9845012345'),
    buildVisitor(
      id: 'VIS-7',
      name: 'Arun Kumar',
      mobile: '9790011223',
      status: VisitorStatus.checkedIn,
    ),
    buildVisitor(
      id: '40',
      name: 'Priya Nair',
      mobile: '9003456789',
      status: VisitorStatus.checkedOut,
    ),
  ];

  List<String> ids(List<Visitor> list) => list.map((v) => v.id).toList();

  group('searchVisitors', () {
    test('empty query returns everyone', () {
      expect(searchVisitors(visitors), hasLength(4));
      expect(searchVisitors(visitors, query: '   '), hasLength(4));
    });

    test('name: case-insensitive and partial', () {
      expect(ids(searchVisitors(visitors, query: 'MEERA')), ['12']);
      expect(ids(searchVisitors(visitors, query: 'kum')), ['VIS-7']);
      expect(ids(searchVisitors(visitors, query: ' sharma ')), ['1']);
    });

    test('mobile: partial match on digits, from the first digit', () {
      expect(ids(searchVisitors(visitors, query: '98765')), ['1']);
      expect(ids(searchVisitors(visitors, query: '4501')), ['12']);
      expect(ids(searchVisitors(visitors, query: '98 765')), ['1']);
      expect(ids(searchVisitors(visitors, query: '900')), ['40']);
      // One digit already filters mobiles (no minimum length).
      expect(
        ids(searchVisitors(visitors, query: '0')),
        ['1', '12', 'VIS-7', '40'],
      );
    });

    test('a numeric query also matches the exact visitor id', () {
      // "40" is Priya's id; no mobile contains "40".
      expect(ids(searchVisitors(visitors, query: '40')), ['40']);
      // "1" is Rahul's id AND a fragment of three mobile numbers.
      expect(ids(searchVisitors(visitors, query: '1')), ['1', '12', 'VIS-7']);
    });

    test('visitor id: exact only, never partial', () {
      expect(ids(searchVisitors(visitors, query: 'vis-7')), ['VIS-7']);
      expect(searchVisitors(visitors, query: 'VIS'), isEmpty);
    });

    test('letters in the query are never turned into mobile digits', () {
      // "VIS-7" contains the digit 7, which appears in several mobiles; it
      // must not pull those visitors in.
      expect(ids(searchVisitors(visitors, query: 'VIS-7')), ['VIS-7']);
    });

    test('no match gives an empty list', () {
      expect(searchVisitors(visitors, query: 'zzz'), isEmpty);
    });

    test('project filter alone and combined with status and query', () {
      final mixed = [
        buildVisitor(id: 'a', name: 'Asha', project: 'Project A'),
        buildVisitor(id: 'b', name: 'Asha Rao', project: 'Project B'),
        buildVisitor(
          id: 'c',
          name: 'Bala',
          project: 'Project B',
          status: VisitorStatus.checkedIn,
        ),
      ];
      expect(ids(searchVisitors(mixed, project: 'Project B')), ['b', 'c']);
      expect(
        ids(searchVisitors(mixed, project: 'Project B', query: 'asha')),
        ['b'],
      );
      expect(
        ids(
          searchVisitors(
            mixed,
            project: 'Project B',
            status: VisitorStatus.checkedIn,
          ),
        ),
        ['c'],
      );
      expect(searchVisitors(mixed, project: 'Project C'), isEmpty);
    });

    test('status filter alone and combined with a query', () {
      expect(
        ids(searchVisitors(visitors, status: VisitorStatus.checkedIn)),
        ['VIS-7'],
      );
      expect(
        searchVisitors(
          visitors,
          query: 'rahul',
          status: VisitorStatus.checkedOut,
        ),
        isEmpty,
      );
      expect(
        ids(
          searchVisitors(
            visitors,
            query: 'priya',
            status: VisitorStatus.checkedOut,
          ),
        ),
        ['40'],
      );
    });
  });

  group('VisitorsCubit filters', () {
    late VisitorsCubit cubit;

    setUp(() async {
      cubit = VisitorsCubit(FakeVisitorRepository(visitors));
      await cubit.load();
    });

    tearDown(() => cubit.close());

    test('status filter keeps the search text', () {
      cubit.setQuery('a');
      cubit.setStatusFilter(VisitorStatus.checkedIn);
      expect(cubit.state.query, 'a');
      expect(cubit.state.statusFilter, VisitorStatus.checkedIn);
      expect(ids(cubit.state.filtered), ['VIS-7']);
    });

    test('chip counts follow the search text', () {
      expect(cubit.state.countFor(null), 4);
      expect(cubit.state.countFor(VisitorStatus.registered), 2);
      cubit.setQuery('meera');
      expect(cubit.state.countFor(null), 1);
      expect(cubit.state.countFor(VisitorStatus.registered), 1);
      expect(cubit.state.countFor(VisitorStatus.checkedIn), 0);
    });

    test('selecting All and clearing filters reset the list', () {
      cubit.setQuery('x');
      cubit.setStatusFilter(VisitorStatus.checkedOut);
      expect(cubit.state.hasActiveFilters, isTrue);

      cubit.clearFilters();
      expect(cubit.state.query, isEmpty);
      expect(cubit.state.statusFilter, isNull);
      expect(cubit.state.hasActiveFilters, isFalse);
      expect(cubit.state.filtered, hasLength(4));

      cubit.setStatusFilter(VisitorStatus.checkedOut);
      cubit.setStatusFilter(null);
      expect(cubit.state.statusFilter, isNull);
    });

    test('project filter narrows the list and the chip counts', () async {
      final repo = FakeVisitorRepository([
        buildVisitor(id: '1', project: 'Project A'),
        buildVisitor(
          id: '2',
          project: 'Project B',
          status: VisitorStatus.checkedIn,
        ),
        buildVisitor(id: '3', project: 'Project B'),
      ]);
      final projectCubit = VisitorsCubit(repo);
      addTearDown(projectCubit.close);
      await projectCubit.load();

      projectCubit.setProjectFilter('Project B');

      // Same createdAt for all three, so compare as a set (sort order is not
      // guaranteed for ties).
      expect(ids(projectCubit.state.filtered).toSet(), {'2', '3'});
      expect(projectCubit.state.countFor(null), 2);
      expect(projectCubit.state.countFor(VisitorStatus.checkedIn), 1);
      expect(projectCubit.state.hasActiveFilters, isTrue);

      projectCubit.clearFilters();
      expect(projectCubit.state.projectFilter, isNull);
      expect(projectCubit.state.filtered, hasLength(3));
    });

    test('filters survive a refresh', () async {
      cubit.setStatusFilter(VisitorStatus.registered);
      cubit.setQuery('rahul');
      await cubit.load();
      expect(cubit.state.statusFilter, VisitorStatus.registered);
      expect(cubit.state.query, 'rahul');
      expect(ids(cubit.state.filtered), ['1']);
    });

    test('a visitor leaves a filtered list when their status changes', () async {
      cubit.setStatusFilter(VisitorStatus.registered);
      expect(ids(cubit.state.filtered), contains('1'));

      await cubit.checkIn('1');

      expect(ids(cubit.state.filtered), isNot(contains('1')));
      expect(cubit.state.countFor(VisitorStatus.checkedIn), 2);
    });
  });
}
