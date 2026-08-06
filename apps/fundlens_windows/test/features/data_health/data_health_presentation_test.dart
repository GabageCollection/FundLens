import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/features/data_health/data_health_models.dart';
import 'package:fundlens_windows/features/data_health/data_health_presentation.dart';

void main() {
  group('dataHealthPresentation 五态投影完整', () {
    test('每个状态都有标签、图标与两种表面色,且覆盖全部五态', () {
      // 穷尽 switch 保证新增状态在编译期强制补配。
      final labels = <String>{};
      for (final status in DataHealthStatus.values) {
        final p = dataHealthPresentation(status);
        labels.add(p.label);
        expect(p.icon, isNotNull);
        expect(p.textColor, isNotNull);
        expect(p.iconColor, isNotNull);
        expect(
          p.textColor,
          isNot(equals(p.iconColor)),
          reason: '文字档色(AA)与图标原色必须保持不同的对比度策略',
        );
      }
      expect(
        labels,
        containsAll(['正常', '部分缺失', '需要更新', '正在刷新', '刷新失败']),
      );
    });

    test('状态到标签的语义一一对应', () {
      const expected = <DataHealthStatus, String>{
        DataHealthStatus.normal: '正常',
        DataHealthStatus.partialMissing: '部分缺失',
        DataHealthStatus.needsUpdate: '需要更新',
        DataHealthStatus.refreshing: '正在刷新',
        DataHealthStatus.refreshFailed: '刷新失败',
      };
      for (final entry in expected.entries) {
        expect(dataHealthPresentation(entry.key).label, entry.value);
      }
    });
  });
}
