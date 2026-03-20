// test/helpers/isar_test_helper.dart
// Initialises the Isar native binary before running repository tests.
// Must be called in setUpAll() for any test that uses in-memory Isar.
import 'dart:ffi';
import 'dart:io';
import 'package:isar_community/src/native/isar_core.dart';

/// Calls [initializeCoreBinary] pointing at the pre-built Windows x64 DLL
/// that lives in the project's build output directory.
///
/// On non-Windows platforms the function automatically picks the right name
/// from the build folder tree; adjust [_libPath] if you add CI targets.
void initIsarForTests() {
  // Resolve the absolute path relative to the workspace root so it works
  // regardless of the working directory that flutter test chooses.
  final projectRoot = _findProjectRoot();
  final Map<Abi, String> libraries;

  if (Platform.isWindows) {
    // flutter build windows produces both Debug and Release artifacts; use
    // whichever exists first.
    final candidates = [
      '$projectRoot\\build\\windows\\x64\\runner\\Debug\\libisar.dll',
      '$projectRoot\\build\\windows\\x64\\runner\\Release\\libisar.dll',
    ];
    final dll = candidates.firstWhere(
      (p) => File(p).existsSync(),
      orElse: () => candidates.first,
    );
    libraries = {Abi.windowsX64: dll};
  } else if (Platform.isMacOS) {
    libraries = {}; // Isar usually auto-finds dylib on macOS
  } else if (Platform.isLinux) {
    libraries = {}; // auto-finds .so on Linux
  } else {
    libraries = {};
  }

  initializeCoreBinary(libraries: libraries);
}

/// Walks up the directory tree from [Platform.script] to find the Flutter
/// project root (the folder containing pubspec.yaml).
String _findProjectRoot() {
  var dir = File(Platform.script.toFilePath()).parent;
  while (!File('${dir.path}${Platform.pathSeparator}pubspec.yaml')
      .existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      // Reached filesystem root without finding pubspec.yaml — fall back to cwd
      return Directory.current.path;
    }
    dir = parent;
  }
  return dir.path;
}
