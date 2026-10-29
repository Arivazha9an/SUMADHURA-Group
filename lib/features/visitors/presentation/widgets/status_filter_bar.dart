import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/config/ui_style.dart';
import '../../domain/visitor.dart';
import '../cubit/visitors_cubit.dart';
import '../cubit/visitors_state.dart';
import 'status_chip.dart';

/// Horizontal filter row: status chips (All, Registered, Checked In,
/// Checked Out) followed by a project menu. Status counts follow the search
/// text and the project filter, so they match the visible list.
class StatusFilterBar extends StatelessWidget {
  const StatusFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VisitorsCubit, VisitorsState>(
      buildWhen: (a, b) =>
          a.statusFilter != b.statusFilter ||
          a.projectFilter != b.projectFilter ||
          a.visitors != b.visitors ||
          a.query != b.query,
      builder: (context, state) {
        final cubit = context.read<VisitorsCubit>();
        return SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            children: [
              _FilterChip(
                label: 'All',
                count: state.countFor(null),
                selected: state.statusFilter == null,
                onSelected: () => cubit.setStatusFilter(null),
              ),
              for (final status in VisitorStatus.values) ...[
                const SizedBox(width: 8),
                _FilterChip(
                  label: status.label,
                  count: state.countFor(status),
                  selected: state.statusFilter == status,
                  color: StatusStyle.of(status).color,
                  onSelected: () => cubit.setStatusFilter(status),
                ),
              ],
              const SizedBox(width: 8),
              _ProjectMenu(
                selected: state.projectFilter,
                options: state.projectOptions,
                onSelected: cubit.setProjectFilter,
              ),
            ],
          ),
        );
      },
    );
  }
}

Color _chipBorder(bool selected, Color accent) {
  if (selected) return accent;
  return UiStyle.glass
      ? Colors.white.withValues(alpha: 0.9)
      : AppTheme.border;
}

Color get _chipBackground =>
    UiStyle.glass ? Colors.white.withValues(alpha: 0.6) : Colors.white;

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
    this.color,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return ChoiceChip(
      label: Text('$label · $count'),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      selectedColor: accent.withValues(alpha: 0.14),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? accent : null,
      ),
      shape: const StadiumBorder(),
      side: BorderSide(color: _chipBorder(selected, accent)),
      backgroundColor: _chipBackground,
    );
  }
}

/// "Project" dropdown chip. Picking the already selected project, or "All
/// projects", clears the filter.
class _ProjectMenu extends StatelessWidget {
  const _ProjectMenu({
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final String? selected;
  final List<String> options;
  final ValueChanged<String?> onSelected;

  /// PopupMenuButton cannot return null for "All", so it gets a sentinel.
  static const String _all = '__all__';

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final active = selected != null;

    return PopupMenuButton<String>(
      tooltip: 'Filter by project',
      onSelected: (value) => onSelected(value == _all ? null : value),
      itemBuilder: (context) => [
        const PopupMenuItem(value: _all, child: Text('All projects')),
        for (final project in options)
          CheckedPopupMenuItem(
            value: project,
            checked: project == selected,
            child: Text(project),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.14) : _chipBackground,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: _chipBorder(active, accent)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list,
              size: 18,
              color: active ? accent : null,
            ),
            const SizedBox(width: 6),
            Text(
              selected ?? 'Project',
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? accent : null,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: active ? accent : null,
            ),
          ],
        ),
      ),
    );
  }
}
