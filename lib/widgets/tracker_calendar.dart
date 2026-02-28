import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../logic/tracker_calendar_provider.dart';
import 'month_section.dart';
import '../widgets/tracker_value_bottom_sheet.dart';

class TrackerCalendar extends ConsumerStatefulWidget {
  const TrackerCalendar({super.key, required this.tracker});

  final Tracker tracker;

  @override
  ConsumerState<TrackerCalendar> createState() => _TrackerCalendarState();
}

class _TrackerCalendarState extends ConsumerState<TrackerCalendar> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      ref
          .read(trackerCalendarProvider(widget.tracker).notifier)
          .loadMorePastMonths();
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(trackerCalendarProvider(widget.tracker));

    if (notifier.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final months = notifier.state.months;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        for (final month in months) ...[
          // Month Header
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                month.label,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          // Days Grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, dayIndex) {
                  final dayData = month.days[dayIndex];
                  return DayBlock(
                    dayData: dayData,
                    unitAbbreviation: widget.tracker.config.unit,
                    onTap: () async {
                      final result = await showTrackerValueBottomSheet(
                        context: context,
                        date: dayData.date,
                        initialAmount: dayData.entry?.quantity ?? 0,
                        unitName: widget.tracker.config.unit ?? 'units',
                        maxValue: widget.tracker.config.maxValue ?? 12,
                      );
                      if (result != null) {
                        await ref
                            .read(trackerCalendarProvider(widget.tracker))
                            .saveEntry(dayData.date, result);
                      }
                    },
                    streakType: widget.tracker.streakType,
                    streakColors: widget.tracker.config.streakColors,
                    columnIndex: dayIndex % 7,
                  );
                },
                childCount: month.days.length,
                addRepaintBoundaries: false,
                addAutomaticKeepAlives: false,
              ),
            ),
          ),
        ],

        // Loading indicator
        SliverToBoxAdapter(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: notifier.state.isLoadingMore
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
}
