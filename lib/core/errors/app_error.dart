/// Structured application error type.
///
/// Provides typed categories of errors that occur across providers and
/// features, making error handling and user-facing messages predictable.
sealed class AppError implements Exception {
  const AppError(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Raised when a network request fails.
final class NetworkError extends AppError {
  const NetworkError(super.message, {this.statusCode});
  final int? statusCode;
}

/// Raised when JSON or model parsing fails.
final class ParseError extends AppError {
  const ParseError(super.message, {this.cause});
  final Object? cause;
}

/// Raised when the requested resource is not found.
final class NotFoundError extends AppError {
  const NotFoundError(super.message);
}

/// Raised when a provider does not support a requested operation.
final class UnsupportedOperationError extends AppError {
  const UnsupportedOperationError(super.message);
}

/// Raised when no healthy API endpoint is available.
final class EndpointUnavailableError extends AppError {
  const EndpointUnavailableError(super.message);
}

/// Raised when authentication or authorisation is required.
final class AuthError extends AppError {
  const AuthError(super.message);
}

/// Generic / unexpected error.
final class UnknownError extends AppError {
  const UnknownError(super.message, {this.cause});
  final Object? cause;
}
