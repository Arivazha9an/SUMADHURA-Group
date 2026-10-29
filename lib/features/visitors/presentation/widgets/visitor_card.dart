import 'package:flutter/material.dart';

import '../../domain/visitor.dart';
import 'status_chip.dart';

/// One row of the visitor list. Shows name, mobile, project, type and status,
/// with edit/delete shortcuts. Tapping the row opens the details screen.
class VisitorCard extends StatelessWidget {
  const VisitorCard({
    super.key,
    required this.visitor,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.isBusy = false,
  });

  final Visitor visitor;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      visitor.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: StatusChip(status: visitor.status),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${visitor.mobile}  ·  ${visitor.project}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      visitor.visitorType.label,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ),
                  if (isBusy)
                    const Padding(
                      padding: EdgeInsets.only(right: 14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else ...[
                    IconButton(
                      tooltip: 'Edit ${visitor.name}',
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      tooltip: 'Delete ${visitor.name}',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: theme.colorScheme.error,
                      onPressed: onDelete,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
