import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visitor_management/core/widgets/custom_button.dart';
import 'package:visitor_management/core/widgets/custom_text_field.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('CustomButton', () {
    testWidgets('calls onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(CustomButton(label: 'Go', onPressed: () => taps++)),
      );

      await tester.tap(find.text('Go'));
      expect(taps, 1);
    });

    testWidgets('null onPressed is a disabled button', (tester) async {
      await tester.pumpWidget(
        _host(const CustomButton(label: 'Go', onPressed: null)),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('loading shows a spinner and ignores taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          CustomButton(
            label: 'Save',
            isLoading: true,
            onPressed: () => taps++,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      await tester.tap(find.text('Save'));
      expect(taps, 0);
    });

    testWidgets('secondary variant is outlined and shows its icon',
        (tester) async {
      await tester.pumpWidget(
        _host(
          CustomButton(
            label: 'Scan',
            icon: Icons.qr_code_scanner,
            variant: CustomButtonVariant.secondary,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
    });
  });

  group('CustomTextField', () {
    testWidgets('shows its label and the validator message', (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          Form(
            key: formKey,
            child: CustomTextField(
              controller: controller,
              label: 'Visitor name',
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
          ),
        ),
      );

      expect(find.text('Visitor name'), findsOneWidget);
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'Asha');
      expect(formKey.currentState!.validate(), isTrue);
    });

    testWidgets('disabled field does not accept input', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          CustomTextField(
            controller: controller,
            label: 'Name',
            enabled: false,
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
    });
  });
}
