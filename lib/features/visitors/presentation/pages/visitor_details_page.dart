import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/router.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/glass.dart';
import '../../domain/visitor.dart';
import '../../data/qr_pass_exporter.dart';
import '../cubit/visitors_cubit.dart';
import '../widgets/delete_visitor.dart';
import '../widgets/start_visit_dialog.dart';
import '../widgets/status_chip.dart';
import '../widgets/visit_history_card.dart';

/// Reads the visitor from [VisitorsCubit] by id, so a check-in made here (or a
/// refresh elsewhere) is reflected immediately without passing objects around.
class VisitorDetailsPage extends StatelessWidget {
  const VisitorDetailsPage({super.key, required this.visitorId});

  final String visitorId;

  static const double _qrSize = 200;
  static const double _maxContentWidth = 560;

  @override
  Widget build(BuildContext context) {
    final visitor = context.select(
      (VisitorsCubit cubit) => cubit.state.byId(visitorId),
    );
    final isBusy = context.select(
      (VisitorsCubit cubit) => cubit.state.busyIds.contains(visitorId),
    );

    if (visitor == null) {
      return GlassScaffold(
        appBar: AppBar(title: const Text('Visitor')),
        body: EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Visitor not found',
          message: 'This record may have been deleted.',
          actionLabel: 'Go back',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    return GlassScaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Visitor details'),
        actions: [
          IconButton(
            tooltip: 'Edit visitor',
            icon: const Icon(Icons.edit_outlined),
            onPressed: isBusy
                ? null
                : () => AppRouter.openForm(context, visitor: visitor),
          ),
          IconButton(
            tooltip: 'Delete visitor',
            icon: const Icon(Icons.delete_outline),
            onPressed: isBusy ? null : () => _delete(context, visitor),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 4, 16, GlassTokens.bottomInset(context)),
              children: [
                _Header(visitor: visitor),
                const SizedBox(height: 16),
                _InfoCard(visitor: visitor),
                const SizedBox(height: 16),
                _QrCard(visitor: visitor, size: _qrSize),
                const SizedBox(height: 16),
                VisitHistoryCard(visitor: visitor),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _ActionBar(
        visitor: visitor,
        isBusy: isBusy,
        onCheckIn: () => _changeStatus(context, visitor, checkIn: true),
        onCheckOut: () => _changeStatus(context, visitor, checkIn: false),
        onStartVisit: () => _startVisit(context, visitor),
      ),
    );
  }

  /// Returning visitor: ask for project / purpose, then create a NEW visit.
  /// The cubit refuses (and explains) if an active visit already exists.
  Future<void> _startVisit(BuildContext context, Visitor visitor) async {
    final cubit = context.read<VisitorsCubit>();
    final details = await showStartVisitDialog(
      context,
      visitorName: visitor.name,
      initialProject: visitor.project,
      initialPurpose: visitor.purpose,
    );
    if (details == null || !context.mounted) return;

    final result = await cubit.startNewVisit(
      visitor.id,
      project: details.project,
      purpose: details.purpose,
    );
    if (!context.mounted || result.isIgnored) return;

    if (result.isSuccess) {
      showAppSnackBar(context, 'New visit started for ${visitor.name}.');
    } else {
      showAppSnackBar(context, result.error!, isError: true);
    }
  }

  Future<void> _delete(BuildContext context, Visitor visitor) async {
    final deleted = await confirmAndDeleteVisitor(context, visitor);
    if (deleted && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _changeStatus(
    BuildContext context,
    Visitor visitor, {
    required bool checkIn,
  }) async {
    final cubit = context.read<VisitorsCubit>();
    final result =
        checkIn ? await cubit.checkIn(visitor.id) : await cubit.checkOut(visitor.id);
    if (!context.mounted || result.isIgnored) return;

    if (result.isSuccess) {
      showAppSnackBar(
        context,
        checkIn
            ? '${visitor.name} checked in.'
            : '${visitor.name} checked out.',
      );
    } else {
      // Nothing was changed on the server, so no success message is shown.
      showAppSnackBar(context, result.error!, isError: true);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.visitor});

  final Visitor visitor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          visitor.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            StatusChip(status: visitor.status),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'ID ${visitor.id}',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.visitor});

  final Visitor visitor;

  @override
  Widget build(BuildContext context) {
    final rows = <_InfoRow>[
      _InfoRow('Mobile', visitor.mobile),
      if (visitor.email != null) _InfoRow('Email', visitor.email!),
      _InfoRow('Visitor type', visitor.visitorType.label),
      _InfoRow('Project', visitor.project),
      _InfoRow('Purpose', visitor.purpose.isEmpty ? '—' : visitor.purpose),
      _InfoRow('First registered', formatDateTime(visitor.createdAt)),
      if (visitor.currentVisit != null)
        _InfoRow(
          visitor.hasActiveVisit ? 'Visit started' : 'Last visit',
          formatDateTime(visitor.currentVisit!.createdAt),
        ),
      if (visitor.checkInTime != null)
        _InfoRow('Checked in', formatDateTime(visitor.checkInTime!)),
      if (visitor.checkOutTime != null)
        _InfoRow('Checked out', formatDateTime(visitor.checkOutTime!)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  static const double _labelWidth = 104;

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _labelWidth,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

enum _QrAction { share, save }

class _QrCard extends StatefulWidget {
  const _QrCard({
    required this.visitor,
    required this.size,
    this.exporter = const PlatformQrPassExporter(),
  });

  final Visitor visitor;
  final double size;
  final QrPassExporter exporter;

  @override
  State<_QrCard> createState() => _QrCardState();
}

class _QrCardState extends State<_QrCard> {
  /// The action in progress. Non-null disables both buttons, so a double tap
  /// cannot open two share sheets or save the image twice.
  _QrAction? _active;

  Future<void> _run(_QrAction action) async {
    if (_active != null) return;
    setState(() => _active = action);
    try {
      switch (action) {
        case _QrAction.share:
          await widget.exporter.share(widget.visitor);
        case _QrAction.save:
          await widget.exporter.saveToGallery(widget.visitor);
          if (mounted) showAppSnackBar(context, 'QR pass saved to your gallery.');
      }
    } on QrExportException catch (error) {
      if (mounted) showAppSnackBar(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _active = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visitor = widget.visitor;
    final busy = _active != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // The QR payload is exactly the server-generated visitor ID.
            // White background and a quiet zone keep it scannable.
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.white,
              child: QrImageView(
                data: visitor.id,
                version: QrVersions.auto,
                size: widget.size,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              visitor.id,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Send this pass to the visitor so they can show it at the gate. '
              'The ID above works for search if the QR is lost.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    label: 'Share',
                    icon: Icons.share_outlined,
                    variant: CustomButtonVariant.secondary,
                    isLoading: _active == _QrAction.share,
                    onPressed: busy ? null : () => _run(_QrAction.share),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    label: 'Save',
                    icon: Icons.download_outlined,
                    variant: CustomButtonVariant.secondary,
                    isLoading: _active == _QrAction.save,
                    onPressed: busy ? null : () => _run(_QrAction.save),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows only the action that is valid for the current status.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.visitor,
    required this.isBusy,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onStartVisit,
  });

  final Visitor visitor;
  final bool isBusy;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final VoidCallback onStartVisit;

  @override
  Widget build(BuildContext context) {
    final Widget child;

    if (visitor.status.canCheckIn) {
      child = CustomButton(
        label: 'Check in',
        icon: Icons.login,
        isLoading: isBusy,
        onPressed: onCheckIn,
      );
    } else if (visitor.status.canCheckOut) {
      child = CustomButton(
        label: 'Check out',
        icon: Icons.logout,
        isLoading: isBusy,
        onPressed: onCheckOut,
      );
    } else {
      // The last visit is finished (or none exists): the only valid action is
      // to start a NEW visit. A finished visit is never reopened.
      child = CustomButton(
        label: 'Start new visit',
        icon: Icons.add_circle_outline,
        isLoading: isBusy,
        onPressed: onStartVisit,
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: GlassContainer(
          radius: 34,
          blur: 30,
          tintAlpha: 0.45,
          padding: const EdgeInsets.all(6),
          child: SizedBox(width: double.infinity, height: 52, child: child),
        ),
      ),
    );
  }
}
