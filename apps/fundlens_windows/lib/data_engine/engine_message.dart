import 'dart:convert';

/// Structured error raised for every engine-side or protocol-side failure.
final class DataEngineException implements Exception {
  const DataEngineException(
    this.code,
    this.message, {
    this.retryable = false,
    this.details = const <String, Object?>{},
  });

  final String code;
  final String message;
  final bool retryable;
  final Map<String, Object?> details;

  @override
  String toString() => 'DataEngineException($code: $message)';
}

/// Builds the protocol-v1 request envelope.
Map<String, Object?> buildRequest({
  required String id,
  required String method,
  required Map<String, Object?> params,
}) {
  return <String, Object?>{
    'jsonrpc': '2.0',
    'id': id,
    'method': method,
    'params': params,
    'schema_version': 1,
  };
}

/// Encodes a request as one compact JSON line (no newline appended).
String encodeRequestLine({
  required String id,
  required String method,
  required Map<String, Object?> params,
}) =>
    jsonEncode(buildRequest(id: id, method: method, params: params));

/// Decodes one stdout line into a response envelope.
///
/// Throws [DataEngineException] with `protocol.invalid_response` when the line
/// is not a JSON object, and with `protocol.version_unsupported` when the
/// envelope declares a `schema_version` other than 1.
Map<String, Object?> decodeResponseLine(String line) {
  final Object? decoded;
  try {
    decoded = jsonDecode(line);
  } on FormatException {
    throw const DataEngineException(
      'protocol.invalid_response',
      'Engine emitted a malformed stdout line',
    );
  }
  if (decoded is! Map<String, Object?>) {
    throw const DataEngineException(
      'protocol.invalid_response',
      'Engine emitted a non-object stdout line',
    );
  }
  if (decoded['schema_version'] != 1) {
    throw const DataEngineException(
      'protocol.version_unsupported',
      'Engine response uses an unsupported schema version',
    );
  }
  return decoded;
}

/// Converts an engine error envelope into a [DataEngineException].
DataEngineException exceptionFromErrorEnvelope(Map<String, Object?> response) {
  final error = response['error'];
  if (error is! Map<String, Object?>) {
    return const DataEngineException(
      'protocol.invalid_response',
      'Engine error envelope is malformed',
    );
  }
  return DataEngineException(
    error['code'] as String? ?? 'engine.unknown_error',
    error['message'] as String? ?? 'Engine request failed',
    retryable: error['retryable'] as bool? ?? false,
    details: error['details'] as Map<String, Object?>? ?? const <String, Object?>{},
  );
}

final RegExp _secretPattern = RegExp(
  r'\b(token|password|secret|api[_-]?key)=([^\s]+)',
  caseSensitive: false,
);

/// Masks `key=value` secrets in engine stderr before they reach any log sink.
String redactStderrLine(String line) => line.replaceAllMapped(
      _secretPattern,
      (match) => '${match[1]}=<redacted>',
    );
