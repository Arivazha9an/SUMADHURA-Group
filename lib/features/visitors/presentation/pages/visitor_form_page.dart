import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/glass.dart';
import '../../domain/visitor.dart';
import '../cubit/visitors_cubit.dart';

/// Registration and editing share this one form: pass [visitor] to edit.
class VisitorFormPage extends StatefulWidget {
  const VisitorFormPage({super.key, this.visitor});

  final Visitor? visitor;

  @override
  State<VisitorFormPage> createState() => _VisitorFormPageState();
}

class _VisitorFormPageState extends State<VisitorFormPage> {
  static const int _mobileLength = 10;
  static const double _maxFormWidth = 560;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _emailController;
  late final TextEditingController _purposeController;
  VisitorType? _visitorType;
  String? _project;

  bool get _isEditing => widget.visitor != null;

  /// Project and purpose belong to a visit. While editing, they can only be
  /// changed for an unfinished visit; finished visits are history.
  bool get _canEditVisitFields => !_isEditing || widget.visitor!.hasActiveVisit;

  @override
  void initState() {
    super.initState();
    final visitor = widget.visitor;
    _nameController = TextEditingController(text: visitor?.name);
    _mobileController = TextEditingController(text: visitor?.mobile);
    _emailController = TextEditingController(text: visitor?.email);
    _purposeController = TextEditingController(text: visitor?.purpose);
    _visitorType = visitor?.visitorType;
    // Keep the saved project selectable even if it is not in the default list.
    _project = visitor?.project;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  /// True when any field differs from where the form started.
  bool get _isDirty {
    final visitor = widget.visitor;
    return _nameController.text.trim() != (visitor?.name ?? '') ||
        _mobileController.text.trim() != (visitor?.mobile ?? '') ||
        _emailController.text.trim() != (visitor?.email ?? '') ||
        _purposeController.text.trim() != (visitor?.purpose ?? '') ||
        _visitorType != visitor?.visitorType ||
        _project != visitor?.project;
  }

  /// Called when the user tries to leave (Back, gesture or Cancel) with
  /// unsaved input. Direct `Navigator.pop` calls after a save bypass this.
  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: Text(
          _isEditing
              ? 'Your edits to this visitor have not been saved.'
              : 'This visitor has not been registered yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final cubit = context.read<VisitorsCubit>();
    final draft = VisitorDraft(
      name: _nameController.text.trim(),
      mobile: _mobileController.text.trim(),
      email: _emailController.text.trim(),
      visitorType: _visitorType!,
      project: _project!,
      purpose: _purposeController.text.trim(),
    );

    final existing = widget.visitor;
    final result = existing == null
        ? await cubit.register(draft)
        : await cubit.updateVisitor(existing.id, draft);

    // A second tap while the first request is running is ignored by the cubit.
    if (!mounted || result.isIgnored) return;

    if (!result.isSuccess) {
      showAppSnackBar(
        context,
        _isEditing
            ? "Couldn't save changes. ${result.error}"
            : "Couldn't register the visitor. ${result.error}",
        isError: true,
      );
      return;
    }

    if (_isEditing) {
      showAppSnackBar(context, 'Changes saved.');
      Navigator.of(context).pop();
    } else {
      showAppSnackBar(context, '${result.data!.name} is registered.');
      await AppRouter.replaceWithDetails(context, result.data!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.select((VisitorsCubit c) => c.state.isSaving);

    return PopScope(
      canPop: !_isDirty && !isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || isSaving) return;
        unawaited(_confirmDiscard());
      },
      child: GlassScaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit visitor' : 'Register visitor'),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxFormWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Form(
                  key: _formKey,
                  onChanged: () => setState(() {}),
                  autovalidateMode: AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CustomTextField(
                        controller: _nameController,
                        label: 'Visitor name',
                        enabled: !isSaving,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                            Validators.requiredText(v, 'Visitor name'),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _mobileController,
                        label: 'Mobile number',
                        helperText: '10 digits',
                        enabled: !isSaving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(_mobileLength),
                        ],
                        validator: Validators.mobile,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _emailController,
                        label: 'Email (optional)',
                        enabled: !isSaving,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        validator: Validators.optionalEmail,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<VisitorType>(
                        initialValue: _visitorType,
                        decoration: const InputDecoration(
                          labelText: 'Visitor type',
                        ),
                        items: [
                          for (final type in VisitorType.values)
                            DropdownMenuItem(
                              value: type,
                              child: Text(type.label),
                            ),
                        ],
                        onChanged: isSaving
                            ? null
                            : (value) => setState(() => _visitorType = value),
                        validator: (v) =>
                            Validators.selection(v, 'visitor type'),
                      ),
                      if (!_canEditVisitFields) ...[
                        const SizedBox(height: 16),
                        Text(
                          'The last visit is finished, so its project and '
                          'purpose are kept as they were. Start a new visit '
                          'from the details screen to change them.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _project,
                        decoration: const InputDecoration(
                          labelText: 'Project',
                        ),
                        items: [
                          for (final project in {
                            ...kProjects,
                            if (_project != null) _project!,
                          })
                            DropdownMenuItem(
                              value: project,
                              child: Text(project),
                            ),
                        ],
                        onChanged: isSaving || !_canEditVisitFields
                            ? null
                            : (value) => setState(() => _project = value),
                        validator: (v) => Validators.selection(v, 'project'),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _purposeController,
                        label: 'Purpose of visit',
                        enabled: !isSaving && _canEditVisitFields,
                        minLines: 2,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.done,
                        validator: (v) =>
                            Validators.requiredText(v, 'Purpose of visit'),
                        onSubmitted: (_) => isSaving ? null : _submit(),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: CustomButton(
                              label: 'Cancel',
                              variant: CustomButtonVariant.secondary,
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.of(context).maybePop(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: CustomButton(
                              label: _isEditing
                                  ? 'Save changes'
                                  : 'Register visitor',
                              isLoading: isSaving,
                              onPressed: _submit,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
