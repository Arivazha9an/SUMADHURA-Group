import 'package:flutter/material.dart';

import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../domain/visitor.dart';

/// Details collected for a new visit session.
typedef NewVisitDetails = ({String project, String purpose});

/// Asks for the project and purpose of a returning visitor's new visit.
/// Returns null when cancelled. The fields start with the previous visit's
/// values because repeat visitors usually come for the same reason.
Future<NewVisitDetails?> showStartVisitDialog(
  BuildContext context, {
  required String visitorName,
  required String initialProject,
  required String initialPurpose,
}) {
  return showDialog<NewVisitDetails>(
    context: context,
    builder: (_) => _StartVisitDialog(
      visitorName: visitorName,
      initialProject: initialProject,
      initialPurpose: initialPurpose,
    ),
  );
}

class _StartVisitDialog extends StatefulWidget {
  const _StartVisitDialog({
    required this.visitorName,
    required this.initialProject,
    required this.initialPurpose,
  });

  final String visitorName;
  final String initialProject;
  final String initialPurpose;

  @override
  State<_StartVisitDialog> createState() => _StartVisitDialogState();
}

class _StartVisitDialogState extends State<_StartVisitDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _purposeController;
  String? _project;

  @override
  void initState() {
    super.initState();
    _purposeController = TextEditingController(text: widget.initialPurpose);
    _project = widget.initialProject.isEmpty ? null : widget.initialProject;
  }

  @override
  void dispose() {
    _purposeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop((
      project: _project!,
      purpose: _purposeController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start new visit'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'A new visit will be created for ${widget.visitorName}. '
                'Earlier visits stay in their history.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _project,
                decoration: const InputDecoration(labelText: 'Project'),
                items: [
                  for (final project in {
                    ...kProjects,
                    if (_project != null) _project!,
                  })
                    DropdownMenuItem(value: project, child: Text(project)),
                ],
                onChanged: (value) => setState(() => _project = value),
                validator: (v) => Validators.selection(v, 'project'),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _purposeController,
                label: 'Purpose of visit',
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                validator: (v) => Validators.requiredText(v, 'Purpose of visit'),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Start visit')),
      ],
    );
  }
}
