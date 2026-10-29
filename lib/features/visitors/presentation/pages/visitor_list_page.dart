import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/glass.dart';
import '../../domain/visitor.dart';
import '../cubit/visitors_cubit.dart';
import '../cubit/visitors_state.dart';
import '../widgets/delete_visitor.dart';
import '../widgets/status_filter_bar.dart';
import '../widgets/visitor_card.dart';
import '../widgets/visitor_list_skeleton.dart';

class VisitorListPage extends StatefulWidget {
  const VisitorListPage({super.key});

  @override
  State<VisitorListPage> createState() => _VisitorListPageState();
}

class _VisitorListPageState extends State<VisitorListPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final result = await context.read<VisitorsCubit>().load();
    if (!mounted || result.isSuccess || result.isIgnored) return;
    showAppSnackBar(context, result.error!, isError: true);
  }

  /// Clears the search box only; the status filter stays as chosen.
  void _clearSearch() {
    _searchController.clear();
    context.read<VisitorsCubit>().setQuery('');
  }

  /// Clears the search text and the status filter together.
  void _clearAllFilters() {
    _searchController.clear();
    context.read<VisitorsCubit>().clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitors'),
        actions: [
          IconButton(
            tooltip: 'Register visitor',
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () => AppRouter.openForm(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: context.read<VisitorsCubit>().setQuery,
              decoration: InputDecoration(
                hintText: 'Search name, mobile or visitor ID',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                          onPressed: _clearSearch,
                        ),
                ),
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<VisitorsCubit, VisitorsState>(
              builder: (context, state) => _buildContent(context, state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, VisitorsState state) {
    if (state.isInitialLoading) {
      return const VisitorListSkeleton();
    }
    if (state.hasFailedWithoutData) {
      return ErrorView(
        type: state.errorType,
        message: state.errorMessage ?? 'Something went wrong.',
        onRetry: () => context.read<VisitorsCubit>().load(),
      );
    }
    if (state.visitors.isEmpty) {
      return EmptyState(
        icon: Icons.groups_outlined,
        title: 'No visitors yet',
        message: 'Registered visitors will appear here.',
        actionLabel: 'Register visitor',
        onAction: () => AppRouter.openForm(context),
      );
    }

    final visitors = state.filtered;
    return Column(
      children: [
        const StatusFilterBar(),
        Expanded(
          child: visitors.isEmpty
              ? _buildNoMatches(state)
              : _buildList(visitors, state),
        ),
      ],
    );
  }

  Widget _buildNoMatches(VisitorsState state) {
    final query = state.query.trim();
    final status = state.statusFilter;
    final project = state.projectFilter;
    final filters = [
      if (status != null) status.label.toLowerCase(),
      if (project != null) 'in $project',
    ].join(' ');
    final String message;
    if (query.isNotEmpty && filters.isNotEmpty) {
      message = 'No visitors ($filters) match "$query".';
    } else if (query.isNotEmpty) {
      message = 'Nothing matches "$query".';
    } else if (filters.isNotEmpty) {
      message = 'No visitors found ($filters).';
    } else {
      message = 'No visitors to show.';
    }
    return EmptyState(
      icon: Icons.search_off,
      title: 'No matching visitors',
      message: message,
      actionLabel: state.hasActiveFilters ? 'Clear filters' : null,
      onAction: state.hasActiveFilters ? _clearAllFilters : null,
    );
  }

  Widget _buildList(List<Visitor> visitors, VisitorsState state) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 4, 16, GlassTokens.bottomInset(context)),
        itemCount: visitors.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final visitor = visitors[index];
          return VisitorCard(
            visitor: visitor,
            isBusy: state.busyIds.contains(visitor.id),
            onTap: () => AppRouter.openDetails(context, visitor.id),
            onEdit: () => AppRouter.openForm(context, visitor: visitor),
            onDelete: () => confirmAndDeleteVisitor(context, visitor),
          );
        },
      ),
    );
  }
}
