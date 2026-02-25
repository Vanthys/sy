import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../data/providers.dart';
import '../utils/color_utils.dart';

// ----------------------------------------
// Data Models
// ----------------------------------------
class DayData {
  const DayData({
    required this.date,
    this.entry,
    required this.amount,
    required this.color,
    this.inStreak = false,
  });

  final DateTime date;
  final Entry? entry;
  final double amount;
  final Color color;
  final bool inStreak;
}

class MonthData {
  const MonthData({
    required this.monthStart,
    required this.label,
    required this.days,
  });

  final DateTime monthStart;
  final String label;
  final List<DayData> days;
}

// ----------------------------------------
// State Model
// ----------------------------------------
class CalendarState {
  final List<MonthData> months;
  final bool isLoadingMore;

  const CalendarState({required this.months, this.isLoadingMore = false});

  CalendarState copyWith({List<MonthData>? months, bool? isLoadingMore}) {
    return CalendarState(
      months: months ?? this.months,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

// ----------------------------------------
// Provider & Notifier
// ----------------------------------------
final trackerCalendarProvider = ChangeNotifierProvider.autoDispose
    .family<TrackerCalendarNotifier, Tracker>(
      (ref, tracker) => TrackerCalendarNotifier(ref, tracker),
    );

class TrackerCalendarNotifier extends ChangeNotifier {
  TrackerCalendarNotifier(this.ref, this.tracker) {
    _init();
  }

  final Ref ref;
  final Tracker tracker;

  static const int _monthsPerBatch = 6;

  DateTime _latestMonth = DateTime.now();
  DateTime _earliestLoaded = DateTime.now();
  StreamSubscription<List<Entry>>? _entriesSub;
  List<Entry> _entries = [];

  CalendarState state = const CalendarState(months: []);
  bool isLoading = true;

  void _init() {
    final now = DateTime.now();
    _latestMonth = DateTime(now.year, now.month, 1);
    _earliestLoaded = DateTime(now.year, now.month - (_monthsPerBatch - 1), 1);
    _setupStream();
  }

  @override
  void dispose() {
    _entriesSub?.cancel();
    super.dispose();
  }

  void _setupStream() {
    _entriesSub?.cancel();
    _entriesSub = ref
        .read(entryRepositoryProvider)
        .watchEntriesInRange(
          tracker.id,
          _earliestLoaded,
          _latestMonth.add(const Duration(days: 31)),
        )
        .listen((data) {
          _entries = data;
          _updateState();
        });
  }

  void _updateState() {
    final months = _groupEntriesIntoMonths(_entries);
    state = state.copyWith(months: months);
    isLoading = false;
    notifyListeners();
  }

  Future<void> loadMorePastMonths() async {
    if (isLoading || state.isLoadingMore) return;

    state = state.copyWith(isLoadingMore: true);
    notifyListeners();

    final newStart = DateTime(
      _earliestLoaded.year,
      _earliestLoaded.month - _monthsPerBatch,
      1,
    );

    final older = await ref
        .read(entryRepositoryProvider)
        .fetchEntriesInRange(
          tracker.id,
          newStart,
          _earliestLoaded.add(const Duration(days: 1)),
        );

    _entries.insertAll(0, older);
    _earliestLoaded = newStart;

    _setupStream();

    state = state.copyWith(isLoadingMore: false);
    notifyListeners();
  }

  Future<void> saveEntry(DateTime date, double amount) async {
    final normalized = DateTime(date.year, date.month, date.day);
    await ref
        .read(entryRepositoryProvider)
        .saveEntry(tracker.id, normalized, amount);
  }

  // ----------------------------------------
  // Helpers
  // ----------------------------------------
  List<MonthData> _groupEntriesIntoMonths(List<Entry> entries) {
    final grouped = <String, List<Entry>>{};
    for (final e in entries) {
      final key = DateFormat('yyyy-MM').format(e.date);
      grouped.putIfAbsent(key, () => []).add(e);
    }

    final streakDates = _computeCurrentStreakDates(tracker.streakType, entries);
    final months = <MonthData>[];
    DateTime month = _latestMonth;

    while (month.isAfter(_earliestLoaded) ||
        month.isAtSameMomentAs(_earliestLoaded)) {
      final key = DateFormat('yyyy-MM').format(month);
      final entriesForMonth = grouped[key] ?? [];

      final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
      final lastDay = DateTime(month.year, month.month, daysInMonth);

      final today = DateTime.now();
      final maxVisibleDate = lastDay.isAfter(today) ? today : lastDay;
      final visibleDays = maxVisibleDate.day;

      final days = List.generate(visibleDays, (i) {
        final date = DateTime(month.year, month.month, visibleDays - i);
        final Entry? entry = entriesForMonth.firstWhereOrNull(
          (e) => DateUtils.isSameDay(e.date, date),
        );
        final amount = entry?.quantity ?? 0.0;
        final inStreak = streakDates.any((d) => DateUtils.isSameDay(d, date));

        return DayData(
          date: date,
          entry: entry,
          amount: amount,
          color: ColorUtils.getColorForAmount(amount),
          inStreak: inStreak,
        );
      }).toList();

      months.add(
        MonthData(
          monthStart: month,
          label: DateFormat('MMMM yyyy').format(month),
          days: days,
        ),
      );

      month = DateTime(month.year, month.month - 1, 1);
    }

    return months;
  }

  List<DateTime> _computeCurrentStreakDates(
    StreakType type,
    List<Entry> entries,
  ) {
    if (entries.isEmpty) return [];

    final sorted = entries.map((e) => e.date).toList()..sort();
    final today = DateTime.now();
    final Set<DateTime> streakDays = {};

    DateTime current = today;

    bool isGoodDay(DateTime d) {
      final hasEntry = sorted.any((e) => DateUtils.isSameDay(e, d));
      return type == StreakType.continued ? hasEntry : !hasEntry;
    }

    while (isGoodDay(current)) {
      streakDays.add(DateTime(current.year, current.month, current.day));
      current = current.subtract(const Duration(days: 1));
    }

    return streakDays.toList();
  }
}
