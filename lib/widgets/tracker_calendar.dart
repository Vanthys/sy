import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../logic/theme_provider.dart';
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
  bool _didInitialScroll = false;
  ProviderSubscription<CalendarState>? _calendarSub;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Register once, outisde build so _didInitialScroll is never reset
    // by a widget rebuild and the subscription lifecycle is explicit.
    _calendarSub = ref.listenManual(
      trackerCalendarProvider(widget.tracker),
      _onCalendarState,
    );
  }

  @override
  void dispose() {
    _calendarSub?.close();
    _scrollController.dispose();
    super.dispose();
  }

  void _onCalendarState(CalendarState? prev, CalendarState next) {
    final reversed = ref.read(reverseMonthOrderProvider);
    if (!reversed || next.isLoading) return;

    if (!_didInitialScroll) {
      // First data load in reversed mode: jump to bottom (most recent month).
      _didInitialScroll = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
      return;
    }

    if (prev != null && next.months.length > prev.months.length) {
      // Older months prepended: shift offset by the added content height so
      // the visible position stays stable.
      final oldMax = _scrollController.hasClients
          ? _scrollController.position.maxScrollExtent
          : 0.0;
      final oldOffset = _scrollController.hasClients
          ? _scrollController.offset
          : 0.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final delta = _scrollController.position.maxScrollExtent - oldMax;
        _scrollController.jumpTo(oldOffset + delta);
      });
    }
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (!pos.hasContentDimensions || pos.maxScrollExtent <= 0) return;
    final reversed = ref.read(reverseMonthOrderProvider);
    // Reversed: oldest months at top (pixels ~ 0) -> load more when near top.
    // Normal: oldest months at bottom -> load more when near bottom.
    final nearLoadEdge = reversed
        ? pos.pixels <= 200
        : pos.pixels >= pos.maxScrollExtent - 200;
    if (nearLoadEdge) {
      ref
          .read(trackerCalendarProvider(widget.tracker).notifier)
          .loadMorePastMonths();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reversed = ref.watch(reverseMonthOrderProvider);
    final calendarState = ref.watch(trackerCalendarProvider(widget.tracker));

    if (calendarState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final months = calendarState.months;

    final loadingIndicator = SliverToBoxAdapter(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: calendarState.isLoadingMore
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : const SizedBox.shrink(),
      ),
    );

    List<Widget> buildMonthSlivers(MonthData month) {
      final header = SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        sliver: SliverToBoxAdapter(
          child: Text(
            month.label,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      );
      final grid = SliverPadding(
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
              if (dayData == null) return const SizedBox.shrink();
              return DayBlock(
                dayData: dayData,
                unitAbbreviation: widget.tracker.config.unit,
                inputType: widget.tracker.config.inputType,
                reversed: reversed,
                onTap: () async {
                  final result = await showTrackerValueBottomSheet(
                    context: context,
                    tracker: widget.tracker,
                    date: dayData.date,
                    initialAmount: dayData.entry?.quantity ?? 0,
                  );
                  if (result != null) {
                    await ref
                        .read(trackerCalendarProvider(widget.tracker).notifier)
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
      );
      return [header, grid];
    }

    // In reversed mode the loading indicator is at the top (older content).
    // In normal mode it is at the bottom.
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        if (reversed) loadingIndicator,
        for (final month in months) ...buildMonthSlivers(month),
        if (!reversed) loadingIndicator,
      ],
    );
  }
}
