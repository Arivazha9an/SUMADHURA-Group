import 'package:flutter_test/flutter_test.dart';
import 'package:visitor_management/features/visitors/data/qr_pass_image.dart';

void main() {
  const pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

  testWidgets('builds a PNG image for the visitor pass', (tester) async {
    // Image encoding needs real async work, which the fake-async test zone
    // would never complete.
    final bytes = await tester.runAsync(
      () => buildQrPassPng(
        visitorId: 'VIS001',
        visitorName: 'Rahul Sharma',
        project: 'Project A',
      ),
    );

    expect(bytes, isNotNull);
    expect(bytes!.sublist(0, 8), pngSignature);
    expect(bytes.length, greaterThan(1000));
  });

  testWidgets('different visitors produce different images', (tester) async {
    final images = await tester.runAsync(
      () => Future.wait([
        buildQrPassPng(visitorId: '1', visitorName: 'A', project: 'Project A'),
        buildQrPassPng(visitorId: '2', visitorName: 'A', project: 'Project A'),
      ]),
    );

    expect(images![0], isNot(equals(images[1])));
  });

  testWidgets('very long names do not break rendering', (tester) async {
    final bytes = await tester.runAsync(
      () => buildQrPassPng(
        visitorId: 'VIS-LONG',
        visitorName: 'A very long visitor name ' * 8,
        project: 'Project A',
      ),
    );
    expect(bytes!.sublist(0, 8), pngSignature);
  });
}
