// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vault_storage_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(vaultStorageService)
final vaultStorageServiceProvider = VaultStorageServiceProvider._();

final class VaultStorageServiceProvider
    extends
        $FunctionalProvider<
          VaultStorageService,
          VaultStorageService,
          VaultStorageService
        >
    with $Provider<VaultStorageService> {
  VaultStorageServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vaultStorageServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vaultStorageServiceHash();

  @$internal
  @override
  $ProviderElement<VaultStorageService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VaultStorageService create(Ref ref) {
    return vaultStorageService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VaultStorageService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VaultStorageService>(value),
    );
  }
}

String _$vaultStorageServiceHash() =>
    r'ab499192361161f2d746fd04ded4ccf00c64f6aa';
