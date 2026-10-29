import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visitor_management/features/qr_scanner/domain/qr_image_scan_service.dart';

/// Stands in for the platform ML decoder, which cannot run in unit tests.
class _FakeDecoder implements QrImageDecoder {
  _FakeDecoder(this._onDecode);

  final Future<List<String>> Function(String path) _onDecode;
  final List<String> pathsDecoded = [];

  @override
  Future<List<String>> decode(String imagePath) {
    pathsDecoded.add(imagePath);
    return _onDecode(imagePath);
  }
}

QrImageScanService _serviceReturning(List<String> codes) =>
    QrImageScanService(_FakeDecoder((_) async => codes));

void main() {
  group('QR payload parsing (firstVisitorId)', () {
    test('accepts plain ids and trims whitespace', () {
      expect(firstVisitorId(['42']), '42');
      expect(firstVisitorId([' VIS-001\n']), 'VIS-001');
    });

    test('skips non-visitor codes and returns the first valid id', () {
      expect(
        firstVisitorId(['https://example.com', 'WIFI:S:x;;', '17']),
        '17',
      );
    });

    test('returns null when nothing looks like an id', () {
      expect(firstVisitorId(const []), isNull);
      expect(firstVisitorId(['', '   ', 'two words']), isNull);
    });
  });

  group('image decoding service', () {
    test('returns the visitor id found in the image', () async {
      final result = await _serviceReturning(['23']).scan('/tmp/qr.png');
      expect(result, isA<QrImageVisitorFound>());
      expect((result as QrImageVisitorFound).visitorId, '23');
    });

    test('passes the picked file path to the decoder', () async {
      final decoder = _FakeDecoder((_) async => ['5']);
      await QrImageScanService(decoder).scan('/storage/pass.png');
      expect(decoder.pathsDecoded, ['/storage/pass.png']);
    });

    test('image without any QR code', () async {
      expect(
        await _serviceReturning([]).scan('/tmp/photo.jpg'),
        isA<QrImageNoCodeFound>(),
      );
      // Blank values count as "nothing found", not as an invalid code.
      expect(
        await _serviceReturning(['  ']).scan('/tmp/photo.jpg'),
        isA<QrImageNoCodeFound>(),
      );
    });

    test('QR code that is not a visitor pass', () async {
      expect(
        await _serviceReturning(['https://example.com/menu']).scan('/x.png'),
        isA<QrImageNotVisitorPass>(),
      );
    });

    test('a valid pass next to a stray code is still found', () async {
      final result = await _serviceReturning(['not a pass!', '88']).scan('/x');
      expect((result as QrImageVisitorFound).visitorId, '88');
    });

    test('decoder failures become "unreadable", never an exception', () async {
      final failing = QrImageScanService(
        _FakeDecoder((_) async => throw PlatformException(code: 'bad_image')),
      );
      expect(await failing.scan('/broken.png'), isA<QrImageUnreadable>());

      final io = QrImageScanService(
        _FakeDecoder((_) async => throw const FormatException('corrupt')),
      );
      expect(await io.scan('/corrupt.png'), isA<QrImageUnreadable>());
    });
  });
}
