# sy3

A secure, high-performance, multi-platform habit and streak tracker built with Flutter, Riverpod, and Isar.

## Features

- **Flexible Tracking**: Support for Toggle, Choice, and Quantity-based trackers.
- **Secure Vault**: Encrypted trackers with PBKDF2 hashing and AES encryption.
- **Biometric Unlock**: Access your private trackers with fingerprint or face ID.
- **Fast Performance**: Isar-backed persistence with off-isolate bulk calculations.
- **Beautiful UI**: Modern Material 3 design with AMOLED support.

## Getting Started

### Prerequisites

- Flutter SDK (^3.9.0)
- Android Studio / VS Code with Flutter extension

### Installation

1. Clone the repository.
2. Run `flutter pub get`.
3. Generate Isar schemas:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
4. Run the app:
   ```bash
   flutter run
   ```

## Testing

This project includes a comprehensive test suite covering unit logic, widget rendering, and in-memory Isar repository integration.

To run the local test suite:
```bash
flutter test
```

*Note: The repository integration tests rely on Isar's native library. On Windows, ensure you have run `flutter build windows` at least once so the tests can locate `libisar.dll`.*

## Continuous Integration (CI)

We use GitHub Actions to enforce code quality on the `main` branch. 

Every Pull Request and direct push to `main` will automatically trigger:
1. `dart format` to ensure clean code style
2. `flutter analyze` to catch potential bugs and lint errors
3. `flutter test` to ensure no regressions occur across the 80+ test suite

Please ensure your code passes formatting, analysis, and tests locally before opening a pull request.
