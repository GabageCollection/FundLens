import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'data_engine_client.dart';
import 'engine_message.dart';

/// Handle for one running engine child process.
abstract interface class EngineProcessHandle {
  /// Line-delimited JSON-RPC responses from the child.
  Stream<String> get stdoutLines;

  /// Diagnostic output from the child; must be redacted before logging.
  Stream<String> get stderrLines;

  /// Completes with the exit code when the child terminates.
  Future<int> get exitFuture;

  /// Writes one compact JSON line to the child's stdin.
  void writeLine(String line);

  /// Terminates the child.
  Future<void> kill();
}

/// Starts supervised engine child processes. Injectable for tests.
abstract interface class ProcessAdapter {
  Future<EngineProcessHandle> start();
}

final class _PendingRequest {
  _PendingRequest({required this.id, required this.method, required this.params});

  final String id;
  final String method;
  final Map<String, Object?> params;
  final Completer<Map<String, Object?>> completer = Completer<Map<String, Object?>>();
  Timer? timer;
}

/// Supervised [DataEngineClient] speaking line-delimited JSON-RPC over stdio.
///
/// Calls are serialized through a single active-request queue. On unexpected
/// child exit all pending calls fail and the next call restarts the child at
/// most once. User cancellation and timeouts terminate the child but do not
/// consume the restart budget.
final class ProcessDataEngineClient implements DataEngineClient {
  ProcessDataEngineClient({
    required this.adapter,
    Uuid? uuid,
    this.stderrLogger,
  }) : _uuid = uuid ?? const Uuid();

  /// Starts supervised engine child processes.
  final ProcessAdapter adapter;
  final Uuid _uuid;

  /// Sink for redacted engine stderr lines; null disables stderr logging.
  final void Function(String line)? stderrLogger;

  final List<_PendingRequest> _queue = <_PendingRequest>[];
  _PendingRequest? _active;
  EngineProcessHandle? _child;
  bool _closed = false;
  bool _restartAvailable = true;
  bool _lastExitUnexpected = false;

  @override
  Future<Map<String, Object?>> call(
    String method,
    Map<String, Object?> params, {
    Duration timeout = const Duration(seconds: 30),
  }) {
    if (_closed) {
      return Future<Map<String, Object?>>.error(
        const DataEngineException('engine.closed', 'Data engine client is closed'),
      );
    }
    final request = _PendingRequest(id: _uuid.v4(), method: method, params: params);
    request.timer = Timer(timeout, () => _abortActive(
          request,
          const DataEngineException('engine.timeout', 'Engine request timed out'),
        ));
    _queue.add(request);
    unawaited(_pump());
    return request.completer.future;
  }

  @override
  Future<void> cancel(String requestId) async {
    final queuedIndex = _queue.indexWhere((r) => r.id == requestId);
    if (queuedIndex >= 0) {
      final request = _queue.removeAt(queuedIndex);
      _fail(request,
          const DataEngineException('engine.cancelled', 'Request cancelled by caller'));
      return;
    }
    final active = _active;
    if (active != null && active.id == requestId) {
      _abortActive(
        active,
        const DataEngineException('engine.cancelled', 'Request cancelled by caller'),
      );
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final child = _child;
    _child = null;
    final active = _active;
    _active = null;
    active?.timer?.cancel();
    const error = DataEngineException('engine.closed', 'Data engine client is closed');
    if (active != null && !active.completer.isCompleted) {
      active.completer.completeError(error);
    }
    for (final request in _queue) {
      _fail(request, error);
    }
    _queue.clear();
    await child?.kill();
  }

  /// Ids of requests still waiting in the queue. Test support only.
  @visibleForTesting
  Future<List<String>> debugQueuedIds() async =>
      _queue.map((request) => request.id).toList(growable: false);

  void _fail(_PendingRequest request, DataEngineException error) {
    request.timer?.cancel();
    if (!request.completer.isCompleted) {
      request.completer.completeError(error);
    }
  }

  Future<void> _pump() async {
    if (_closed || _active != null || _queue.isEmpty) return;
    final request = _queue.removeAt(0);
    _active = request; // mark active before awaiting to serialize concurrent pumps
    final EngineProcessHandle child;
    try {
      child = await _ensureChild();
    } on DataEngineException catch (error) {
      _active = null;
      _fail(request, error);
      unawaited(_pump());
      return;
    }
    child.writeLine(encodeRequestLine(
      id: request.id,
      method: request.method,
      params: request.params,
    ));
  }

  Future<EngineProcessHandle> _ensureChild() async {
    final existing = _child;
    if (existing != null) return existing;
    if (_lastExitUnexpected) {
      if (!_restartAvailable) {
        throw const DataEngineException(
          'engine.restart_exhausted',
          'Engine crashed again after its one controlled restart',
        );
      }
      _restartAvailable = false;
      _lastExitUnexpected = false;
    }
    final child = await adapter.start();
    _child = child;
    child.stdoutLines.listen(
      (line) => _onStdoutLine(child, line),
      onError: (Object _) {}, // stream errors surface through exitFuture
    );
    child.stderrLines.listen((line) => stderrLogger?.call(redactStderrLine(line)));
    unawaited(child.exitFuture.then((code) => _onExit(child, code)));
    return child;
  }

  void _onStdoutLine(EngineProcessHandle child, String line) {
    if (!identical(child, _child)) return;
    final active = _active;
    if (active == null) return;
    final Map<String, Object?> response;
    try {
      response = decodeResponseLine(line);
    } on DataEngineException catch (error) {
      _finishActive(active, error: error);
      unawaited(_pump());
      return;
    }
    if (response['id'] != active.id) {
      _finishActive(
        active,
        error: const DataEngineException(
          'protocol.invalid_response',
          'Engine response id does not match the active request',
        ),
      );
      unawaited(_pump());
      return;
    }
    if (response.containsKey('error')) {
      _finishActive(active, error: exceptionFromErrorEnvelope(response));
    } else {
      final result = response['result'];
      _finishActive(
        active,
        result: result is Map<String, Object?> ? result : <String, Object?>{'value': result},
      );
    }
    unawaited(_pump());
  }

  void _finishActive(
    _PendingRequest request, {
    Map<String, Object?>? result,
    DataEngineException? error,
  }) {
    if (!identical(_active, request)) return;
    _active = null;
    request.timer?.cancel();
    if (request.completer.isCompleted) return;
    if (error != null) {
      request.completer.completeError(error);
    } else {
      request.completer.complete(result);
    }
  }

  /// Terminates the child for a user-driven abort (cancel/timeout). This is
  /// not a crash: the restart budget is untouched and the next call starts a
  /// fresh child.
  void _abortActive(_PendingRequest request, DataEngineException error) {
    if (!identical(_active, request)) return;
    final child = _child;
    _active = null;
    _child = null;
    _fail(request, error);
    if (child != null) unawaited(child.kill());
    unawaited(_pump());
  }

  void _onExit(EngineProcessHandle child, int code) {
    if (!identical(child, _child)) return; // deliberate kill or stale process
    _child = null;
    _lastExitUnexpected = true;
    final error = DataEngineException(
      'engine.exited',
      'Engine process exited unexpectedly with code $code',
    );
    final active = _active;
    _active = null;
    if (active != null) _fail(active, error);
    for (final request in _queue) {
      _fail(request, error);
    }
    _queue.clear();
  }
}
