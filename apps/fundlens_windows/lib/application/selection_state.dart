import 'package:flutter_riverpod/legacy.dart';
import 'package:fundlens_core/fundlens_core.dart';

/// Asset class selected on the overview Asset Spectrum; `null` means no
/// filter and all holdings are shown.
final selectedAssetClassProvider = StateProvider<AssetClass?>((ref) => null);
