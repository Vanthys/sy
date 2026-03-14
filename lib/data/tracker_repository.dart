import 'dart:convert';
import 'package:isar_community/isar.dart';
import 'package:uuid/uuid.dart';
import '/data/database.dart';
import '/data/schemas/tracker_schema.dart';
import '/data/schemas/entry_schema.dart';
import '/data/tracker_config.dart';
import '/logic/vault_provider.dart';
import '/utils/encryption_utils.dart';

/// Adapts [IsarTracker] rows to the app-level [Tracker] data class.
extension IsarTrackerConversion on IsarTracker {
  Tracker toTracker() {
    final config = TrackerConfig.fromJson(jsonDecode(configJson));
    return Tracker(
      id: uuid,
      title: title,
      description: description,
      streakType: StreakType.values[streakTypeIndex],
      privacyLevel: PrivacyLevel.values[privacyLevelIndex],
      config: config,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      createdAt: createdAt,
      updatedAt: updatedAt,
      sortOrder: sortOrder,
    );
  }
}

class TrackerRepository {
  final Isar _isar;
  final VaultState vaultState;

  TrackerRepository(this._isar, this.vaultState);

  // shorthand collections
  IsarCollection<IsarTracker> get _trackers => _isar.collection<IsarTracker>();
  IsarCollection<IsarEntry> get _entries => _isar.collection<IsarEntry>();

  // ------------------------------------------------------------------
  // Helpers (encryption / decryption — unchanged from Drift version)
  // ------------------------------------------------------------------

  Tracker _decryptTracker(Tracker t) {
    if (t.privacyLevel == PrivacyLevel.standard) return t;

    final key = vaultState.activeKey;
    if (key == null) {
      return t.copyWith(
        title: 'Locked Vault Tracker',
        description: const Value('Unlock the vault to view.'),
      );
    }

    final decTitle = EncryptionUtils.decryptText(t.title, key);
    final decDesc =
        t.description != null ? EncryptionUtils.decryptText(t.description!, key) : null;

    if (decTitle == null) {
      return t.copyWith(
        title: 'Encrypted Tracker',
        description: const Value('Incorrect vault key.'),
      );
    }

    return t.copyWith(title: decTitle, description: Value(decDesc));
  }

  String _encryptTextIfPrivate(String text, PrivacyLevel level) {
    if (level == PrivacyLevel.standard) return text;
    final key = vaultState.activeKey;
    if (key == null) throw Exception('Cannot save private tracker: Vault is locked.');
    return EncryptionUtils.encryptText(text, key);
  }

  // ------------------------------------------------------------------
  // Queries
  // ------------------------------------------------------------------

  Future<List<Tracker>> getAllTrackers() async {
    final raw = await _trackers
        .filter()
        .privacyLevelIndexLessThan(vaultState.unlockedLevel.index + 1)
        .sortBySortOrder()
        .findAll();
    return raw.map((r) => _decryptTracker(r.toTracker())).toList();
  }

  Stream<List<Tracker>> watchAllTrackers() {
    return _trackers
        .filter()
        .privacyLevelIndexLessThan(vaultState.unlockedLevel.index + 1)
        .sortBySortOrder()
        .watch(fireImmediately: true)
        .map((list) => list.map((r) => _decryptTracker(r.toTracker())).toList());
  }

  Future<Tracker?> getTrackerById(String uuid) async {
    final raw = await _trackers.filter().uuidEqualTo(uuid).findFirst();
    return raw != null ? _decryptTracker(raw.toTracker()) : null;
  }

  // ------------------------------------------------------------------
  // Mutations
  // ------------------------------------------------------------------

  Future<void> createTracker({
    required String title,
    String? description,
    required StreakType streakType,
    required TrackerConfig config,
    PrivacyLevel privacyLevel = PrivacyLevel.standard,
  }) async {
    final now = DateTime.now();
    final encTitle = _encryptTextIfPrivate(title, privacyLevel);
    final encDesc = description != null ? _encryptTextIfPrivate(description, privacyLevel) : null;

    final row = IsarTracker()
      ..uuid = const Uuid().v4()
      ..title = encTitle
      ..description = encDesc
      ..streakTypeIndex = streakType.index
      ..privacyLevelIndex = privacyLevel.index
      ..configJson = jsonEncode(config.toJson())
      ..currentStreak = 0
      ..longestStreak = 0
      ..createdAt = now
      ..updatedAt = now
      ..sortOrder = await _trackers.count();

    await _isar.writeTxn(() => _trackers.put(row));
  }

