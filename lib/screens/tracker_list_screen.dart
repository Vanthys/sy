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
    Future.microtask(() => ref.read(refreshStreaksProvider.future));
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

  Future<void> _handleVaultUnlock() async {
    final notifier = ref.read(vaultProvider.notifier);
    final isConfigured = await notifier.isVaultConfigured();

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
      final pinController = TextEditingController();
      final success = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unlock Vault'),
          content: TextField(
            controller: pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Enter PIN'),
            onSubmitted: (val) => Navigator.pop(context, true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Unlock'),
            ),
          ],
        ),
      );

      if (success == true) {
        final unlocked = await notifier.unlockVault(pinController.text);
        if (!unlocked && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Incorrect Vault PIN.')));
        }
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
          if (trackers.isEmpty && !vaultState.isVaultUnlocked) {
            return RefreshIndicator(
              onRefresh: _handleVaultUnlock,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
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
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _handleVaultUnlock,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
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
            ),
          );
        },
      ),
    );
  }
}
