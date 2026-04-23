// test/helpers/isar_test_helper.dart
// Initialises the Isar native binary before running repository tests.
// Must be called in setUpAll() for any test that uses Isar.
import 'dart:ffi';
import 'dart:convert';
import 'dart:io';
import 'package:isar_community/src/native/isar_core.dart';

/// Calls [initializeCoreBinary] with a local native library for the current
/// platform. This avoids network downloads, which fail under Flutter tests
/// because [TestWidgetsFlutterBinding] intercepts `HttpClient`.
Future<void> initIsarForTests() async {
  final libPath = await _resolveLocalIsarLibraryPath();
  initializeCoreBinary(libraries: {Abi.current(): libPath});
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

Future<String> _resolveLocalIsarLibraryPath() async {
  final projectRoot = _findProjectRoot();
  final packageRoot = await _findIsarFlutterLibsPackageRoot();

  final candidates = <String>[
    if (Platform.isWindows) ...[
      '$projectRoot\\build\\windows\\x64\\runner\\Debug\\libisar.dll',
      '$projectRoot\\build\\windows\\x64\\runner\\Release\\libisar.dll',
      if (packageRoot != null) '$packageRoot\\windows\\libisar.dll',
    ],
    if (Platform.isLinux && packageRoot != null)
      '$packageRoot${Platform.pathSeparator}linux${Platform.pathSeparator}libisar.so',
    if (Platform.isMacOS && packageRoot != null)
      '$packageRoot${Platform.pathSeparator}macos${Platform.pathSeparator}libisar.dylib',
  ];

  for (final path in candidates) {
    if (File(path).existsSync()) {
      return path;
    }
  }

  throw StateError(
    'Could not locate a local IsarCore library for tests. Checked: '
    '${candidates.join(', ')}',
  );
}

Future<String?> _findIsarFlutterLibsPackageRoot() async {
  final projectRoot = _findProjectRoot();
  final configFile = File(
    '$projectRoot${Platform.pathSeparator}.dart_tool${Platform.pathSeparator}package_config.json',
  );
  if (!configFile.existsSync()) return null;

  final json =
      jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
  final packages = (json['packages'] as List).cast<Map<String, dynamic>>();
  final package = packages.firstWhere(
    (pkg) => pkg['name'] == 'isar_community_flutter_libs',
    orElse: () => const <String, dynamic>{},
  );

  final rootUri = package['rootUri'] as String?;
  if (rootUri == null || rootUri.isEmpty) return null;

  final resolved = Uri.parse(rootUri).resolveUri(Directory(projectRoot).uri);
  return Directory.fromUri(resolved).path;
}
