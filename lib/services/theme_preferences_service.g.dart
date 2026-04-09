// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_preferences_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(themePreferencesService)
final themePreferencesServiceProvider = ThemePreferencesServiceProvider._();

final class ThemePreferencesServiceProvider
    extends
        $FunctionalProvider<
          ThemePreferencesService,
          ThemePreferencesService,
          ThemePreferencesService
        >
    with $Provider<ThemePreferencesService> {
  ThemePreferencesServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themePreferencesServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themePreferencesServiceHash();

  @$internal
  @override
  $ProviderElement<ThemePreferencesService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ThemePreferencesService create(Ref ref) {
    return themePreferencesService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemePreferencesService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemePreferencesService>(value),
    );
  }
}

String _$themePreferencesServiceHash() =>
    r'be768df9ed8de9dbb4fef0c03177a1c7a8863618';
