import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../data/providers.dart';
import '../data/tracker_config.dart';
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
    required this.streakGradient,
    required this.tooltip,
    this.inStreak = false,
    this.isStreakStart = false,
    this.isStreakEnd = false,
  });

  final DateTime date;
  final Entry? entry;
  final double amount;
  final Color color;
  final List<Color> streakGradient;
  final String tooltip;
  final bool inStreak;
  final bool isStreakStart;
  final bool isStreakEnd;
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

  // Cached configuration colors (pre-parsed once)
  late final List<Color> _streakColors;
  late final List<Color> _intensityColors;

  CalendarState state = const CalendarState(months: []);
  bool isLoading = true;

  void _init() {
    final now = DateTime.now();
    _latestMonth = DateTime(now.year, now.month, 1);
    _earliestLoaded = DateTime(now.year, now.month - (_monthsPerBatch - 1), 1);

    // Pre-parse config colors once to avoid hex parsing in the loop
    _streakColors = _parseStreakColors();
    _intensityColors = _parseIntensityColors();

    _setupStream();
  }

  List<Color> _parseStreakColors() {
    if (tracker.config.inputType == InputType.choice &&
        tracker.config.optionColors != null) {
      final parsed = tracker.config.optionColors!
          .map(ColorUtils.parseHexColor)
          .whereType<Color>()
          .toList();
      if (parsed.isNotEmpty) {
        if (parsed.length == 1) return [parsed.first, parsed.first];
        return parsed;
      }
    }

    final colors = tracker.config.streakColors;
    if (colors == null || colors.isEmpty) {
      return [const Color(0xFF2196F3), const Color(0xFF2196F3)];
    }
    final parsed = colors
        .map(ColorUtils.parseHexColor)
        .whereType<Color>()
        .toList();
    if (parsed.isEmpty) {
      return [const Color(0xFF2196F3), const Color(0xFF2196F3)];
    }
    if (parsed.length == 1) return [parsed.first, parsed.first];
    return parsed;
  }

  List<Color> _parseIntensityColors() {
    final colors = tracker.config.intensityColors;
    if (colors == null || colors.isEmpty) return [];
    return colors.map(ColorUtils.parseHexColor).whereType<Color>().toList();
  }

  @override
  void dispose() {
    _entriesSub?.cancel();
    super.dispose();
  }

  void _setupStream() {
    _entriesSub?.cancel();
    ref.read(entryRepositoryProvider.future).then((entryRepo) {
      _entriesSub = entryRepo
          .watchEntriesInRange(
            tracker.id,
            _earliestLoaded,
            _latestMonth.add(const Duration(days: 31)),
          )
          .listen((data) {
            _entries = data;
            _updateState();
          });
    });
  }

  void _updateState() {
    // We removed 'compute' (Isolate) because spawning was causing a 200-500ms freeze on the main thread.
    // For small sets (6-24 months), synchronous grouping on the main thread is actually faster
    // than the overhead of serialization and isolate setup.
    final months = _generateMonthsData();
    state = state.copyWith(months: months);
    isLoading = false;
    notifyListeners();
  }

  List<MonthData> _generateMonthsData() {
    final entryMap = <DateTime, Entry>{
      for (final e in _entries)
        DateTime(e.date.year, e.date.month, e.date.day): e,
    };

    final meaningfulEntries = _entries
        .where((e) => e.quantity.round() > 0)
        .toList();
    final entryDatesSet = meaningfulEntries
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet();

    // Streak Calculation
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);

    final createdAt = tracker.createdAt;
    final createdAtMidnight = DateTime(
      createdAt.year,
      createdAt.month,
      createdAt.day,
    );

    // Determine Tracking Origin (earliest of creation or data)
    final sortedDays = entryDatesSet.toList()..sort();
    final earliestEntry = sortedDays.isEmpty
        ? createdAtMidnight
        : sortedDays.first;
    final trackingStartDay = earliestEntry.isBefore(createdAtMidnight)
        ? earliestEntry
        : createdAtMidnight;

    final Set<DateTime> streakDatesSet = {};
    DateTime current = todayMidnight;

    if (tracker.streakType == StreakType.continued &&
        !entryDatesSet.contains(current)) {
      current = DateTime(current.year, current.month, current.day - 1);
    }

    bool isGoodDay(DateTime d) {
      final hasEntry = entryDatesSet.contains(d);
      return tracker.streakType == StreakType.continued ? hasEntry : !hasEntry;
    }

    while (isGoodDay(current) && !current.isBefore(trackingStartDay)) {
      streakDatesSet.add(current);
      current = DateTime(current.year, current.month, current.day - 1);
    }

    // Grouping
    final months = <MonthData>[];
    DateTime month = _latestMonth;

    while (month.isAfter(_earliestLoaded) ||
        month.isAtSameMomentAs(_earliestLoaded)) {
      final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
      final monthEnd = DateTime(month.year, month.month, daysInMonth);
      final maxVisibleDate = monthEnd.isAfter(todayMidnight)
          ? todayMidnight
          : monthEnd;
      final visibleDaysCount = maxVisibleDate.day;

      final days = List.generate(visibleDaysCount, (i) {
        final date = DateTime(month.year, month.month, visibleDaysCount - i);
        final entry = entryMap[date];
        final amount = entry?.quantity ?? 0.0;
        final inStreak = streakDatesSet.contains(date);

        bool isStart = false;
        bool isEnd = false;

        if (inStreak) {
          final yesterday = DateTime(date.year, date.month, date.day - 1);
          final tomorrow = DateTime(date.year, date.month, date.day + 1);
          isStart = !streakDatesSet.contains(yesterday);
          isEnd = !streakDatesSet.contains(tomorrow);
        }

        final tooltip =
            '${DateFormat('yyyy-MM-dd').format(date)}${amount > 0 ? ' - $amount ${tracker.config.unit ?? 'units'}' : ''}';

        final dayColor = tracker.config.inputType == InputType.choice
            ? ColorUtils.getColorForChoice(
                (amount - 1).toInt(),
                optionColors: tracker.config.optionColors,
                fallback: _intensityColors.isNotEmpty
                    ? _intensityColors.first
                    : Colors.blue,
              )
            : tracker.config.inputType == InputType.toggle
            ? (amount > 0
                  ? (_intensityColors.isNotEmpty
                        ? _intensityColors.last
                        : Colors.blue)
                  : Colors.transparent)
            : ColorUtils.getColorForAmount(
                amount,
                preParsedColors: _intensityColors,
                maxValue:
                    tracker.config.intensityGoal ?? tracker.config.maxValue,
              );

        List<Color> gradient = _streakColors;

        if (inStreak && tracker.config.inputType == InputType.choice) {
          final yesterday = DateTime(date.year, date.month, date.day - 1);
          final tomorrow = DateTime(date.year, date.month, date.day + 1);

          Color getChoiceColor(DateTime d) {
            final e = entryMap[d];
            if (e != null && e.quantity > 0) {
              return ColorUtils.getColorForChoice(
                (e.quantity - 1).toInt(),
                optionColors: tracker.config.optionColors,
                fallback: _intensityColors.isNotEmpty
                    ? _intensityColors.first
                    : Colors.blue,
              );
            }
            return dayColor;
          }

          Color prevColor = isStart ? dayColor : getChoiceColor(yesterday);
          Color nextColor = isEnd ? dayColor : getChoiceColor(tomorrow);

          Color leftColor = Color.lerp(nextColor, dayColor, 0.5) ?? dayColor;
          Color rightColor = Color.lerp(prevColor, dayColor, 0.5) ?? dayColor;

          gradient = [leftColor, dayColor, rightColor];
        }

        return DayData(
          date: date,
          entry: entry,
          amount: amount,
          tooltip: tooltip,
          color: dayColor,
          streakGradient: gradient,
          inStreak: inStreak,
          isStreakStart: isStart,
          isStreakEnd: isEnd,
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

  Future<void> loadMorePastMonths() async {
    if (isLoading || state.isLoadingMore) return;

    state = state.copyWith(isLoadingMore: true);
    notifyListeners();

    final newStart = DateTime(
      _earliestLoaded.year,
      _earliestLoaded.month - _monthsPerBatch,
      1,
    );

    final entryRepo = await ref.read(entryRepositoryProvider.future);
    final older = await entryRepo.fetchEntriesInRange(
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

    // --- Synchronous Optimistic Update ---
    final now = DateTime.now();
    final index = _entries.indexWhere(
      (e) =>
          e.date.year == normalized.year &&
          e.date.month == normalized.month &&
          e.date.day == normalized.day,
    );

    if (index != -1) {
      final old = _entries[index];
      _entries[index] = Entry(
        id: old.id,
        tracker: old.tracker,
        date: old.date,
        quantity: amount,
        comment: old.comment,
        createdAt: old.createdAt,
        updatedAt: now,
      );
    } else {
      _entries.add(
        Entry(
          id: -1,
          tracker: tracker.id,
          date: normalized,
          quantity: amount,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    _updateState();
    // ------------------------------------

    final entryRepo = await ref.read(entryRepositoryProvider.future);
    await entryRepo.saveEntry(tracker.id, normalized, amount);
  }
}
