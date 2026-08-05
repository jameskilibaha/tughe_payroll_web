/// Thrown by [ApiClient]/[ApiService] whenever a backend call fails, whether
/// because of a network problem or an error response from FastAPI (which
/// replies with `{"detail": "..."}`).
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  /// Human readable message, safe to show directly in a snackbar/dialog.
  final String message;

  /// HTTP status code, when the failure came from a real response
  /// (null for network-level failures such as no connectivity).
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isNetworkError => statusCode == null;

  @override
  String toString() => message;
}
