// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'screen_protection_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(screenProtectionService)
final screenProtectionServiceProvider = ScreenProtectionServiceProvider._();

final class ScreenProtectionServiceProvider
    extends
        $FunctionalProvider<
          ScreenProtectionService,
          ScreenProtectionService,
          ScreenProtectionService
        >
    with $Provider<ScreenProtectionService> {
  ScreenProtectionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'screenProtectionServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$screenProtectionServiceHash();

  @$internal
  @override
  $ProviderElement<ScreenProtectionService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ScreenProtectionService create(Ref ref) {
    return screenProtectionService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScreenProtectionService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScreenProtectionService>(value),
    );
  }
}

String _$screenProtectionServiceHash() =>
    r'20119c03c34c27e074cb4c29def0b5bccc451f03';
