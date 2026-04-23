import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/database.dart';
import '../data/providers.dart';
import '../data/tracker_config.dart';
import '../utils/color_utils.dart';

part 'tracker_calendar_provider.g.dart';

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

class CalendarState {
  final List<MonthData> months;
  final bool isLoading;
  final bool isLoadingMore;

  const CalendarState({
    required this.months,
    this.isLoading = false,
    this.isLoadingMore = false,
  });

  CalendarState copyWith({
    List<MonthData>? months,
    bool? isLoading,
    bool? isLoadingMore,
  }) {
    return CalendarState(
      months: months ?? this.months,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

@riverpod
class TrackerCalendarNotifier extends _$TrackerCalendarNotifier {
  static const int _monthsPerBatch = 6;

  late Tracker _tracker;
  late DateTime _latestMonth;
  late DateTime _earliestLoaded;
  StreamSubscription<List<Entry>>? _entriesSub;
  List<Entry> _entries = [];
  late List<Color> _streakColors;
  late List<Color> _intensityColors;

  @override
  CalendarState build(Tracker tracker) {
    _tracker = tracker;

    final now = DateTime.now();
    _latestMonth = DateTime(now.year, now.month, 1);
    _earliestLoaded = DateTime(now.year, now.month - (_monthsPerBatch - 1), 1);

    _streakColors = _parseStreakColors();
    _intensityColors = _parseIntensityColors();

    ref.onDispose(() => _entriesSub?.cancel());
    _setupStream();

    return const CalendarState(months: [], isLoading: true);
  }

  List<Color> _parseStreakColors() {
    if (_tracker.config.inputType == InputType.choice &&
        _tracker.config.optionColors != null) {
      final parsed = _tracker.config.optionColors!
          .map(ColorUtils.parseHexColor)
          .whereType<Color>()
          .toList();
      if (parsed.isNotEmpty) {
        if (parsed.length == 1) return [parsed.first, parsed.first];
        return parsed;
      }
    }

    final colors = _tracker.config.streakColors;
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
    final colors = _tracker.config.intensityColors;
    if (colors == null || colors.isEmpty) return [];
    return colors.map(ColorUtils.parseHexColor).whereType<Color>().toList();
  }

  void _setupStream() {
    _entriesSub?.cancel();
    ref.read(entryRepositoryProvider.future).then((entryRepo) {
      _entriesSub = entryRepo
          .watchEntriesInRange(
            _tracker.id,
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
    final months = _generateMonthsData();
    state = state.copyWith(
      months: months,
      isLoading: false,
    );
  }

  List<MonthData> _generateMonthsData() {
    final entryMap = <DateTime, Entry>{
      for (final entry in _entries)
        DateTime(entry.date.year, entry.date.month, entry.date.day): entry,
    };

    final meaningfulEntries = _entries
        .where((entry) => entry.quantity.round() > 0)
        .toList();
    final entryDatesSet = meaningfulEntries
        .map((entry) => DateTime(entry.date.year, entry.date.month, entry.date.day))
        .toSet();

    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);

    final createdAt = _tracker.createdAt;
    final createdAtMidnight = DateTime(
      createdAt.year,
      createdAt.month,
      createdAt.day,
    );

    final sortedDays = entryDatesSet.toList()..sort();
    final earliestEntry = sortedDays.isEmpty ? createdAtMidnight : sortedDays.first;
    final trackingStartDay = earliestEntry.isBefore(createdAtMidnight)
        ? earliestEntry
        : createdAtMidnight;

    final streakDatesSet = <DateTime>{};
    var current = todayMidnight;

    if (_tracker.streakType == StreakType.continued &&
        !entryDatesSet.contains(current)) {
      current = DateTime(current.year, current.month, current.day - 1);
    }

    bool isGoodDay(DateTime day) {
      final hasEntry = entryDatesSet.contains(day);
      return _tracker.streakType == StreakType.continued ? hasEntry : !hasEntry;
    }

    while (isGoodDay(current) && !current.isBefore(trackingStartDay)) {
      streakDatesSet.add(current);
      current = DateTime(current.year, current.month, current.day - 1);
    }

    final months = <MonthData>[];
    var month = _latestMonth;

    while (month.isAfter(_earliestLoaded) ||
        month.isAtSameMomentAs(_earliestLoaded)) {
      final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
      final monthEnd = DateTime(month.year, month.month, daysInMonth);
      final maxVisibleDate = monthEnd.isAfter(todayMidnight)
          ? todayMidnight
          : monthEnd;
      final visibleDaysCount = maxVisibleDate.day;

      final days = List.generate(visibleDaysCount, (index) {
        final date = DateTime(
          month.year,
          month.month,
          visibleDaysCount - index,
        );
        final entry = entryMap[date];
        final amount = entry?.quantity ?? 0.0;
        final inStreak = streakDatesSet.contains(date);

        var isStart = false;
        var isEnd = false;

        if (inStreak) {
          final yesterday = DateTime(date.year, date.month, date.day - 1);
          final tomorrow = DateTime(date.year, date.month, date.day + 1);
          isStart = !streakDatesSet.contains(yesterday);
          isEnd = !streakDatesSet.contains(tomorrow);
        }

        final tooltip =
            '${DateFormat('yyyy-MM-dd').format(date)}${amount > 0 ? ' - $amount ${_tracker.config.unit ?? 'units'}' : ''}';

        final dayColor = _tracker.config.inputType == InputType.choice
            ? ColorUtils.getColorForChoice(
                (amount - 1).toInt(),
                optionColors: _tracker.config.optionColors,
                fallback: _intensityColors.isNotEmpty
                    ? _intensityColors.first
                    : Colors.blue,
              )
            : _tracker.config.inputType == InputType.toggle
            ? (amount > 0
                  ? (_intensityColors.isNotEmpty
                        ? _intensityColors.last
                        : Colors.blue)
                  : Colors.transparent)
            : ColorUtils.getColorForAmount(
                amount,
                preParsedColors: _intensityColors,
                maxValue: _tracker.config.intensityGoal ?? _tracker.config.maxValue,
              );

        var gradient = _streakColors;

        if (inStreak && _tracker.config.inputType == InputType.choice) {
          final yesterday = DateTime(date.year, date.month, date.day - 1);
          final tomorrow = DateTime(date.year, date.month, date.day + 1);

          Color getChoiceColor(DateTime day) {
            final foundEntry = entryMap[day];
            if (foundEntry != null && foundEntry.quantity > 0) {
              return ColorUtils.getColorForChoice(
                (foundEntry.quantity - 1).toInt(),
                optionColors: _tracker.config.optionColors,
                fallback: _intensityColors.isNotEmpty
                    ? _intensityColors.first
                    : Colors.blue,
              );
            }
            return dayColor;
          }

          final prevColor = isStart ? dayColor : getChoiceColor(yesterday);
          final nextColor = isEnd ? dayColor : getChoiceColor(tomorrow);

          final leftColor = Color.lerp(nextColor, dayColor, 0.5) ?? dayColor;
          final rightColor = Color.lerp(prevColor, dayColor, 0.5) ?? dayColor;

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
      });

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
    if (state.isLoading || state.isLoadingMore) return;

    state = state.copyWith(isLoadingMore: true);

    final newStart = DateTime(
      _earliestLoaded.year,
      _earliestLoaded.month - _monthsPerBatch,
      1,
    );

    final entryRepo = await ref.read(entryRepositoryProvider.future);
    final older = await entryRepo.fetchEntriesInRange(
      _tracker.id,
      newStart,
      _earliestLoaded.add(const Duration(days: 1)),
    );

    _entries.insertAll(0, older);
    _earliestLoaded = newStart;

    _setupStream();

    state = state.copyWith(isLoadingMore: false);
  }

  Future<void> saveEntry(DateTime date, double amount) async {
    final normalized = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final index = _entries.indexWhere(
      (entry) =>
          entry.date.year == normalized.year &&
          entry.date.month == normalized.month &&
          entry.date.day == normalized.day,
    );

    if (index != -1) {
      if (amount > 0) {
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
        _entries.removeAt(index);
      }
    } else if (amount > 0) {
      _entries.add(
        Entry(
          id: -1,
          tracker: _tracker.id,
          date: normalized,
          quantity: amount,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    _updateState();

    final entryRepo = await ref.read(entryRepositoryProvider.future);
    await entryRepo.saveEntry(_tracker.id, normalized, amount);
  }
}
