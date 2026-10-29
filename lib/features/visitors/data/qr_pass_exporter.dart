import 'dart:io';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/visitor.dart';
import 'qr_pass_image.dart';

/// A share/save failure with a message that can be shown to staff as-is.
class QrExportException implements Exception {
  const QrExportException(this.message);

  final String message;

  @override
  String toString() => 'QrExportException: $message';
}

/// Sends a visitor's QR pass out of the app, so a visitor who loses theirs can
/// be sent a new copy (WhatsApp, SMS, email...) or the image kept on the phone.
abstract class QrPassExporter {
  /// Opens the system share sheet with the pass image.
  Future<void> share(Visitor visitor);

  /// Saves the pass image to the phone's photo gallery.
  Future<void> saveToGallery(Visitor visitor);
}

/// Real implementation: `share_plus` for sharing, `gal` for the gallery.
class PlatformQrPassExporter implements QrPassExporter {
  const PlatformQrPassExporter();

  @override
  Future<void> share(Visitor visitor) async {
    try {
      final file = await _writePass(visitor);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: 'Visitor pass for ${visitor.name}',
        text: 'Visitor pass for ${visitor.name}. Visitor ID: ${visitor.id}. '
            'Show the QR code at the front desk.',
      );
    } on Exception {
      // Includes MissingPluginException (app not fully rebuilt after the
      // plugin was added) and any I/O failure.
      throw const QrExportException(
        "Couldn't open the share sheet. Fully stop and rebuild the app, "
        'then try again.',
      );
    }
  }

  @override
  Future<void> saveToGallery(Visitor visitor) async {
    try {
      final file = await _writePass(visitor);
      await Gal.putImage(file.path);
    } on GalException catch (error) {
      throw QrExportException(
        error.type == GalExceptionType.accessDenied
            ? 'Allow photo access for Visitor Desk in Android Settings to '
                'save the pass.'
            : "Couldn't save the QR pass to the gallery.",
      );
    } on Exception {
      throw const QrExportException(
        "Couldn't save the QR pass. Fully stop and rebuild the app, then try "
        'again.',
      );
    }
  }

  /// Renders the pass into the app's temporary folder. Visitor ids are limited
  /// to letters, digits, "_" and "-" (see `parseVisitorId`), so they are safe
  /// to use in a file name.
  Future<File> _writePass(Visitor visitor) async {
    final bytes = await buildQrPassPng(
      visitorId: visitor.id,
      visitorName: visitor.name,
      project: visitor.project,
    );
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/visitor-pass-${visitor.id}.png');
    return file.writeAsBytes(bytes, flush: true);
  }
}
