import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Pixel layout of the shareable visitor pass (a portrait PNG).
class _Layout {
  static const double width = 720;
  static const double margin = 72;
  static const double qrSize = width - margin * 2;
  static const double headerHeight = 170;
  static const double footerHeight = 200;
  static const double height = headerHeight + qrSize + footerHeight;
}

const Color _ink = Color(0xFF14202E);
const Color _muted = Color(0xFF55616B);

/// Renders a visitor pass as PNG bytes: title, visitor name, the QR code (the
/// payload is exactly [visitorId]) and the ID in plain text underneath.
///
/// The ID is printed so that a visitor who loses the image, or a QR that will
/// not scan, can still be found by the front desk through the search box.
Future<Uint8List> buildQrPassPng({
  required String visitorId,
  required String visitorName,
  required String project,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  // White page: also gives the QR code its required quiet zone.
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, _Layout.width, _Layout.height),
    ui.Paint()..color = Colors.white,
  );

  _paintCentered(
    canvas,
    'VISITOR PASS',
    top: 44,
    fontSize: 26,
    weight: FontWeight.w700,
    color: _muted,
    letterSpacing: 4,
  );
  _paintCentered(
    canvas,
    visitorName,
    top: 92,
    fontSize: 40,
    weight: FontWeight.w700,
  );

  final qr = QrPainter(
    data: visitorId,
    version: QrVersions.auto,
    errorCorrectionLevel: QrErrorCorrectLevel.M,
    gapless: true,
  );
  canvas.save();
  canvas.translate(_Layout.margin, _Layout.headerHeight);
  qr.paint(canvas, const Size(_Layout.qrSize, _Layout.qrSize));
  canvas.restore();

  const footerTop = _Layout.headerHeight + _Layout.qrSize + 28;
  _paintCentered(
    canvas,
    'ID  $visitorId',
    top: footerTop,
    fontSize: 44,
    weight: FontWeight.w700,
    letterSpacing: 1,
  );
  _paintCentered(
    canvas,
    project,
    top: footerTop + 62,
    fontSize: 28,
    color: _muted,
  );
  _paintCentered(
    canvas,
    'Show this code at the front desk',
    top: footerTop + 108,
    fontSize: 24,
    color: _muted,
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    _Layout.width.toInt(),
    _Layout.height.toInt(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();

  if (data == null) throw Exception('Could not encode the QR pass image');
  return data.buffer.asUint8List();
}

/// Paints one horizontally centered line (ellipsized if too wide).
void _paintCentered(
  ui.Canvas canvas,
  String text, {
  required double top,
  required double fontSize,
  FontWeight weight = FontWeight.w400,
  Color color = _ink,
  double letterSpacing = 0,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: _Layout.width - _Layout.margin);
  painter.paint(canvas, Offset((_Layout.width - painter.width) / 2, top));
}
