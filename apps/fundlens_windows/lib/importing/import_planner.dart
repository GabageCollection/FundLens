import 'package:fundlens_core/fundlens_core.dart';
import 'package:uuid/uuid.dart';

import 'import_models.dart';

/// Builds an [ImportPlan] by matching incoming draft holdings against the
/// current repository state.
///
/// Matching order per draft row:
/// 1. same platform + exact product code,
/// 2. same platform + normalized name + instrument type,
/// 3. insert.
///
/// A name-only ambiguity (multiple same-platform holdings share the
/// normalized name and the instrument type cannot disambiguate) produces a
/// blocking issue and the row is neither updated nor inserted.
///
/// In [ImportMode.full], unmatched same-platform holdings are proposed for
/// removal; other platforms are never touched. [ImportMode.partial] — the
/// default — never proposes removals.
final class ImportPlanner {
  ImportPlanner({String Function()? idGenerator, DateTime Function()? clock})
      : _idGenerator = idGenerator ?? const Uuid().v4,
        _clock = clock ?? DateTime.now;

  final String Function() _idGenerator;
  final DateTime Function() _clock;

  ImportPlan plan({
    ImportMode mode = ImportMode.partial,
    required SourcePlatform platform,
    required List<Holding> current,
    required List<DraftHolding> incoming,
    Map<int, DuplicateResolution> resolutions = const {},
  }) {
    final inserts = <Holding>[];
    final updates = <Holding>[];
    final issues = <DataIssue>[];
    final skipped = <DraftHolding>[];
    final matchedIds = <String>{};

    final samePlatform =
        current.where((h) => h.sourcePlatform == platform).toList();

    for (var i = 0; i < incoming.length; i++) {
      final draft = incoming[i];
      final resolution =
          resolutions[i] ?? DuplicateResolution.overwrite;
      if (resolution == DuplicateResolution.skip) {
        skipped.add(draft);
        continue;
      }

      // 1. Same platform + exact product code.
      Holding? match;
      final code = draft.productCode;
      if (code != null && code.isNotEmpty) {
        final codeMatches = samePlatform
            .where((h) => h.productCode == code && !matchedIds.contains(h.id))
            .toList();
        if (codeMatches.length == 1) {
          match = codeMatches.single;
        } else if (codeMatches.length > 1) {
          issues.add(
            DataIssue(
              code: 'import.ambiguous_code',
              field: 'productCode',
              severity: IssueSeverity.blocking,
              message: '产品代码 $code 在同平台对应多条持仓',
              holdingIndex: i,
            ),
          );
          continue;
        }
      }

      // 2. Same platform + normalized name + instrument type.
      if (match == null) {
        final normalized = normalizeProductName(draft.productName);
        final nameMatches = samePlatform
            .where(
              (h) =>
                  normalizeProductName(h.productName) == normalized &&
                  !matchedIds.contains(h.id),
            )
            .toList();
        if (nameMatches.isNotEmpty) {
          final typed = nameMatches
              .where((h) => h.instrumentType == draft.instrumentType)
              .toList();
          if (typed.length == 1) {
            match = typed.single;
          } else if (nameMatches.length > 1) {
            issues.add(
              DataIssue(
                code: 'import.ambiguous_name',
                field: 'productName',
                severity: IssueSeverity.blocking,
                message: '产品名称 ${draft.productName} 在同平台存在多条同名持仓，无法确定匹配',
                holdingIndex: i,
              ),
            );
            continue;
          }
        }
      }

      if (match != null) {
        switch (resolution) {
          case DuplicateResolution.merge:
            matchedIds.add(match.id);
            updates.add(_mergedHolding(draft, match));
          case DuplicateResolution.overwrite:
            matchedIds.add(match.id);
            updates.add(
              _toHolding(draft, id: match.id, createdAt: match.createdAt),
            );
          case DuplicateResolution.keepBoth:
            // The existing holding is left untouched and the incoming row is
            // written as a new holding, so match.id must NOT be claimed.
            inserts.add(_toHolding(draft, id: _idGenerator()));
          case DuplicateResolution.skip:
            // Handled above; kept for exhaustiveness.
            break;
        }
      } else {
        inserts.add(_toHolding(draft, id: _idGenerator()));
      }
    }

    final removeIds = <String>[];
    final unchangedIds = <String>[];
    for (final holding in current) {
      if (matchedIds.contains(holding.id)) continue;
      if (mode == ImportMode.full && holding.sourcePlatform == platform) {
        removeIds.add(holding.id);
      } else {
        unchangedIds.add(holding.id);
      }
    }

    return ImportPlan(
      inserts: inserts,
      updates: updates,
      removeIds: removeIds,
      unchangedIds: unchangedIds,
      issues: issues,
      skipped: skipped,
    );
  }

