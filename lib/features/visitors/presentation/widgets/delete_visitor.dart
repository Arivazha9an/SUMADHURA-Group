import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/app_snack_bar.dart';
import '../../domain/visitor.dart';
import '../cubit/visitors_cubit.dart';

/// Asks for confirmation, deletes through the cubit and reports the outcome.
/// Returns true only when the record was actually deleted on the server.
Future<bool> confirmAndDeleteVisitor(
  BuildContext context,
  Visitor visitor,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete visitor?'),
      content: Text(
        'This permanently removes ${visitor.name}. Their QR code will stop '
        'working.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  final result = await context.read<VisitorsCubit>().delete(visitor.id);
  if (!context.mounted || result.isIgnored) return false;

  if (result.isSuccess) {
    showAppSnackBar(context, '${visitor.name} was deleted.');
    return true;
  }
  showAppSnackBar(
    context,
    "Couldn't delete ${visitor.name}. ${result.error}",
    isError: true,
  );
  return false;
}
