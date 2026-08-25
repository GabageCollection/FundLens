import 'package:fundlens_core/fundlens_core.dart';

import '../../importing/import_models.dart';
import 'import_draft_persistence.dart';

/// Field edit outcome: either the updated draft, or a blocking issue for
/// an unparseable amount (which disables commit until corrected).
final class DraftFieldEditResult {
  const DraftFieldEditResult.updated(this.draft) : invalidAmountIssue = null;
  const DraftFieldEditResult.invalid(this.invalidAmountIssue) : draft = null;

  final ImportDraft? draft;
  final DataIssue? invalidAmountIssue;
}

/// Applies a user edit to one draft field. Pure with respect to external
/// state: the returned draft replaces the old one; issues attached to the
/// edited field are cleared on success.
DraftFieldEditResult applyDraftFieldEdit(
  ImportDraft draft,
  int holdingIndex,
  String field,
  String text,
) {
  if (holdingIndex < 0 || holdingIndex >= draft.holdings.length) {
    return DraftFieldEditResult.updated(draft);
  }
  final holding = draft.holdings[holdingIndex];

  DecimalValue? amount;
  if (amountFieldNames.contains(field)) {
    amount = parseImportAmount(text);
    if (amount == null) {
      return DraftFieldEditResult.invalid(
        DataIssue(
          code: 'import.invalid_amount',
          field: field,
          severity: IssueSeverity.blocking,
          message: '金额无法解析: $text',
          holdingIndex: holdingIndex,
        ),
      );
    }
  }

  final updated = DraftHolding(
    sourcePlatform: holding.sourcePlatform,
    productName: field == 'product_name' || field == 'productName'
        ? text
        : holding.productName,
    productCode: holding.productCode,
    instrumentType: holding.instrumentType,
    assetClass: holding.assetClass,
    currentValue: field == 'current_value' || field == 'currentValue'
        ? amount!
        : holding.currentValue,
    quantity: field == 'quantity' ? amount : holding.quantity,
    currentPrice: holding.currentPrice,
    costPrice: field == 'cost_price' || field == 'costPrice'
        ? amount
        : holding.costPrice,
    costAmount: holding.costAmount,
    holdingProfit: field == 'holding_profit' || field == 'holdingProfit'
        ? amount
        : holding.holdingProfit,
    cumulativeProfit: field == 'cumulative_profit' || field == 'cumulativeProfit'
        ? amount
        : holding.cumulativeProfit,
    currency: holding.currency,
    platformTags: holding.platformTags,
    note: holding.note,
    dataOrigin: holding.dataOrigin,
    metadata: holding.metadata,
  );

  replaceDraftFieldIssues(draft, holdingIndex, field, const []);
  return DraftFieldEditResult.updated(
    ImportDraft(
      holdings: [
        for (var i = 0; i < draft.holdings.length; i++)
          i == holdingIndex ? updated : draft.holdings[i],
      ],
      issues: draft.issues,
    ),
  );
}

/// Fields whose text edits are parsed as decimal amounts.
const amountFieldNames = {
  'current_value',
  'holding_profit',
  'cumulative_profit',
  'cost_price',
  'quantity',
  'currentValue',
  'holdingProfit',
  'cumulativeProfit',
  'costPrice',
};

/// Removes all issues attached to (holdingIndex, field) and appends
/// [replacement]. Mutates [draft.issues] in place, matching the draft's
/// shared-list semantics used across the import review flow.
void replaceDraftFieldIssues(
  ImportDraft draft,
  int holdingIndex,
  String field,
  List<DataIssue> replacement,
) {
  draft.issues
    ..removeWhere((i) => i.holdingIndex == holdingIndex && i.field == field)
    ..addAll(replacement);
}
