import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/router.dart';
import '../../../core/widgets/glass.dart';
import '../../visitors/domain/visitor.dart';
import '../../visitors/presentation/cubit/visitors_cubit.dart';
import '../data/mobile_scanner_image_decoder.dart';
import '../domain/qr_image_scan_service.dart';

/// QR scanner: live camera, or a QR image picked from the gallery.
///
/// Both inputs end in [_openVisitor]: validate the id, look the visitor up
/// through the API, open details. `_handling` is set synchronously before any
/// `await`, so repeated camera callbacks or repeated taps on "Upload" can never
/// start a second lookup for the same scan.
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage>
    with WidgetsBindingObserver {
  static const double _frameSize = 240;

  static const String _notVisitorPassMessage =
      'This QR code is not a visitor pass. Use the code shown on a '
      "visitor's details screen.";

  final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final ImagePicker _picker = ImagePicker();
  late final QrImageScanService _imageScanService =
      QrImageScanService(MobileScannerImageDecoder(_controller));

  /// True while a scan is being processed (or details are open).
  bool _handling = false;
  bool _starting = false;
  String? _scanError;
  MobileScannerException? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_startCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  /// Release the camera when the app is backgrounded and re-acquire it on
  /// return (this also picks up a permission granted in system settings).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_handling && _scanError == null) unawaited(_startCamera());
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(_controller.stop());
    }
  }

  Future<void> _startCamera() async {
    if (_starting || !mounted) return;
    _starting = true;
    try {
      await _controller.start();
      if (mounted && _cameraError != null) setState(() => _cameraError = null);
    } on MobileScannerException catch (error) {
      // Already running (e.g. resumed right after the permission dialog).
      if (error.errorCode ==
          MobileScannerErrorCode.controllerAlreadyInitialized) {
        return;
      }
      if (mounted) setState(() => _cameraError = error);
    } finally {
      _starting = false;
    }
  }

  // ------------------------------------------------------------ camera scan

  Future<void> _onDetect(BarcodeCapture capture) async {
    // _scanError != null: a late frame arriving after an error was shown.
    if (_handling || _scanError != null) return;
    String? raw;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        raw = value;
        break;
      }
    }
    if (raw == null) return;

    _handling = true; // synchronous: blocks every later callback
    setState(() => _scanError = null);
    await _controller.stop();
    if (!mounted) return;

    final visitorId = parseVisitorId(raw);
    if (visitorId == null) {
      _showScanError(_notVisitorPassMessage);
      return;
    }
    await _openVisitor(visitorId);
  }

  // ----------------------------------------------------------- image upload

  Future<void> _pickImage() async {
    if (_handling) return;
    _handling = true; // synchronous guard, same as the camera path
    setState(() => _scanError = null);
    await _controller.stop();
    if (!mounted) return;

    final XFile? file;
    try {
      file = await _picker.pickImage(source: ImageSource.gallery);
    } on Exception {
      // PlatformException, or MissingPluginException when the app was not
      // fully rebuilt after the plugin was added. Never leave the scanner
      // stuck with the camera stopped.
      _showScanError(
        "Couldn't open the photo gallery. Fully stop and rebuild the app, "
        'then try again.',
      );
      return;
    }
    if (!mounted) return;

    if (file == null) {
      // Picker closed without a choice: not an error, go back to scanning.
      _resumeScanning();
      return;
    }

    final result = await _imageScanService.scan(file.path);
    if (!mounted) return;

    switch (result) {
      case QrImageVisitorFound(:final visitorId):
        await _openVisitor(visitorId);
      case QrImageNoCodeFound():
        _showScanError(
          'No QR code was found in that image. Choose a clear, uncropped '
          'picture of the visitor pass.',
        );
      case QrImageNotVisitorPass():
        _showScanError(_notVisitorPassMessage);
      case QrImageUnreadable():
        _showScanError("That image couldn't be read. Try a different one.");
    }
  }

  // ------------------------------------------------------------ shared path

  Future<void> _openVisitor(String visitorId) async {
    final result = await context.read<VisitorsCubit>().lookup(visitorId);
    if (!mounted) return;
    if (!result.isSuccess) {
      _showScanError(result.error ?? "Couldn't look up this visitor.");
      return;
    }

    await AppRouter.openDetails(context, result.data!.id);
    // Back from details: ready for the next visitor.
    if (mounted) _resumeScanning();
  }

  /// Shows [message] and leaves the camera stopped until the user acts.
  void _showScanError(String message) {
    if (!mounted) return;
    setState(() {
      _scanError = message;
      _handling = false;
    });
  }

  void _resumeScanning() {
    setState(() {
      _scanError = null;
      _handling = false;
    });
    unawaited(_startCamera());
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan visitor QR'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        // The theme defaults to dark status-bar icons; this bar is black.
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: ValueListenableBuilder<MobileScannerState>(
        valueListenable: _controller,
        builder: (context, value, _) {
          final cameraError = _cameraError ?? value.error;
          if (cameraError != null) {
            return _CameraProblem(
              error: cameraError,
              message: _scanError,
              isBusy: _handling,
              onRetry: _resumeScanning,
              onUploadImage: _pickImage,
            );
          }
          return _buildScanner();
        },
      ),
    );
  }

  Widget _buildScanner() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        IgnorePointer(
          child: Center(
            child: Container(
              width: _frameSize,
              height: _frameSize,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _scanError == null ? Colors.white : Colors.redAccent,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_scanError != null)
                    _ScanErrorPanel(
                      message: _scanError!,
                      onScanAgain: _resumeScanning,
                    )
                  else if (_handling)
                    const _HintPill(
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  else
                    const _HintPill(
                      child: Text(
                        "Point the camera at a visitor's QR code",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 12),
                  _UploadButton(onPressed: _handling ? null : _pickImage),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UploadButton extends StatelessWidget {
  const _UploadButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.photo_library_outlined),
      label: const Text('Upload QR image'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white38,
        side: BorderSide(
          color: onPressed == null ? Colors.white24 : Colors.white70,
        ),
      ),
    );
  }
}

class _HintPill extends StatelessWidget {
  const _HintPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: 30,
      blur: 24,
      tint: Colors.black,
      tintAlpha: 0.3,
      rimAlpha: 0.35,
      elevated: false,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        child: child,
      ),
    );
  }
}

