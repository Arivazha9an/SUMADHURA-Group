import 'package:mobile_scanner/mobile_scanner.dart';

import '../domain/qr_image_scan_service.dart';

/// Decodes QR codes from a gallery image using `mobile_scanner`'s
/// `analyzeImage` (ML Kit on Android), so no extra decoding package is needed.
class MobileScannerImageDecoder implements QrImageDecoder {
  const MobileScannerImageDecoder(this._controller);

  final MobileScannerController _controller;

  @override
  Future<List<String>> decode(String imagePath) async {
    final capture = await _controller.analyzeImage(imagePath);
    if (capture == null) return const [];
    return [
      for (final barcode in capture.barcodes)
        if (barcode.rawValue != null) barcode.rawValue!,
    ];
  }
}
