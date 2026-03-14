# v2.0 Roadmap - Architectural Evolution

To address the current pain points around database maintenance, UI flexibility, and security, I propose the following roadmap for the next major version of the app.

## 1. Database: Move from SQLite to Isar
The current Drift/SQLite setup requires manual migrations and SQL-style schema management, which can be brittle and complex.
- **Why Isar?**: Isar is a high-performance NoSQL database for Flutter. It is schemaless (it handles field additions/removals automatically) and stores Dart objects directly.
- **Migration Path**: We can write a one-time migration to move data from the `.sqlite` file into Isar's `.isar` format. This will eliminate the "annoying schema changes" forever.
- **Improved Performance**: Isar's reactive nature means we can remove many manual refresh logic blocks we've added recently.

## 2. Dynamic Visuals: Custom Mapping & Adaptive Ranges
Currently, intensity is normalized by the local maximum or hardcoded (1-12), which doesn't work for multi-choice or diverse tracking.
- **Value-to-Color Mapping**: For "Choice" trackers, the user should be able to pick a specific color for each option (e.g., "Bad" = Red, "Good" = Blue).
- **User-Defined Intensity Ceiling**: Instead of a hardcoded 12, each tracker should have an "Intensity Goal" that defines what 100% opacity looks like.
- **Discrete Heatmaps**: For binary/toggle trackers, use a dedicated "Checkmark" visual instead of a varying intensity square.

## 3. Security: "Fortress" Vault 
The current security model stores PINs in plain text and derives keys simply.
- **Secure PIN Storage**: Move from `SharedPreferences` to `flutter_secure_storage` (Keychain/Keystore).
- **Hashing**: Use Argon2 or PBKDF2 to hash the PIN before storage. The vault will check the hash, not the plain text.
- **Ephemeral Key Management**: The encryption key should be derived on-the-fly when the vault is unlocked and cleared from memory when locked.
- **Biometric Integration**: Add FaceID/TouchID support as an optional unlock method.

## 4. Feature Requests: "Smart Previews" & Insights
- **Next-Day Preview**: Show how logging a value today will impact your longest streak (gamification).
- **Trend Detection**: Automatically detect if a tracker is trending up or down over months.