class _ScanErrorPanel extends StatelessWidget {
  const _ScanErrorPanel({required this.message, required this.onScanAgain});

  final String message;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassContainer(
      radius: 28,
      blur: 28,
      tintAlpha: 0.82,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onScanAgain,
            child: const Text('Scan again'),
          ),
        ],
      ),
    );
  }
}

/// Shown when the camera cannot start (permission denied, camera busy).
/// Uploading an image still works here, so the app stays usable.
class _CameraProblem extends StatelessWidget {
  const _CameraProblem({
    required this.error,
    required this.message,
    required this.isBusy,
    required this.onRetry,
    required this.onUploadImage,
  });

  final MobileScannerException error;
  final String? message;
  final bool isBusy;
  final VoidCallback onRetry;
  final VoidCallback onUploadImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return GlassBackground(
      child: SizedBox(
        width: double.infinity,
        child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  denied ? Icons.no_photography_outlined : Icons.videocam_off,
                  size: 48,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  denied
                      ? 'Camera access is turned off'
                      : "Camera isn't available",
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  denied
                      ? 'Visitor Desk needs the camera to read QR codes. Open '
                          'Android Settings → Apps → Visitor Desk → '
                          'Permissions, allow Camera, then try again. You can '
                          'also upload a QR image instead.'
                      : 'The camera could not be started. Close other apps '
                          'that are using it and try again, or upload a QR '
                          'image instead.',
                  textAlign: TextAlign.center,
                ),
                if (message != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 20,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          message!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: isBusy ? null : onUploadImage,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Upload QR image'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: isBusy ? null : onRetry,
                  child: const Text('Try camera again'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
