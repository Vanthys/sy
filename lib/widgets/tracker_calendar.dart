import 'package:flutter/material.dart';
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
  });

  final String trackerId;
  final AppDatabase database;
  final String? unitName;
  final String? unitAbbreviation;

  @override
  State<TrackerCalendar> createState() => _TrackerCalendarState();
}

class _TrackerCalendarState extends State<TrackerCalendar> {
  late final EntryRepository _repo;
  List<Entry> entries = [];

  @override
  void initState() {
    super.initState();
    _repo = EntryRepository(widget.database);
     _repo.watchEntries(widget.trackerId).listen((data) {
    if (mounted) {
      setState(() => entries = data);
    }
  });
    
  }


Future<void> _handleSave(DateTime date, double amount) async {
  await _repo.saveEntry(widget.trackerId, date, amount);
}

  List<_MonthData> _generateMonthsData() {
    final today = DateTime.now();
    final Map<String, Entry> entriesByDate = {};

    for (final entry in entries) {
      final dateKey = DateFormat('yyyy-MM-dd').format(entry.date);
      entriesByDate[dateKey] = entry;
    }

    DateTime earliest = today.subtract(const Duration(days: 180));
    if (entries.isNotEmpty) {
      final sortedEntries = List<Entry>.from(entries)
        ..sort((a, b) => a.date.compareTo(b.date));
      earliest = sortedEntries.first.date;
    }

    DateTime current = DateTime(earliest.year, earliest.month, 1);
    final monthsData = <_MonthData>[];

    while (!current.isAfter(today)) {
      final monthStart = DateTime(current.year, current.month, 1);
      final monthLabel = DateFormat('MMMM yyyy').format(monthStart);

      final daysInMonth = DateTime(current.year, current.month + 1, 0).day;
      final days = <DayData>[];

      for (var day = 1; day <= daysInMonth; day++) {
        final date = DateTime(current.year, current.month, day);
        if (date.isAfter(today)) {
          break;
        }

        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        final entry = entriesByDate[dateKey];

        days.add(
          DayData(
            date: date,
            entry: entry,
            amount: entry?.quantity ?? 0,
            color: ColorUtils.getColorForAmount(entry?.quantity ?? 0),
          ),
        );
      }

      monthsData.add(
        _MonthData(monthStart: monthStart, label: monthLabel, days: days),
      );

      current = DateTime(current.year, current.month + 1, 1);
    }

    return monthsData;
  }

  
  @override
  Widget build(BuildContext context) {
    final monthsData = _generateMonthsData()
      ..sort((a, b) => b.monthStart.compareTo(a.monthStart));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: monthsData.length,
      itemBuilder: (context, index) {
        final month = monthsData[index];
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
              maxValue: 100, // or pass a tracker-specific max
            );

            if (result != null) {
              await _handleSave(dayData.date, result);
            }
          },
        );
      },
    );
  }
}

class DayData {
  const DayData({
    required this.date,
    this.entry,
    required this.amount,
    required this.color,
  });

  final DateTime date;
  final Entry? entry;
  final double amount;
  final Color color;
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
