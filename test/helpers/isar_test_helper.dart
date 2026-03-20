// test/helpers/isar_test_helper.dart
// Initialises the Isar native binary before running repository tests.
// Must be called in setUpAll() for any test that uses Isar.
import 'dart:ffi';
import 'dart:io';
import 'package:isar_community/src/native/isar_core.dart';

/// Calls [initializeCoreBinary] with the correct native library for the
/// current platform.
///
/// - **Windows (local dev):** points directly at the pre-built DLL in
///   `build/windows/x64/runner/Debug/` — no network needed.
/// - **Linux / macOS (CI):** uses `download: true` so isar_community fetches
///   `libisar_linux_x64.so` / `libisar.dylib` automatically from its CDN.
Future<void> initIsarForTests() async {
  if (Platform.isWindows) {
    final projectRoot = _findProjectRoot();
    final candidates = [
      '$projectRoot\\build\\windows\\x64\\runner\\Debug\\libisar.dll',
      '$projectRoot\\build\\windows\\x64\\runner\\Release\\libisar.dll',
    ];
    final dll = candidates.firstWhere(
      (p) => File(p).existsSync(),
      orElse: () => candidates.first,
    );
    initializeCoreBinary(libraries: {Abi.windowsX64: dll});
  } else {
    // On Linux / macOS runners (CI) — download the binary automatically.
    await initializeCoreBinary(download: true);
  }
}

/// Walks up from [Platform.script] to find the Flutter project root
/// (the folder containing pubspec.yaml).
String _findProjectRoot() {
  var dir = File(Platform.script.toFilePath()).parent;
  while (!File(
    '${dir.path}${Platform.pathSeparator}pubspec.yaml',
  ).existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) return Directory.current.path;
    dir = parent;
  }
  return dir.path;
}
