// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracker_calendar_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TrackerCalendarNotifier)
final trackerCalendarProvider = TrackerCalendarNotifierFamily._();

final class TrackerCalendarNotifierProvider
    extends $NotifierProvider<TrackerCalendarNotifier, CalendarState> {
  TrackerCalendarNotifierProvider._({
    required TrackerCalendarNotifierFamily super.from,
    required Tracker super.argument,
  }) : super(
         retry: null,
         name: r'trackerCalendarProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$trackerCalendarNotifierHash();

  @override
  String toString() {
    return r'trackerCalendarProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TrackerCalendarNotifier create() => TrackerCalendarNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CalendarState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CalendarState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TrackerCalendarNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$trackerCalendarNotifierHash() =>
    r'd484905ce0af5c0b043cbc221debbb532e7e9821';

final class TrackerCalendarNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          TrackerCalendarNotifier,
          CalendarState,
          CalendarState,
          CalendarState,
          Tracker
        > {
  TrackerCalendarNotifierFamily._()
    : super(
        retry: null,
        name: r'trackerCalendarProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TrackerCalendarNotifierProvider call(Tracker tracker) =>
      TrackerCalendarNotifierProvider._(argument: tracker, from: this);

  @override
  String toString() => r'trackerCalendarProvider';
}

abstract class _$TrackerCalendarNotifier extends $Notifier<CalendarState> {
  late final _$args = ref.$arg as Tracker;
  Tracker get tracker => _$args;

  CalendarState build(Tracker tracker);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<CalendarState, CalendarState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CalendarState, CalendarState>,
              CalendarState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
