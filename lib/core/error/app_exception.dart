import 'dart:io';

import 'package:dio/dio.dart';

enum AppErrorType {
  network,
  timeout,
  notFound,
  server,
  malformedResponse,
  unknown,
}

/// Single error type surfaced by the data layer. Messages are written for
/// front-desk staff, so they can be shown as-is.
class AppException implements Exception {
  const AppException(this.type, this.message);

  final AppErrorType type;
  final String message;

  factory AppException.fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AppException(
          AppErrorType.timeout,
          'The server took too long to respond. Please try again.',
        );
      case DioExceptionType.connectionError:
        return const AppException(
          AppErrorType.network,
          "Can't reach the server. Check the internet connection and try again.",
        );
      case DioExceptionType.badCertificate:
        return const AppException(
          AppErrorType.network,
          'A secure connection to the server could not be established.',
        );
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        if (code == 404) {
          return const AppException(
            AppErrorType.notFound,
            'The requested record was not found.',
          );
        }
        if (code == 429) {
          return const AppException(
            AppErrorType.server,
            'Too many requests. Wait a moment and try again.',
          );
        }
        if (code != null && code >= 500) {
          return AppException(
            AppErrorType.server,
            'The server is having problems (HTTP $code). Try again shortly.',
          );
        }
        return AppException(
          AppErrorType.server,
          'The server rejected the request (HTTP ${code ?? 'unknown'}).',
        );
      case DioExceptionType.cancel:
        return const AppException(
          AppErrorType.unknown,
          'The request was cancelled.',
        );
      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          return const AppException(
            AppErrorType.network,
            "Can't reach the server. Check the internet connection and try again.",
          );
        }
        return const AppException(
          AppErrorType.unknown,
          'Something went wrong while contacting the server.',
        );
      case DioExceptionType.transformTimeout:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  @override
  String toString() => 'AppException($type): $message';
}
