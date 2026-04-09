import 'package:encrypt/encrypt.dart' as enc;

import 'database.dart';

class VaultAccess {
  const VaultAccess({
    this.unlockedLevel = PrivacyLevel.standard,
    this.activeKey,
  });

  final PrivacyLevel unlockedLevel;
  final enc.Key? activeKey;

  bool get isVaultUnlocked => unlockedLevel != PrivacyLevel.standard;
}
