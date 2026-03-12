class ApiException implements Exception {
  const ApiException({
    required this.path,
    required this.message,
    this.statusCode,
  });

  final String path;
  final String message;
  final int? statusCode;

  @override
  String toString() {
    final code = statusCode == null ? '' : ' [$statusCode]';
    return 'ApiException$code $path: $message';
  }
}
