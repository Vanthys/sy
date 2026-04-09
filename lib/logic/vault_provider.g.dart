// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vault_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(VaultNotifier)
final vaultProvider = VaultNotifierProvider._();

final class VaultNotifierProvider
    extends $NotifierProvider<VaultNotifier, VaultState> {
  VaultNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vaultProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vaultNotifierHash();

  @$internal
  @override
  VaultNotifier create() => VaultNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VaultState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VaultState>(value),
    );
  }
}

String _$vaultNotifierHash() => r'7853424369e87319a43b024538d5c1adeceac2e3';

abstract class _$VaultNotifier extends $Notifier<VaultState> {
  VaultState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<VaultState, VaultState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<VaultState, VaultState>,
              VaultState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(vaultAccess)
final vaultAccessProvider = VaultAccessProvider._();

final class VaultAccessProvider
    extends $FunctionalProvider<VaultAccess, VaultAccess, VaultAccess>
    with $Provider<VaultAccess> {
  VaultAccessProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vaultAccessProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vaultAccessHash();

  @$internal
  @override
  $ProviderElement<VaultAccess> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VaultAccess create(Ref ref) {
    return vaultAccess(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VaultAccess value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VaultAccess>(value),
    );
  }
}

String _$vaultAccessHash() => r'76aff1ef28eabdf71490b0e00710f26ba921dcb7';
