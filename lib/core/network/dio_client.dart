import 'package:dio/dio.dart';

import '../config/api_config.dart';

/// Builds the single Dio instance used by the repository.
Dio createDioClient({String? baseUrl}) {
  return Dio(
    BaseOptions(
      baseUrl: baseUrl ?? ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      sendTimeout: ApiConfig.sendTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: const {'Accept': 'application/json'},
      contentType: Headers.jsonContentType,
    ),
  );
}
