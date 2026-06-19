import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/providers.dart';
import '../widgets/tracker_calendar.dart';
import '../widgets/tracker_stats/tracker_stats_view.dart';
import '../logic/vault_provider.dart';

class TrackerCalendarScreen extends ConsumerStatefulWidget {
  const TrackerCalendarScreen({super.key, required this.tracker});

  final Tracker tracker;

  @override
  ConsumerState<TrackerCalendarScreen> createState() =>
      _TrackerCalendarScreenState();
}

class _TrackerCalendarScreenState extends ConsumerState<TrackerCalendarScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Eject user if vault locks and this is an encrypted tracker.
    // Must be in initState (not build) to avoid stale dependents on dispose.
    ref.listenManual<VaultState>(vaultProvider, (previous, next) {
      final wasUnlocked = previous?.isVaultUnlocked ?? false;
      final isUnlocked = next.isVaultUnlocked;
      if (wasUnlocked &&
          !isUnlocked &&
          widget.tracker.privacyLevel != PrivacyLevel.standard) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the live tracker so edits (title, privacy level, etc.) are
    // reflected immediately without a screen reload.
    final trackerList = ref.watch(trackerListProvider);
    final tracker = trackerList.when(
      data: (list) =>
          list.where((t) => t.id == widget.tracker.id).firstOrNull ??
          widget.tracker,
      loading: () => widget.tracker,
      error: (_, _) => widget.tracker,
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _currentPage == 0 ? tracker.title : 'Statistics',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_currentPage == 0 &&
                tracker.privacyLevel != PrivacyLevel.standard) ...[
              const SizedBox(width: 6),
              Icon(
                tracker.privacyLevel == PrivacyLevel.vault
                    ? Icons.lock_outline
                    : Icons.visibility_off,
                size: 18,
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _currentPage == 0
                  ? Icons.analytics_outlined
                  : Icons.calendar_month,
            ),
            onPressed: () {
              _pageController.animateToPage(
                _currentPage == 0 ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (page) => setState(() => _currentPage = page),
        children: [
          // Use widget.tracker (stable identity) so the calendar provider
          // isn't recreated when updateTrackerStreaks writes updatedAt to
          // the tracker collection and trackerListProvider re-emits.
          TrackerCalendar(tracker: widget.tracker),
          TrackerStatsView(tracker: widget.tracker),
        ],
      ),
    );
  }
}
