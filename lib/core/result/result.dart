/// Generic result type used throughout the app.
///
/// Use [Result.success] for successful operations and [Result.failure] for
/// errors, passing an [AppError] or a plain string message.
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(String message, {Object? error}) = Failure<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get valueOrNull => switch (this) {
        Success(:final value) => value,
        Failure() => null,
      };

  String? get errorMessage => switch (this) {
        Success() => null,
        Failure(:final message) => message,
      };

  /// Transforms the value if successful, otherwise propagates the failure.
  Result<U> map<U>(U Function(T value) transform) => switch (this) {
        Success(:final value) => Result.success(transform(value)),
        Failure(:final message, :final error) =>
          Result.failure(message, error: error),
      };

  /// Flat-maps the value if successful.
  Result<U> flatMap<U>(Result<U> Function(T value) transform) => switch (this) {
        Success(:final value) => transform(value),
        Failure(:final message, :final error) =>
          Result.failure(message, error: error),
      };

  /// Returns [value] on success, or [fallback] on failure.
  T getOrElse(T fallback) => switch (this) {
        Success(:final value) => value,
        Failure() => fallback,
      };
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.message, {this.error});
  final String message;
  final Object? error;
}
