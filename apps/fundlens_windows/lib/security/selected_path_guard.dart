import 'package:path/path.dart' as p;

/// Canonicalizes user-selected file paths before they are sent to the
/// Python engine, so the engine's allowlist comparison sees one exact
/// spelling per file (no `.`/`..` segments, consistent separators).
final class SelectedPathGuard {
  const SelectedPathGuard();

  /// Returns the canonical absolute form of [path].
  ///
  /// The canonicalization is lexical; it does not require the file to
  /// exist and never follows symlinks (the engine rejects symlink escapes
  /// on its side). Throws [ArgumentError] for empty paths.
  String canonicalize(String path) {
    if (path.trim().isEmpty) {
      throw ArgumentError.value(path, 'path', 'must not be empty');
    }
    return p.canonicalize(path);
  }

  /// Canonicalizes every selected path, preserving order.
  List<String> canonicalizeAll(Iterable<String> paths) =>
      [for (final path in paths) canonicalize(path)];
}
