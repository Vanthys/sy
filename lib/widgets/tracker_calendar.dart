import 'dart:async';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../data/entry_repository.dart';
import '../utils/color_utils.dart';
import 'month_section.dart';
import '../widgets/tracker_value_bottom_sheet.dart';

class TrackerCalendar extends StatefulWidget {
  const TrackerCalendar({
    super.key,
    required this.trackerId,
    required this.database,
    this.unitName,
    this.unitAbbreviation,
    this.streakType = StreakType.continued,
  });

  final String trackerId;
  final AppDatabase database;
  final String? unitName;
  final String? unitAbbreviation;
  final StreakType streakType;

  @override
  State<TrackerCalendar> createState() => _TrackerCalendarState();
}

class _TrackerCalendarState extends State<TrackerCalendar> {
  late final EntryRepository _repo;

  static const int _monthsPerBatch = 6;
  final ScrollController _scrollController = ScrollController();

  final List<Entry> _entries = [];

  late DateTime _latestMonth;
  late DateTime _earliestLoaded;

  bool _isLoadingMore = false;
  StreamSubscription<List<Entry>>? _entriesSub;

  @override
  void initState() {
    super.initState();
    _repo = EntryRepository(widget.database);

    final now = DateTime.now();
    _latestMonth = DateTime(now.year, now.month, 1);
    _earliestLoaded = DateTime(now.year, now.month - (_monthsPerBatch - 1), 1);

    _loadInitialEntries();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _entriesSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // ----------------------------------------
  // Database loading
  // ----------------------------------------

  void _loadInitialEntries() {
    _entriesSub?.cancel();
    _entriesSub = _repo
        .watchEntriesInRange(
          widget.trackerId,
          _earliestLoaded,
          _latestMonth.add(const Duration(days: 31)),
        )
        .listen((data) {
      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(data);
      });
    });
  }

  Future<void> _loadMorePastMonths() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    final newStart = DateTime(
      _earliestLoaded.year,
      _earliestLoaded.month - _monthsPerBatch,
      1,
    );

    final older = await _repo.fetchEntriesInRange(
      widget.trackerId,
      newStart,
      _earliestLoaded.add(const Duration(days: 1)),
    );

    setState(() {
      _entries.insertAll(0, older);
      _earliestLoaded = newStart;
      _isLoadingMore = false;
    });

    // 🆕 Restart watcher with new range so old saves update too
    _entriesSub?.cancel();
    _entriesSub = _repo
        .watchEntriesInRange(
          widget.trackerId,
          _earliestLoaded,
          _latestMonth.add(const Duration(days: 31)),
        )
        .listen((data) {
      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(data);
      });
    });
  }

  // ----------------------------------------
  // Scroll + UI logic
  // ----------------------------------------

  void _onScroll() {
    if (_isLoadingMore) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _loadMorePastMonths();
    }
  }

  Future<void> _handleSave(DateTime date, double amount) async {
    final normalized = DateTime(date.year, date.month, date.day);
    await _repo.saveEntry(widget.trackerId, normalized, amount);
  }

  // ----------------------------------------
  // Build UI
  // ----------------------------------------

  @override
  Widget build(BuildContext context) {
    final months = _groupEntriesIntoMonths(_entries);

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.separated(
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemCount: months.length,
            itemBuilder: (context, index) {
              final month = months[index];
              return MonthSection(
                monthLabel: month.label,
                days: month.days.reversed.toList(),
                unitAbbreviation: widget.unitAbbreviation,
                onDayTap: (dayData) async {
                  final result = await showTrackerValueBottomSheet(
                    context: context,
                    date: dayData.date,
                    initialAmount: dayData.entry?.quantity ?? 0,
                    unitName: widget.unitName ?? 'units',
                    maxValue: 12,
                  );
                  if (result != null) {
                    await _handleSave(dayData.date, result);
                  }
                },
                  streakType: widget.streakType,

              );
            },
          ),
        ),

        // Loading indicator
        SliverToBoxAdapter(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isLoadingMore
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------
  // Helpers
  // ----------------------------------------

  List<_MonthData> _groupEntriesIntoMonths(List<Entry> entries) {
    final grouped = <String, List<Entry>>{};
    for (final e in entries) {
      final key = DateFormat('yyyy-MM').format(e.date);
      grouped.putIfAbsent(key, () => []).add(e);
    }

    // 🆕 Compute streak days globally
    final streakDates = _computeCurrentStreakDates(widget.streakType, entries);

    final months = <_MonthData>[];
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

        final inStreak = streakDates.any(
          (d) => DateUtils.isSameDay(d, date),
        ); 

        return DayData(
          date: date,
          entry: entry,
          amount: amount,
          color: ColorUtils.getColorForAmount(amount),
          inStreak: inStreak, 
        );
      }).reversed.toList();

      months.add(
        _MonthData(
          monthStart: month,
          label: DateFormat('MMMM yyyy').format(month),
          days: days,
        ),
      );

      month = DateTime(month.year, month.month - 1, 1);
    }

    return months;
  }
}

// ----------------------------------------
// 🆕 Helper: Compute current streak days
// ----------------------------------------
List<DateTime> _computeCurrentStreakDates(
    StreakType type, List<Entry> entries) {
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

// ----------------------------------------
// Supporting models
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

class _MonthData {
  const _MonthData({
    required this.monthStart,
    required this.label,
    required this.days,
  });

  final DateTime monthStart;
  final String label;
  final List<DayData> days;
}
