import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/router.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/dashboard_stat_card.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/loading_view.dart';
import '../../visitors/domain/visitor.dart';
import '../../visitors/presentation/cubit/visitors_cubit.dart';
import '../../visitors/presentation/cubit/visitors_state.dart';
import '../../visitors/presentation/widgets/status_chip.dart';
import '../domain/dashboard_stats.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.onViewAllVisitors});

  /// Switches the shell to the Visitors tab.
  final VoidCallback onViewAllVisitors;

  Future<void> _refresh(BuildContext context) async {
    final result = await context.read<VisitorsCubit>().load();
    if (!context.mounted || result.isSuccess || result.isIgnored) return;
    showAppSnackBar(context, result.error!, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visitor Desk')),
      body: BlocBuilder<VisitorsCubit, VisitorsState>(
        builder: (context, state) {
          if (state.isInitialLoading) {
            return const LoadingView(message: 'Loading visitors…');
          }
          if (state.hasFailedWithoutData) {
            return ErrorView(
              type: state.errorType,
              message: state.errorMessage ?? 'Something went wrong.',
              onRetry: () => context.read<VisitorsCubit>().load(),
            );
          }

          final now = DateTime.now();
          final stats = DashboardStats.fromVisitors(state.visitors, now);
          return RefreshIndicator(
            onRefresh: () => _refresh(context),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 0, 16, GlassTokens.bottomInset(context)),
              children: [
                _DayHeading(now: now),
                const SizedBox(height: 12),
                _StatRow(stats: stats),
                const SizedBox(height: 16),
                const _QuickActions(),
                const SizedBox(height: 24),
                _RecentActivity(
                  activity: stats.recentActivity,
                  now: now,
                  onViewAll: onViewAllVisitors,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DayHeading extends StatelessWidget {
  const _DayHeading({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      formatDayHeading(now),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DashboardStatCard(
              value: stats.registeredToday,
              label: 'Total Visitors Today',
              icon: Icons.how_to_reg_outlined,
              color: primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DashboardStatCard(
              value: stats.currentlyCheckedIn,
              label: 'Currently Checked In',
              icon: StatusStyle.of(VisitorStatus.checkedIn).icon,
              color: StatusStyle.of(VisitorStatus.checkedIn).color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DashboardStatCard(
              value: stats.checkedOutToday,
              label: 'Checked Out Today',
              icon: StatusStyle.of(VisitorStatus.checkedOut).icon,
              color: StatusStyle.of(VisitorStatus.checkedOut).color,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CustomButton(
            label: 'Register visitor',
            icon: Icons.person_add_alt_1_outlined,
            onPressed: () => AppRouter.openForm(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CustomButton(
            label: 'Scan QR',
            icon: Icons.qr_code_scanner,
            variant: CustomButtonVariant.secondary,
            onPressed: () => AppRouter.openScanner(context),
          ),
        ),
      ],
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({
    required this.activity,
    required this.now,
    required this.onViewAll,
  });

  final List<RecentActivity> activity;
  final DateTime now;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent visitors',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(onPressed: onViewAll, child: const Text('All visitors')),
          ],
        ),
        const SizedBox(height: 4),
        if (activity.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No visitors yet. Registered visitors will show up here.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < activity.length; i++) ...[
                  if (i > 0) const Divider(),
                  _ActivityRow(item: activity[i], now: now),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item, required this.now});

  final RecentActivity item;
  final DateTime now;

  String get _verb => switch (item.type) {
        ActivityType.registered => 'Registered',
        ActivityType.checkedIn => 'Checked in',
        ActivityType.checkedOut => 'Checked out',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final visitor = item.visitor;
    return InkWell(
      onTap: () => AppRouter.openDetails(context, visitor.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visitor.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_verb ${formatRelativeToDay(item.at, now)}'
                    '  ·  ${visitor.project}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            StatusChip(status: visitor.status),
          ],
        ),
      ),
    );
  }
}
