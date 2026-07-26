enum AiErrorKind {
  invalidConfiguration,
  authentication,
  endpoint,
  model,
  quota,
  timeout,
  network,
  server,
  invalidResponse,
  cancelled,
}

class AiException implements Exception {
  const AiException(this.kind, this.message, {this.statusCode});

  final AiErrorKind kind;
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
