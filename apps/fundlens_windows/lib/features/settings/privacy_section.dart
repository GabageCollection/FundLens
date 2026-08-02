import 'package:flutter/material.dart';

import 'widgets/settings_section_card.dart';

/// Privacy facts: local-only processing, temporary screenshot cleanup and
/// redacted logging. These are factual statements, not toggles.
class PrivacySection extends StatelessWidget {
  const PrivacySection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsSectionCard(
      title: '隐私与安全',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final fact in const [
            '所有数据仅在本机处理，不上传服务器。',
            '导入截图的临时副本在写入成功或取消后自动清除。',
            '日志中的路径与敏感信息经过脱敏处理。',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(fact, style: theme.textTheme.bodySmall)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
