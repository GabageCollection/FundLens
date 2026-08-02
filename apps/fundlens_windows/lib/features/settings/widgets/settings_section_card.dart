import 'package:flutter/material.dart';

import '../../../theme/fundlens_theme.dart';
import '../../../theme/fundlens_tokens.dart';

/// Paper section card shared by the settings sections.
class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: FundLensTokens.cardGap),
      padding: const EdgeInsets.all(FundLensTokens.cardPadding),
      decoration: BoxDecoration(
        color: FundLensTokens.surface,
        borderRadius: BorderRadius.circular(FundLensTokens.radiusCard),
        border: Border.all(color: FundLensTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.extension<FundLensTextStyles>()!.sectionTitle,
          ),
          const SizedBox(height: FundLensTokens.space3),
          child,
        ],
      ),
    );
  }
}
