enum ProvenanceKind { original, inferred, market, userCorrected }

final class FieldProvenance {
  const FieldProvenance({required this.kind, required this.source});
  final ProvenanceKind kind;
  final String source;
}
