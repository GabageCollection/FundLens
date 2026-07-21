import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/data_engine/engine_message.dart';
import 'package:fundlens_windows/data_engine/process_data_engine_client.dart';

final class FakeEngineProcess implements EngineProcessHandle {
  final StreamController<String> stdoutController = StreamController<String>();
  final StreamController<String> stderrController = StreamController<String>();
  final Completer<int> exitCompleter = Completer<int>();
  final List<String> written = <String>[];
  bool killed = false;

  @override
  Stream<String> get stdoutLines => stdoutController.stream;

  @override
  Stream<String> get stderrLines => stderrController.stream;

  @override
  Future<int> get exitFuture => exitCompleter.future;

  @override
  void writeLine(String line) => written.add(line);

  @override
  Future<void> kill() async {
    killed = true;
    exit(143);
  }

  void emit(String line) => stdoutController.add(line);

  void exit(int code) {
    if (!exitCompleter.isCompleted) exitCompleter.complete(code);
  }
}

final class FakeProcessAdapter implements ProcessAdapter {
  final List<FakeEngineProcess> processes = <FakeEngineProcess>[];

  @override
  Future<EngineProcessHandle> start() async {
    final process = FakeEngineProcess();
    processes.add(process);
    return process;
  }
}

Future<void> flush() => pumpEventQueue();

