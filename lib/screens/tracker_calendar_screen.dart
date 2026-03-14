import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../widgets/tracker_calendar.dart';
import '../widgets/tracker_stats_view.dart';
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
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Eject user if vault locks and this is an encrypted tracker
    ref.listen(vaultProvider, (previous, next) {
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

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _currentPage == 0 ? widget.tracker.title : 'Statistics',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_currentPage == 0 &&
                widget.tracker.privacyLevel != PrivacyLevel.standard) ...[
              const SizedBox(width: 6),
              Icon(
                widget.tracker.privacyLevel == PrivacyLevel.vault
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
          TrackerCalendar(tracker: widget.tracker),
          TrackerStatsView(tracker: widget.tracker),
        ],
      ),
    );
  }
}
