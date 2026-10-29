import '../../visitors/domain/visitor.dart';

/// Reads the raw text of every QR code found in an image file.
///
/// An interface so the app uses `mobile_scanner` while tests use a fake: image
/// decoding itself needs the platform ML kit and cannot run in unit tests.
abstract class QrImageDecoder {
  /// Returns the raw values found (possibly empty). Throws if the file cannot
  /// be read or decoded at all.
  Future<List<String>> decode(String imagePath);
}

/// Outcome of scanning a picked image. The UI maps each case to a message.
sealed class QrImageScanResult {
  const QrImageScanResult();
}

/// A QR code with a well-formed visitor id was found.
class QrImageVisitorFound extends QrImageScanResult {
  const QrImageVisitorFound(this.visitorId);

  final String visitorId;
}

/// The image was readable but contains no QR code.
class QrImageNoCodeFound extends QrImageScanResult {
  const QrImageNoCodeFound();
}

/// QR code(s) were found but none holds a visitor id.
class QrImageNotVisitorPass extends QrImageScanResult {
  const QrImageNotVisitorPass();
}

/// The image could not be opened or decoded.
class QrImageUnreadable extends QrImageScanResult {
  const QrImageUnreadable();
}

/// Returns the first value that looks like a visitor id, or null.
/// An image can contain several QR codes; a stray one must not hide a valid
/// visitor pass next to it.
String? firstVisitorId(Iterable<String> rawValues) {
  for (final raw in rawValues) {
    final id = parseVisitorId(raw);
    if (id != null) return id;
  }
  return null;
}

class QrImageScanService {
  const QrImageScanService(this._decoder);

  final QrImageDecoder _decoder;

  Future<QrImageScanResult> scan(String imagePath) async {
    final List<String> codes;
    try {
      codes = await _decoder.decode(imagePath);
    } on Exception {
      return const QrImageUnreadable();
    }

    final nonEmpty = codes.where((code) => code.trim().isNotEmpty).toList();
    if (nonEmpty.isEmpty) return const QrImageNoCodeFound();

    final id = firstVisitorId(nonEmpty);
    return id == null
        ? const QrImageNotVisitorPass()
        : QrImageVisitorFound(id);
  }
}