void main() {
  late FakeProcessAdapter adapter;
  late ProcessDataEngineClient client;

  setUp(() {
    adapter = FakeProcessAdapter();
    client = ProcessDataEngineClient(adapter: adapter);
  });

  tearDown(() async {
    await client.close();
  });

  Map<String, Object?> lastRequest(FakeEngineProcess process) =>
      jsonDecode(process.written.last) as Map<String, Object?>;

  test('writes one compact JSON line and correlates success by id', () async {
    final future = client.call('health.check', const {});
    await flush();
    final process = adapter.processes.single;
    expect(process.written, hasLength(1));
    final request = lastRequest(process);
    expect(request.keys, unorderedEquals(['jsonrpc', 'id', 'method', 'params', 'schema_version']));
    expect(request['jsonrpc'], '2.0');
    expect(request['method'], 'health.check');
    expect(request['schema_version'], 1);
    expect(process.written.single, isNot(contains('\n')));
    // Compact JSON: no spaces after separators.
    expect(process.written.single, isNot(contains(': ')));

    process.emit(jsonEncode({
      'jsonrpc': '2.0',
      'id': request['id'],
      'result': {'status': 'ok', 'engine_version': '0.1.0'},
      'schema_version': 1,
    }));
    expect(await future, {'status': 'ok', 'engine_version': '0.1.0'});
  });

  test('engine error response becomes DataEngineException', () async {
    final future = client.call('health.check', const {});
    await flush();
    final request = lastRequest(adapter.processes.single);
    adapter.processes.single.emit(jsonEncode({
      'jsonrpc': '2.0',
      'id': request['id'],
      'error': {
        'code': 'protocol.method_not_found',
        'message': 'Request rejected',
        'retryable': false,
        'details': <String, Object?>{},
      },
      'schema_version': 1,
    }));
    await expectLater(
      future,
      throwsA(isA<DataEngineException>()
          .having((e) => e.code, 'code', 'protocol.method_not_found')
          .having((e) => e.retryable, 'retryable', isFalse)),
    );
  });

  test('malformed stdout fails only the active request and isolates the rest', () async {
    final first = client.call('health.check', const {});
    await flush();
    adapter.processes.single.emit('this is not json');
    await expectLater(
      first,
      throwsA(isA<DataEngineException>()
          .having((e) => e.code, 'code', 'protocol.invalid_response')),
    );

    // The child is still usable; a later call succeeds on the same process.
    final second = client.call('health.check', const {});
    await flush();
    expect(adapter.processes, hasLength(1));
    final request = lastRequest(adapter.processes.single);
    adapter.processes.single.emit(jsonEncode({
      'jsonrpc': '2.0',
      'id': request['id'],
      'result': {'status': 'ok', 'engine_version': '0.1.0'},
      'schema_version': 1,
    }));
    expect(await second, {'status': 'ok', 'engine_version': '0.1.0'});
  });

  test('rejects responses with schema_version other than 1', () async {
    final future = client.call('health.check', const {});
    await flush();
    final request = lastRequest(adapter.processes.single);
    adapter.processes.single.emit(jsonEncode({
      'jsonrpc': '2.0',
      'id': request['id'],
      'result': <String, Object?>{},
      'schema_version': 99,
    }));
    await expectLater(
      future,
      throwsA(isA<DataEngineException>()
          .having((e) => e.code, 'code', 'protocol.version_unsupported')),
    );
  });

  test('unexpected exit fails active and queued requests', () async {
    final first = client.call('health.check', const {});
    final second = client.call('health.check', const {});
    await flush();
    adapter.processes.single.exit(1);
    await expectLater(
      first,
      throwsA(isA<DataEngineException>().having((e) => e.code, 'code', 'engine.exited')),
    );
    await expectLater(
      second,
      throwsA(isA<DataEngineException>().having((e) => e.code, 'code', 'engine.exited')),
    );
  });

  test('restarts at most once after unexpected exits', () async {
    final first = client.call('health.check', const {});
    await flush();
    adapter.processes.single.exit(1);
    await expectLater(first, throwsA(isA<DataEngineException>()));

    // First restart is allowed.
    final second = client.call('health.check', const {});
    await flush();
    expect(adapter.processes, hasLength(2));
    final request = lastRequest(adapter.processes[1]);
    adapter.processes[1].emit(jsonEncode({
      'jsonrpc': '2.0',
      'id': request['id'],
      'result': {'status': 'ok', 'engine_version': '0.1.0'},
      'schema_version': 1,
    }));
    expect(await second, isNotNull);

    // Second unexpected exit exhausts the restart budget.
    final third = client.call('health.check', const {});
    await flush();
    adapter.processes[1].exit(1);
    await expectLater(third, throwsA(isA<DataEngineException>()));

    await expectLater(
      client.call('health.check', const {}),
      throwsA(isA<DataEngineException>()
          .having((e) => e.code, 'code', 'engine.restart_exhausted')),
    );
    expect(adapter.processes, hasLength(2));
  });

  test('cancel removes a queued request without touching the active one', () async {
    final first = client.call('health.check', const {});
    final second = client.call('health.check', const {});
    await flush();
    final process = adapter.processes.single;
    final firstId = jsonDecode(process.written[0]) as Map<String, Object?>;

    await client.cancel('unknown-id'); // no-op
    final queuedId = await client.debugQueuedIds().then((ids) => ids.single);
    final expectation = expectLater(
      second,
      throwsA(isA<DataEngineException>().having((e) => e.code, 'code', 'engine.cancelled')),
    );
    await client.cancel(queuedId);
    await expectation;

    process.emit(jsonEncode({
      'jsonrpc': '2.0',
      'id': firstId['id'],
      'result': {'status': 'ok', 'engine_version': '0.1.0'},
      'schema_version': 1,
    }));
    expect(await first, isNotNull);
    expect(process.killed, isFalse);
  });

  test('cancel of the active request kills the child and is not counted as a crash', () async {
    final first = client.call('health.check', const {});
    await flush();
    final process = adapter.processes.single;
    final activeId = (jsonDecode(process.written.single) as Map<String, Object?>)['id'] as String;

    final expectation = expectLater(
      first,
      throwsA(isA<DataEngineException>().having((e) => e.code, 'code', 'engine.cancelled')),
    );
    await client.cancel(activeId);
    await expectation;
    expect(process.killed, isTrue);
    await flush();

    // Next call starts a fresh child without consuming the crash-restart budget.
    final second = client.call('health.check', const {});
    await flush();
    expect(adapter.processes, hasLength(2));
    final request = lastRequest(adapter.processes[1]);
    adapter.processes[1].emit(jsonEncode({
      'jsonrpc': '2.0',
      'id': request['id'],
      'result': {'status': 'ok', 'engine_version': '0.1.0'},
      'schema_version': 1,
    }));
    expect(await second, isNotNull);

    // A real crash afterwards still gets its one restart.
    final third = client.call('health.check', const {});
    await flush();
    adapter.processes[1].exit(1);
    await expectLater(third, throwsA(isA<DataEngineException>()));
    final fourth = client.call('health.check', const {});
    await flush();
    expect(adapter.processes, hasLength(3));
    final request4 = lastRequest(adapter.processes[2]);
    adapter.processes[2].emit(jsonEncode({
      'jsonrpc': '2.0',
      'id': request4['id'],
      'result': {'status': 'ok', 'engine_version': '0.1.0'},
      'schema_version': 1,
    }));
    expect(await fourth, isNotNull);
  });

  test('timeout kills the child and fails the request', () async {
    final future = client.call('health.check', const {},
        timeout: const Duration(milliseconds: 50));
    await flush();
    await expectLater(
      future,
      throwsA(isA<DataEngineException>().having((e) => e.code, 'code', 'engine.timeout')),
    );
    expect(adapter.processes.single.killed, isTrue);

    final second = client.call('health.check', const {});
    await flush();
    expect(adapter.processes, hasLength(2));
    final request = lastRequest(adapter.processes[1]);
    adapter.processes[1].emit(jsonEncode({
      'jsonrpc': '2.0',
      'id': request['id'],
      'result': {'status': 'ok', 'engine_version': '0.1.0'},
      'schema_version': 1,
    }));
    expect(await second, isNotNull);
  });

  test('stderr lines are redacted before logging', () async {
    final logged = <String>[];
    final loggingClient = ProcessDataEngineClient(adapter: adapter, stderrLogger: logged.add);
    addTearDown(loggingClient.close);

    final future = loggingClient.call('health.check', const {});
    await flush();
    adapter.processes.single.stderrController.add('auth token=abc123 password=hunter2 ok');
    await flush();
    expect(logged.single, 'auth token=<redacted> password=<redacted> ok');

    final request = lastRequest(adapter.processes.single);
    adapter.processes.single.emit(jsonEncode({
      'jsonrpc': '2.0',
      'id': request['id'],
      'result': {'status': 'ok', 'engine_version': '0.1.0'},
      'schema_version': 1,
    }));
    expect(await future, isNotNull);
  });
}
