import 'package:drift/drift.dart';
import '/data/database.dart';
import '/logic/vault_provider.dart';
import '/utils/encryption_utils.dart';
import 'tracker_config.dart';

class TrackerRepository {
  final AppDatabase db;
  final VaultState vaultState;

  TrackerRepository(this.db, this.vaultState);

  /// Helper to decrypt a tracker if necessary.
  /// If decryption fails (wrong key) or it's standard plain text, returns as-is (or with a "Locked" placeholder).
  Tracker _decryptTracker(Tracker t) {
    if (t.privacyLevel == PrivacyLevel.standard) return t;

    // It's a private tracker. We need the active key to decrypt.
    final key = vaultState.activeKey;
    if (key == null) {
      return t.copyWith(
        title: 'Locked Vault Tracker',
        description: const Value('Unlock the vault to view.'),
      );
    }

    final decTitle = EncryptionUtils.decryptText(t.title, key);
    final decDesc = t.description != null
        ? EncryptionUtils.decryptText(t.description!, key)
        : null;

    // If decryption fails (returns null), it means the key is wrong (e.g. using General PIN on Secret Tracker)
    if (decTitle == null) {
      return t.copyWith(
        title: 'Encrypted Tracker',
        description: const Value('Incorrect vault key.'),
      );
    }

    return t.copyWith(title: decTitle, description: Value(decDesc));
  }

  /// Helper to encrypt plain text if the privacy level requires it.
  String _encryptTextIfPrivate(String text, PrivacyLevel level) {
    if (level == PrivacyLevel.standard) return text;
    final key = vaultState.activeKey;
    if (key == null)
      throw Exception("Cannot save private tracker: Vault is locked.");
    return EncryptionUtils.encryptText(text, key);
  }

  /// Fetch all trackers, ordered by creation date (newest first)
  /// Only fetches trackers up to the currently unlocked privacy level.
  Future<List<Tracker>> getAllTrackers() async {
    final rawTrackers =
        await (db.select(db.trackers)
              ..where(
                (t) => t.privacyLevel.isSmallerOrEqualValue(
                  vaultState.unlockedLevel.index,
                ),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();

    return rawTrackers.map(_decryptTracker).toList();
  }

  /// Stream all trackers to listen for live updates
  Stream<List<Tracker>> watchAllTrackers() {
    return (db.select(db.trackers)
          ..where(
            (t) => t.privacyLevel.isSmallerOrEqualValue(
              vaultState.unlockedLevel.index,
            ),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch()
        .map((list) => list.map(_decryptTracker).toList());
  }

  /// Get a single tracker by ID
  Future<Tracker?> getTrackerById(String id) async {
    final t = await (db.select(
      db.trackers,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return t != null ? _decryptTracker(t) : null;
  }

  /// Create a new tracker with a given configuration
  Future<void> createTracker({
    required String title,
    String? description,
    required StreakType streakType,
    required TrackerConfig config,
    PrivacyLevel privacyLevel = PrivacyLevel.standard,
  }) async {
    final now = DateTime.now();

    final encTitle = _encryptTextIfPrivate(title, privacyLevel);
    final encDesc = description != null
        ? _encryptTextIfPrivate(description, privacyLevel)
        : null;

    await db
        .into(db.trackers)
        .insert(
          TrackersCompanion.insert(
            title: encTitle,
            description: Value(encDesc),
            streakType: streakType,
            privacyLevel: Value(privacyLevel),
            config: config,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  /// Update tracker info (title, description, streaks, etc.)
  Future<void> updateTracker(
    String id, {
    String? title,
    String? description,
    StreakType? streakType,
    PrivacyLevel? privacyLevel,
    TrackerConfig? config,
    int? currentStreak,
    int? longestStreak,
  }) async {
    // We need to fetch the existing tracker to know its privacy level if not provided
    final existing = await (db.select(
      db.trackers,
    )..where((t) => t.id.equals(id))).getSingle();
    final targetLevel = privacyLevel ?? existing.privacyLevel;

    Value<String>? encTitleVal;
    if (title != null) {
      encTitleVal = Value(_encryptTextIfPrivate(title, targetLevel));
    }

    Value<String?>? encDescVal;
    if (description != null) {
      encDescVal = Value(_encryptTextIfPrivate(description, targetLevel));
    }

    await (db.update(db.trackers)..where((t) => t.id.equals(id))).write(
      TrackersCompanion(
        title: encTitleVal ?? const Value.absent(),
        description: encDescVal ?? const Value.absent(),
        streakType: Value.absentIfNull(streakType),
        privacyLevel: Value.absentIfNull(privacyLevel),
        config: Value.absentIfNull(config),
        currentStreak: Value.absentIfNull(currentStreak),
        longestStreak: Value.absentIfNull(longestStreak),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Delete tracker and optionally its entries
  Future<void> deleteTracker(String id, {bool deleteEntries = true}) async {
    if (deleteEntries) {
      await (db.delete(db.entries)..where((e) => e.tracker.equals(id))).go();
    }
    await (db.delete(db.trackers)..where((t) => t.id.equals(id))).go();
  }

  /// Update streak stats only
  Future<void> updateStreaks(String id, int current, int longest) async {
    await (db.update(db.trackers)..where((t) => t.id.equals(id))).write(
      TrackersCompanion(
        currentStreak: Value(current),
        longestStreak: Value(longest),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
