import 'package:flutter/material.dart';

import '../../../../core/utils/date_time_utils.dart';
import '../../domain/visitor.dart';
import 'status_chip.dart';

/// All visit sessions of one visitor, newest first. Finished visits are shown
/// exactly as they were saved: their timestamps never change.
class VisitHistoryCard extends StatelessWidget {
  const VisitHistoryCard({super.key, required this.visitor});

  final Visitor visitor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visits = visitor.visitsNewestFirst;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Visit history (${visits.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (visits.isEmpty)
              Text(
                'No visits yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            for (var i = 0; i < visits.length; i++) ...[
              if (i > 0) const Divider(height: 24),
              _VisitRow(visit: visits[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.visit});

  final Visit visit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                formatDateTime(visit.createdAt),
                style: theme.textTheme.titleSmall,
              ),
            ),
            StatusChip(status: visit.status),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          visit.purpose.isEmpty
              ? visit.project
              : '${visit.project} · ${visit.purpose}',
          style: theme.textTheme.bodyMedium,
        ),
        if (visit.checkInTime != null)
          Text(
            'Checked in ${formatDateTime(visit.checkInTime!)}',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        if (visit.checkOutTime != null)
          Text(
            'Checked out ${formatDateTime(visit.checkOutTime!)}',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
      ],
    );
  }
}
