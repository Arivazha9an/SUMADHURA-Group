import 'dart:async';
import 'dart:io';

import '../config/api_config.dart';

/// Answers one question: can this device reach the API right now?
abstract class ConnectivityChecker {
  Future<bool> isReachable();
}

/// Tries to open a TCP connection to the API host.
///
/// This checks what actually matters to the app. Being "connected to Wi-Fi"
/// does not mean the internet works (captive portals, no data), and a
/// network-type plugin cannot tell the difference. No extra package or
/// permission is needed beyond INTERNET.
class SocketConnectivityChecker implements ConnectivityChecker {
  const SocketConnectivityChecker({
    required this.host,
    required this.port,
    this.timeout = const Duration(seconds: 3),
  });

  /// Targets the host of [ApiConfig.baseUrl] (port 443 for https, 80 for http).
  factory SocketConnectivityChecker.forApi() {
    final uri = Uri.parse(ApiConfig.baseUrl);
    final port = uri.hasPort ? uri.port : (uri.scheme == 'http' ? 80 : 443);
    return SocketConnectivityChecker(host: uri.host, port: port);
  }

  final String host;
  final int port;
  final Duration timeout;

  @override
  Future<bool> isReachable() async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.destroy();
      return true;
    } on IOException {
      // SocketException (no route, DNS failure, timeout) is an IOException.
      return false;
    } on TimeoutException {
      return false;
    }
  }
}
