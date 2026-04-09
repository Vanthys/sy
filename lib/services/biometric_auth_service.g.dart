// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'biometric_auth_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(biometricAuthService)
final biometricAuthServiceProvider = BiometricAuthServiceProvider._();

final class BiometricAuthServiceProvider
    extends
        $FunctionalProvider<
          BiometricAuthService,
          BiometricAuthService,
          BiometricAuthService
        >
    with $Provider<BiometricAuthService> {
  BiometricAuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'biometricAuthServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$biometricAuthServiceHash();

  @$internal
  @override
  $ProviderElement<BiometricAuthService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BiometricAuthService create(Ref ref) {
    return biometricAuthService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BiometricAuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BiometricAuthService>(value),
    );
  }
}

String _$biometricAuthServiceHash() =>
    r'f1bf6c67e025bad4b9aad8b3a1e3f4a1b3be05c3';
