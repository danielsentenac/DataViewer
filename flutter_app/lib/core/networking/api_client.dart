import 'package:dataviewer/core/config/app_config.dart';
import 'package:dataviewer/core/networking/api_exception.dart';
import 'package:dataviewer/core/networking/tomcat_session_store.dart';
import 'package:dio/dio.dart';

class ApiClient {
  ApiClient(
    AppConfig config, {
    TomcatSessionStore? sessionStore,
  })  : _sessionStore = sessionStore,
        _dio = Dio(
          BaseOptions(
            baseUrl: _normalizeBaseUrl(config.baseUrl),
            connectTimeout: config.connectTimeout,
            receiveTimeout: config.receiveTimeout,
            contentType: 'application/json',
            responseType: ResponseType.json,
            headers: const <String, String>{'accept-encoding': 'gzip'},
          ),
        ) {
    if (_sessionStore != null) {
      _dio.interceptors.add(_TomcatSessionInterceptor(_sessionStore));
    }
  }

  final Dio _dio;
  final TomcatSessionStore? _sessionStore;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        _normalizePath(path),
        queryParameters: _compactMap(queryParameters),
      );
      return _expectMap(response.data, path);
    } on DioException catch (error) {
      throw _mapDioException(error, path);
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> data,
  }) async {
    try {
      final response =
          await _dio.post<Object?>(_normalizePath(path), data: data);
      return _expectMap(response.data, path);
    } on DioException catch (error) {
      throw _mapDioException(error, path);
    }
  }

  void close() {
    _dio.close(force: true);
  }

  Map<String, dynamic> _expectMap(Object? data, String path) {
    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    throw ApiException(path: path, message: 'Expected a JSON object response.');
  }

  Map<String, dynamic>? _compactMap(Map<String, dynamic>? value) {
    if (value == null) {
      return null;
    }

    return Map<String, dynamic>.fromEntries(
      value.entries.where((entry) => entry.value != null),
    );
  }

  static String _normalizeBaseUrl(String value) {
    return value.endsWith('/') ? value : '$value/';
  }

  static String _normalizePath(String value) {
    return value.startsWith('/') ? value.substring(1) : value;
  }

  ApiException _mapDioException(DioException error, String path) {
    final responseData = error.response?.data;
    String? message;

    if (responseData is Map && responseData['error'] is Map) {
      final errorMap = Map<String, dynamic>.from(responseData['error'] as Map);
      message = errorMap['message'] as String?;
    }

    return ApiException(
      path: path,
      statusCode: error.response?.statusCode,
      message: message ?? error.message ?? 'Unknown HTTP failure.',
    );
  }
}

class _TomcatSessionInterceptor extends Interceptor {
  _TomcatSessionInterceptor(this._sessionStore);

  final TomcatSessionStore _sessionStore;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _sessionStore.applyToRequest(options);
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _sessionStore.captureFromResponse(response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _sessionStore.captureFromResponse(err.response);
    handler.next(err);
  }
}
