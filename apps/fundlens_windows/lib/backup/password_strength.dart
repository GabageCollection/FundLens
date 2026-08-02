/// Strength tiers for a backup password.
enum PasswordStrength { empty, weak, fair, strong }

/// Assesses a backup password.
///
/// `strong` requires at least 12 characters spanning at least three character
/// classes; `fair` requires at least 8 characters spanning at least two
/// classes; everything non-empty falls back to `weak`. Strength is advisory
/// only — creation is never blocked by a weak password.
PasswordStrength assessBackupPassword(String password) {
  if (password.isEmpty) return PasswordStrength.empty;
  final length = password.runes.length;
  final lower = RegExp(r'[a-z]').hasMatch(password);
  final upper = RegExp(r'[A-Z]').hasMatch(password);
  final digit = RegExp(r'[0-9]').hasMatch(password);
  final symbol = RegExp(r'[^a-zA-Z0-9]').hasMatch(password);
  final classes = [lower, upper, digit, symbol].where((b) => b).length;

  if (length >= 12 && classes >= 3) return PasswordStrength.strong;
  if (length >= 8 && classes >= 2) return PasswordStrength.fair;
  return PasswordStrength.weak;
}

/// Short Chinese hint shown under the backup password field.
String passwordStrengthHint(PasswordStrength strength) {
  return switch (strength) {
    PasswordStrength.empty => '',
    PasswordStrength.weak => '密码强度较弱，建议至少 8 位并混用字母与数字。',
    PasswordStrength.fair => '密码强度一般，建议再长一些并混用更多字符类型。',
    PasswordStrength.strong => '密码强度较好。',
  };
}
