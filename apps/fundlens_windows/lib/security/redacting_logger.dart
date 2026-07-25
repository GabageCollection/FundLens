import 'dart:convert';

/// Structured logger that can only emit registered event schemas.
///
/// Sensitive keys are always replaced with `"[REDACTED]"`; fields not
/// declared in the event schema are dropped rather than logged, so an
/// accidental `holdings` or `ocr_text` dump can never reach a log line.
final class RedactingLogger {
  RedactingLogger({required Map<String, Set<String>> schemas})
      : _schemas = Map.unmodifiable(schemas);

  /// Keys whose values are always replaced with `[REDACTED]`.
  static const alwaysRedactedKeys = {
    'amount',
    'value',
    'profit',
    'ocr_text',
    'screenshot',
    'database_key',
    'backup_password',
    'password',
  };

  static const redacted = '[REDACTED]';

  final Map<String, Set<String>> _schemas;

  /// Formats [eventCode] with [fields] as a single-line JSON event.
  ///
  /// Throws [ArgumentError] for unregistered event codes. Registered
  /// non-sensitive fields pass through; always-redacted keys are kept but
  /// replaced; every other field is dropped.
  String format(String eventCode, Map<String, Object?> fields) {
    final allowed = _schemas[eventCode];
    if (allowed == null) {
      throw ArgumentError.value(
        eventCode,
        'eventCode',
        'unregistered log event',
      );
    }
    final safe = <String, Object?>{};
    for (final entry in fields.entries) {
      if (alwaysRedactedKeys.contains(entry.key)) {
        safe[entry.key] = redacted;
      } else if (allowed.contains(entry.key)) {
        safe[entry.key] = entry.value;
      }
      // Unknown fields default to redacted: they are not included at all.
    }
    return jsonEncode({'event': eventCode, 'fields': safe});
  }
}
