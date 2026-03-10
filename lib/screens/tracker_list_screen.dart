import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/data/database.dart';
import '/data/providers.dart';
import '/logic/vault_provider.dart';
import '/widgets/tracker_editor_sheet.dart';
import '/widgets/tracker_overview_card.dart';
import 'settings_screen.dart';
import 'tracker_calendar_screen.dart';

class TrackerListScreen extends ConsumerStatefulWidget {
  const TrackerListScreen({super.key});

  @override
  ConsumerState<TrackerListScreen> createState() => _TrackerListScreenState();
}

class _TrackerListScreenState extends ConsumerState<TrackerListScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh streaks quietly in the background after the first frame
    Future.microtask(() => ref.read(refreshStreaksProvider(false).future));
  }

  Future<void> _openTrackerEditor(
    BuildContext context,
    WidgetRef ref, {
    Tracker? existing,
  }) async {
    final repo = ref.read(trackerRepositoryProvider);
    final vaultState = ref.read(vaultProvider);
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TrackerEditorSheet(
        repo: repo,
        vaultState: vaultState,
        existingTracker: existing,
      ),
    );

    if (result == true && context.mounted) {
      ref.invalidate(refreshStreaksProvider);
      // Trigger a forced refresh
      ref.read(refreshStreaksProvider(true).future);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null ? 'Tracker created' : 'Tracker updated',
          ),
        ),
      );
    }
  }

  Future<void> _deleteTracker(
    BuildContext context,
    WidgetRef ref,
    Tracker t,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete tracker?'),
        content: Text('This will remove "${t.title}" and all its entries.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(trackerRepositoryProvider).deleteTracker(t.id);
    }
  }

  bool _showVaultHeader = false;
  final _pinController = TextEditingController();
  final FocusNode _headerFocus = FocusNode();

  @override
  void dispose() {
    _pinController.dispose();
    _headerFocus.dispose();
    super.dispose();
  }

  Future<void> _submitVaultPin(String pin) async {
    final notifier = ref.read(vaultProvider.notifier);
    final unlocked = await notifier.unlockVault(pin);

    if (unlocked) {
      if (mounted) setState(() => _showVaultHeader = false);
      _pinController.clear();
      _headerFocus.unfocus();
    } else {
      if (mounted) {
        // Optional: Trigger a shake animation here later
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Incorrect Passphrase')));
        _pinController.clear();
      }
    }
  }

  void _onScrollUpdate(ScrollUpdateNotification notification) async {
    final vaultState = ref.read(vaultProvider);

    // Disallow triggering if vault is already unlocked
    if (vaultState.isVaultUnlocked) return;

    // Only detect drag over-scrolls at the TOP of the list
    if (notification.metrics.pixels < -120 && !_showVaultHeader) {
      final isConfigured = await ref
          .read(vaultProvider.notifier)
          .isVaultConfigured();
      if (!isConfigured) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vault is not configured. Go to Settings.'),
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() => _showVaultHeader = true);
        // Add a tiny delay before requesting focus so animation can begin
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) _headerFocus.requestFocus();
        });
      }
    } else if (notification.metrics.pixels > 20 && _showVaultHeader) {
      // Hide if they scroll down normally
      if (mounted) {
        setState(() => _showVaultHeader = false);
        _headerFocus.unfocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(trackerRepositoryProvider);
    final vaultState = ref.watch(vaultProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trackers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTrackerEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Tracker'),
      ),
      body: StreamBuilder<List<Tracker>>(
        stream: repo.watchAllTrackers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final trackers = snapshot.data!;
          Widget listView;
          if (trackers.isEmpty && !vaultState.isVaultUnlocked) {
            listView = ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                const Center(child: Text('No trackers yet.')),
                const SizedBox(height: 8),
                Center(
                  child: FilledButton(
                    onPressed: () => _openTrackerEditor(context, ref),
                    child: const Text('Create your first tracker'),
                  ),
                ),
              ],
            );
          } else {
            listView = ListView.separated(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.only(
                top: 8,
                left: 8,
                right: 8,
                bottom: 80,
              ),
              separatorBuilder: (_, _) => const SizedBox(height: 0),
              itemCount: trackers.length + (vaultState.isVaultUnlocked ? 1 : 0),
              itemBuilder: (context, i) {
                // If vault is unlocked, show a lock banner at the very top
                if (vaultState.isVaultUnlocked && i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Material(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.hardEdge,
                      child: InkWell(
                        onTap: () {
                          ref.read(vaultProvider.notifier).lockVault();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                vaultState.unlockedLevel == PrivacyLevel.secret
                                    ? Icons.visibility_off
                                    : Icons.lock_open,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                vaultState.unlockedLevel == PrivacyLevel.secret
                                    ? 'Secret Vault Unlocked - Tap to Lock'
                                    : 'Vault Unlocked - Tap to Lock',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                // Adjust index if we added the banner
                final trackerIndex = vaultState.isVaultUnlocked ? i - 1 : i;
                final tracker = trackers[trackerIndex];

                return TrackerOverviewCard(
                  tracker: tracker,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TrackerCalendarScreen(tracker: tracker),
                      ),
                    );
                  },
                  onEdit: () =>
                      _openTrackerEditor(context, ref, existing: tracker),
                  onDelete: () => _deleteTracker(context, ref, tracker),
                );
              },
            );
          }

          return NotificationListener<ScrollUpdateNotification>(
            onNotification: (notification) {
              _onScrollUpdate(notification);
              return false;
            },
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    if (_showVaultHeader) {
                      setState(() => _showVaultHeader = false);
                      _headerFocus.unfocus();
                    }
                  },
                  child: listView,
                ),

                // Dimming Backdrop
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !_showVaultHeader,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _showVaultHeader = false);
                        _headerFocus.unfocus();
                      },
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _showVaultHeader ? 1.0 : 0.0,
                        child: Container(color: Colors.black54),
                      ),
                    ),
                  ),
                ),

                // Animated Vault Header
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  top: _showVaultHeader ? 16 : -100,
                  left: 16,
                  right: 16,
                  child: Material(
                    elevation: 8,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(100),
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline, size: 20),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _pinController,
                              focusNode: _headerFocus,
                              obscureText: true,
                              decoration: const InputDecoration(
                                hintText: 'Passphrase',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onSubmitted: _submitVaultPin,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              setState(() => _showVaultHeader = false);
                              _headerFocus.unfocus();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
