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


