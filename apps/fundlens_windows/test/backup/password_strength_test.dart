import 'package:fundlens_windows/backup/password_strength.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('assessBackupPassword', () {
    test('empty is empty', () {
      expect(assessBackupPassword(''), PasswordStrength.empty);
    });

    test('very short single-class is weak', () {
      expect(assessBackupPassword('abc'), PasswordStrength.weak);
      expect(assessBackupPassword('1234567'), PasswordStrength.weak);
    });

    test('8+ chars with two classes is fair', () {
      expect(assessBackupPassword('abcdef12'), PasswordStrength.fair);
      expect(assessBackupPassword('ABCDEFGH1'), PasswordStrength.fair);
      expect(assessBackupPassword('12345678a'), PasswordStrength.fair);
    });

    test('11 chars even with many classes is still fair at best', () {
      expect(assessBackupPassword('aA1!aA1!aA1'), PasswordStrength.fair);
    });

    test('12+ chars with three classes is strong', () {
      expect(
        assessBackupPassword('aA1!aA1!aA1!'),
        PasswordStrength.strong,
      );
      expect(
        assessBackupPassword('pässwörd-2026-OK'),
        PasswordStrength.strong,
      );
    });

    test('12+ chars with only one class is weak', () {
      expect(
        assessBackupPassword('aaaaaaaaaaaa'),
        PasswordStrength.weak,
      );
    });

    test('8 chars with three classes is fair (length gate still applies)',
        () {
      expect(
        assessBackupPassword('aA1!aA1!'),
        PasswordStrength.fair,
      );
    });

    test('digit+symbol-only long password stays fair (two classes)', () {
      expect(
        assessBackupPassword(r'12345678!@#$%^&*'),
        PasswordStrength.fair,
      );
    });
  });

  group('passwordStrengthHint', () {
    test('empty has no hint', () {
      expect(passwordStrengthHint(PasswordStrength.empty), '');
    });

    test('other tiers have non-empty Chinese hints', () {
      expect(passwordStrengthHint(PasswordStrength.weak), isNotEmpty);
      expect(passwordStrengthHint(PasswordStrength.fair), isNotEmpty);
      expect(passwordStrengthHint(PasswordStrength.strong), isNotEmpty);
    });
  });
}
