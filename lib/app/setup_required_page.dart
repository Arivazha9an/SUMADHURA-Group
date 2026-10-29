import 'package:flutter/material.dart';

import '../core/widgets/glass.dart';

/// Shown when no API base URL was supplied at build time. The app cannot work
/// without a real server, so it says so instead of showing fake data.
class SetupRequiredPage extends StatelessWidget {
  const SetupRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassScaffold(
      appBar: AppBar(title: const Text('Visitor Desk')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.settings_outlined, size: 40, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text('API not configured', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'This build has no API base URL. Create the mock API '
                '(see the README) and rebuild with:',
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD9DEE4)),
                ),
                child: const SelectableText(
                  'flutter run \\\n'
                  '  --dart-define=API_BASE_URL=\\\n'
                  '  https://<project-id>.mockapi.io/api/v1',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
