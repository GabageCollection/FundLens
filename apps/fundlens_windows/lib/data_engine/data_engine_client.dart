/// Client for the out-of-process FundLens data engine.
abstract interface class DataEngineClient {
  /// Calls [method] with [params] and returns the engine `result` object.
  ///
  /// Throws a `DataEngineException` for engine errors, protocol violations,
  /// timeouts, cancellation and process exits.
  Future<Map<String, Object?>> call(
    String method,
    Map<String, Object?> params, {
    Duration timeout = const Duration(seconds: 30),
  });

  /// Cancels the request with [requestId].
  ///
  /// A queued request is dropped immediately. Cancelling the active request
  /// terminates the child process; the next call starts a fresh child without
  /// consuming the crash-restart budget.
  Future<void> cancel(String requestId);

  /// Fails every pending request and terminates the child process.
  Future<void> close();
}