  Future<void> updateTracker(
    String uuid, {
    String? title,
    String? description,
    StreakType? streakType,
    PrivacyLevel? privacyLevel,
    TrackerConfig? config,
    int? currentStreak,
    int? longestStreak,
  }) async {
    final existing = await _trackers.filter().uuidEqualTo(uuid).findFirst();
    if (existing == null) return;

    final targetLevel = privacyLevel ?? PrivacyLevel.values[existing.privacyLevelIndex];

    if (title != null) existing.title = _encryptTextIfPrivate(title, targetLevel);
    if (description != null) existing.description = _encryptTextIfPrivate(description, targetLevel);
    if (streakType != null) existing.streakTypeIndex = streakType.index;
    if (privacyLevel != null) existing.privacyLevelIndex = privacyLevel.index;
    if (config != null) existing.configJson = jsonEncode(config.toJson());
    if (currentStreak != null) existing.currentStreak = currentStreak;
    if (longestStreak != null) existing.longestStreak = longestStreak;
    existing.updatedAt = DateTime.now();

    await _isar.writeTxn(() => _trackers.put(existing));
  }

  Future<void> deleteTracker(String uuid, {bool deleteEntries = true}) async {
    await _isar.writeTxn(() async {
      if (deleteEntries) {
        await _entries.filter().trackerIdEqualTo(uuid).deleteAll();
      }
      await _trackers.filter().uuidEqualTo(uuid).deleteAll();
    });
  }

  Future<void> updateStreaks(String uuid, int current, int longest) async {
    final row = await _trackers.filter().uuidEqualTo(uuid).findFirst();
    if (row == null) return;
    row.currentStreak = current;
    row.longestStreak = longest;
    row.updatedAt = DateTime.now();
    await _isar.writeTxn(() => _trackers.put(row));
  }

  Future<void> reorderTrackers(List<String> visibleIds) async {
    await _isar.writeTxn(() async {
      // 1. Fetch ALL trackers sorted by current sortOrder
      final all = await _trackers.where().sortBySortOrder().findAll();

      // 2. Identify the indices (slots) currently occupied by the items in visibleIds
      final slots = <int>[];
      final visibleItemsMap = <String, IsarTracker>{};

      for (int i = 0; i < all.length; i++) {
        if (visibleIds.contains(all[i].uuid)) {
          slots.add(i);
          visibleItemsMap[all[i].uuid] = all[i];
        }
      }

      // 3. Update the trackers in their new order, but using the original slots
      // visibleIds is already in the target order
      for (int i = 0; i < visibleIds.length; i++) {
        if (i >= slots.length) break; // Should not happen

        final trackerId = visibleIds[i];
        final tracker = visibleItemsMap[trackerId];
        if (tracker != null) {
          tracker.sortOrder = slots[i];
          await _trackers.put(tracker);
        }
      }
    });
  }

  // ------------------------------------------------------------------
  // Vault re-key
  // ------------------------------------------------------------------

  Future<void> rekeyVault(PrivacyLevel level, String oldPin, String newPin) async {
    final rows = await _trackers.filter().privacyLevelIndexEqualTo(level.index).findAll();
    
    final oldKey = EncryptionUtils.deriveKeyFromPin(oldPin);
    final newKey = EncryptionUtils.deriveKeyFromPin(newPin);

    await _isar.writeTxn(() async {
      for (final row in rows) {
        final decTitle = EncryptionUtils.decryptText(row.title, oldKey);
        if (decTitle == null) continue;
        final decDesc = row.description != null
            ? EncryptionUtils.decryptText(row.description!, oldKey)
            : null;

        row.title = EncryptionUtils.encryptText(decTitle, newKey);
        row.description = decDesc != null ? EncryptionUtils.encryptText(decDesc, newKey) : null;
        row.updatedAt = DateTime.now();
        await _trackers.put(row);
      }
    });
  }
}
