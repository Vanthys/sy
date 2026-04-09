// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(isar)
final isarProvider = IsarProvider._();

final class IsarProvider
    extends $FunctionalProvider<AsyncValue<Isar>, Isar, FutureOr<Isar>>
    with $FutureModifier<Isar>, $FutureProvider<Isar> {
  IsarProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isarProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isarHash();

  @$internal
  @override
  $FutureProviderElement<Isar> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Isar> create(Ref ref) {
    return isar(ref);
  }
}

String _$isarHash() => r'10c85abdfa62f6a82fc0e0a02d95962dbd42888a';

@ProviderFor(trackerRepository)
final trackerRepositoryProvider = TrackerRepositoryProvider._();

final class TrackerRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<TrackerRepository>,
          TrackerRepository,
          FutureOr<TrackerRepository>
        >
    with
        $FutureModifier<TrackerRepository>,
        $FutureProvider<TrackerRepository> {
  TrackerRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trackerRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trackerRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<TrackerRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TrackerRepository> create(Ref ref) {
    return trackerRepository(ref);
  }
}

String _$trackerRepositoryHash() => r'c27f6b0e33ef04c60e04cb938a49e9d3fecf11ab';

@ProviderFor(entryRepository)
final entryRepositoryProvider = EntryRepositoryProvider._();

final class EntryRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<EntryRepository>,
          EntryRepository,
          FutureOr<EntryRepository>
        >
    with $FutureModifier<EntryRepository>, $FutureProvider<EntryRepository> {
  EntryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'entryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$entryRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<EntryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<EntryRepository> create(Ref ref) {
    return entryRepository(ref);
  }
}

String _$entryRepositoryHash() => r'7db010d4a1b514e4dd9aba2e364b2ff68b48f814';

@ProviderFor(trackerList)
final trackerListProvider = TrackerListProvider._();

final class TrackerListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Tracker>>,
          List<Tracker>,
          Stream<List<Tracker>>
        >
    with $FutureModifier<List<Tracker>>, $StreamProvider<List<Tracker>> {
  TrackerListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trackerListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trackerListHash();

  @$internal
  @override
  $StreamProviderElement<List<Tracker>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Tracker>> create(Ref ref) {
    return trackerList(ref);
  }
}

String _$trackerListHash() => r'd1ed5d92762896260d2767bd3a3f9f42dcd23eb5';

@ProviderFor(refreshStreaks)
final refreshStreaksProvider = RefreshStreaksFamily._();

final class RefreshStreaksProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  RefreshStreaksProvider._({
    required RefreshStreaksFamily super.from,
    required bool super.argument,
  }) : super(
         retry: null,
         name: r'refreshStreaksProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$refreshStreaksHash();

  @override
  String toString() {
    return r'refreshStreaksProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    final argument = this.argument as bool;
    return refreshStreaks(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RefreshStreaksProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$refreshStreaksHash() => r'e695812a39794b9c48dc44bb2bcee9a9032397e4';

final class RefreshStreaksFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, bool> {
  RefreshStreaksFamily._()
    : super(
        retry: null,
        name: r'refreshStreaksProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  RefreshStreaksProvider call(bool force) =>
      RefreshStreaksProvider._(argument: force, from: this);

  @override
  String toString() => r'refreshStreaksProvider';
}
