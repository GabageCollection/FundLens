import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/app_dependencies.dart';
import '../../market/quote_refresh_service.dart';
import '../data_health/data_health_models.dart';
import '../data_health/data_health_providers.dart';
import 'holding_editor_dialog.dart';
import 'holding_export_service.dart';
import 'holding_filters.dart';

/// 行情刷新服务接线;引导完成前为 null,届时刷新操作保持禁用。
final quoteRefreshServiceProvider = Provider<QuoteRefreshService?>((ref) {
  return null;
});

/// 统一的轻提示。
void showHoldingToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

/// 行级 CRUD 与行情/导出动作,供页面、抽屉与批量条共用。
abstract final class HoldingActions {
  /// 编辑并保存;返回是否真正保存。
  /// 取消编辑或保存失败均返回 false;保存失败时额外触发 [onFailure]。
  static Future<bool> edit(
    BuildContext context,
    WidgetRef ref,
    Holding holding, {
    void Function()? onFailure,
  }) async {
    final updated = await showHoldingEditorDialog(context, initial: holding);
    if (updated == null) return false;
    try {
      await ref.read(holdingRepositoryProvider).upsert(updated);
    } catch (e) {
      // 数据库写入失败(磁盘满/损坏等):回调告知调用方,避免异常静默上抛。
      onFailure?.call();
      return false;
    }
    return true;
  }

  /// 二次确认后删除;返回是否真正删除。
  /// 取消确认或删除失败均返回 false;删除失败时额外触发 [onFailure]。
  static Future<bool> delete(
    BuildContext context,
    WidgetRef ref,
    Holding holding, {
    void Function()? onFailure,
  }) async {
    final confirmed = await showHoldingDeleteConfirmation(context, holding);
    if (!confirmed) return false;
    try {
      await ref.read(holdingRepositoryProvider).deleteByIds([holding.id]);
    } catch (e) {
      // 删除失败(数据库错误等):回调告知调用方,由调用方保留抽屉并提示重试。
      onFailure?.call();
      return false;
    }
    return true;
  }

  /// 刷新行情(自动过滤不可刷新的资产)。
  ///
  /// 服务未接线、没有可刷新资产或刷新失败时返回 null。
  /// 统一维护全局刷新状态([quoteRefreshUiStateProvider])、本次新鲜集合
  /// ([freshQuoteHoldingIdsProvider])与最近刷新记录
  /// ([lastQuoteRefreshAttemptProvider]),供数据健康面板与设置页共用。
  static Future<QuoteRefreshReport?> refreshQuotes(
    ProviderContainer ref,
    List<Holding> holdings,
  ) async {
    final uiNotifier = ref.read(quoteRefreshUiStateProvider.notifier);
    // 并发拦截:已有一次刷新进行中则直接返回,避免重复触发。
    if (uiNotifier.state is QuoteRefreshInProgress) return null;

    final eligible = holdings.where(holdingSupportsQuoteRefresh).toList();
    if (eligible.isEmpty) return null;
    final service = ref.read(quoteRefreshServiceProvider);
    if (service == null) return null;

    uiNotifier.state = const QuoteRefreshInProgress();
    try {
      final report = await service.refresh(eligible);
      ref.read(freshQuoteHoldingIdsProvider.notifier).state = {
        for (final h in report.updated) h.id,
        for (final h in report.retained) h.id,
      };
      final source = report.updated.isEmpty
          ? '无更新'
          : report.updated.first.fieldProvenance['currentPrice']?.source ??
                '未知';
      ref.read(lastQuoteRefreshAttemptProvider.notifier).state =
          QuoteRefreshAttempt(
        at: DateTime.now(),
        source: source,
        updated: report.updated.length + report.retained.length,
        failed: report.failed.length,
      );
      uiNotifier.state = const QuoteRefreshIdle();
      return report;
    } catch (e) {
      // 刷新失败(网络异常等):置失败状态携带原因,由调用方提示重试。
      ref.read(lastQuoteRefreshAttemptProvider.notifier).state =
          QuoteRefreshAttempt(
        at: DateTime.now(),
        source: '失败',
        updated: 0,
        failed: eligible.length,
      );
      uiNotifier.state = QuoteRefreshFailed('$e');
      return null;
    }
  }

  static Future<void> export(List<Holding> visible, String path) {
    return const HoldingExportService().exportCsv(visible, path);
  }
}