  /// Merges an incoming draft into an existing holding by summing amounts,
  /// shares and profits. Sums only where both sides carry a value; a null on
  /// either side keeps the other. Unit-price fields stay on the existing
  /// side because a blended price is not well defined.
  Holding _mergedHolding(DraftHolding draft, Holding existing) {
    DecimalValue? sum(DecimalValue? a, DecimalValue? b) {
      if (a == null) return b;
      if (b == null) return a;
      return a + b;
    }

    final now = _clock();
    return Holding(
      id: existing.id,
      sourcePlatform: existing.sourcePlatform,
      instrumentType: existing.instrumentType,
      assetClass: existing.assetClass,
      productName: existing.productName,
      productCode: existing.productCode ?? draft.productCode,
      currency: existing.currency,
      quantity: sum(existing.quantity, draft.quantity),
      currentPrice: existing.currentPrice,
      costPrice: existing.costPrice,
      currentValue: sum(existing.currentValue, draft.currentValue)!,
      costAmount: sum(existing.costAmount, draft.costAmount),
      holdingProfit: sum(existing.holdingProfit, draft.holdingProfit),
      cumulativeProfit: sum(
        existing.cumulativeProfit,
        draft.cumulativeProfit,
      ),
      platformTags: existing.platformTags,
      valuationMethod: existing.valuationMethod,
      dataOrigin: draft.dataOrigin,
      fieldProvenance: existing.fieldProvenance,
      note: existing.note,
      createdAt: existing.createdAt,
      updatedAt: now,
    );
  }

  Holding _toHolding(DraftHolding draft, {required String id, DateTime? createdAt}) {
    final now = _clock();
    return Holding(
      id: id,
      sourcePlatform: draft.sourcePlatform,
      instrumentType: draft.instrumentType,
      assetClass: draft.assetClass,
      productName: draft.productName,
      productCode: draft.productCode,
      currency: draft.currency,
      quantity: draft.quantity,
      currentPrice: draft.currentPrice,
      costPrice: draft.costPrice,
      currentValue: draft.currentValue,
      costAmount: draft.costAmount,
      holdingProfit: draft.holdingProfit,
      cumulativeProfit: draft.cumulativeProfit,
      platformTags: draft.platformTags,
      valuationMethod: ValuationMethod.manualAmount,
      dataOrigin: draft.dataOrigin,
      fieldProvenance: const {
        'currentValue': FieldProvenance(
          kind: ProvenanceKind.original,
          source: 'import',
        ),
      },
      note: draft.note,
      createdAt: createdAt ?? now,
      updatedAt: now,
    );
  }

  /// Normalizes a product name for matching: trims, collapses whitespace,
  /// converts full-width punctuation/letters/digits to half-width, and
  /// lowercases Latin letters. The original name is never modified in storage.
  static String normalizeProductName(String name) {
    final buffer = StringBuffer();
    for (final codeUnit in name.trim().codeUnits) {
      if (codeUnit == 0x3000) {
        buffer.write(' ');
      } else if (codeUnit >= 0xFF01 && codeUnit <= 0xFF5E) {
        buffer.writeCharCode(codeUnit - 0xFEE0);
      } else {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
