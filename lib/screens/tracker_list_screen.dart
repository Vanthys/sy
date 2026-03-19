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
    _scrollController.addListener(_onScroll);
    // Refresh streaks quietly in the background after the first frame
    Future.microtask(() async {
      try {
        await ref.read(refreshStreaksProvider(false).future);
      } catch (_) {
        // Isar may not be ready yet — this is fire-and-forget
      }
    });
  }

  Future<void> _openTrackerEditor(
    BuildContext context,
    WidgetRef ref, {
    Tracker? existing,
  }) async {
    final repo = await ref.read(trackerRepositoryProvider.future);
    final vaultState = ref.read(vaultProvider);
    if (!context.mounted) return;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
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
      final repo = await ref.read(trackerRepositoryProvider.future);
      await repo.deleteTracker(t.id);
    }
  }

  bool _showVaultHeader = false;
  bool _isUnlocking = false;
  bool _isCheckingVault = false;
  List<Tracker>? _pendingOrder; // Optimistic reorder state
  final _pinController = TextEditingController();
  final FocusNode _headerFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pinController.dispose();
    _headerFocus.dispose();
    super.dispose();
  }

  Future<void> _submitVaultPin(String pin) async {
    if (pin.isEmpty) return;
    if (mounted) setState(() => _isUnlocking = true);

    final notifier = ref.read(vaultProvider.notifier);
    final unlocked = await notifier.unlockVault(pin);

    if (unlocked) {
      try {
        await ref.read(trackerListProvider.future);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _showVaultHeader = false;
          _isUnlocking = false;
        });
      }
      _pinController.clear();
      _headerFocus.unfocus();
    } else {
      if (mounted) {
        setState(() => _isUnlocking = false);
        // Optional: Trigger a shake animation here later
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Incorrect Passphrase')));
        _pinController.clear();
      }
    }
  }

  Future<void> _unlockWithBiometrics() async {
    final notifier = ref.read(vaultProvider.notifier);
    final unlocked = await notifier.unlockVaultWithBiometrics();
    if (unlocked) {
      if (mounted) setState(() => _isUnlocking = true);
      try {
        await ref.read(trackerListProvider.future);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _showVaultHeader = false;
          _isUnlocking = false;
        });
      }
      _pinController.clear();
      _headerFocus.unfocus();
    }
  }

  void _onScroll() async {
    if (!_scrollController.hasClients) return;

    final vaultState = ref.read(vaultProvider);

    // Disallow triggering if vault is already unlocked
    if (vaultState.isVaultUnlocked) return;

    final pixels = _scrollController.position.pixels;

    // Only detect drag over-scrolls at the TOP of the list
    if (pixels < -120 && !_showVaultHeader && !_isCheckingVault) {
      _isCheckingVault = true;
      try {
        final isConfigured = await ref
            .read(vaultProvider.notifier)
            .isVaultConfigured();
        if (!mounted) return;
        
        if (!isConfigured) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vault is not configured. Go to Settings.'),
            ),
          );
          return;
        }

        setState(() => _showVaultHeader = true);
        // Add a tiny delay before requesting focus so animation can begin
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) _headerFocus.requestFocus();
        });
      } finally {
        _isCheckingVault = false;
      }
    } else if (pixels > 20 && _showVaultHeader) {
      // Hide if they scroll down normally
      if (mounted) {
        setState(() => _showVaultHeader = false);
        _headerFocus.unfocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the combined stream: handles loading/error from Isar + live updates
    final trackersAsync = ref.watch(trackerListProvider);
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
      body: trackersAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error loading data:\n$e')),
        data: (trackers) {
          // Use the optimistic order during a pending reorder, so the list
          // doesn't flicker back to the stale DB order mid-write.
          final displayTrackers = _pendingOrder ?? trackers;

          Widget listView;
          if (displayTrackers.isEmpty && !vaultState.isVaultUnlocked) {
            listView = ListView(
              controller: _scrollController,
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
            listView = ReorderableListView.builder(
              scrollController: _scrollController,
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) async {
                final isVaultUnlocked = ref.read(vaultProvider).isVaultUnlocked;
                final mutableTrackers = displayTrackers.toList();

                int adjustedOldPath = oldIndex;
                int adjustedNewPath = newIndex;

                if (isVaultUnlocked) {
                  // Index 0 is the vault banner. Don't reorder it.
                  if (oldIndex == 0) return;

                  // Adjust to 0-based index for the actual trackers list
                  adjustedOldPath = oldIndex - 1;
                  adjustedNewPath = newIndex - 1;

                  // If moving to the very top (where banner is), cap at index 0 of trackers
                  if (adjustedNewPath < 0) adjustedNewPath = 0;
                }

                if (adjustedNewPath > adjustedOldPath) adjustedNewPath--;
                if (adjustedOldPath == adjustedNewPath) return;

                final item = mutableTrackers.removeAt(adjustedOldPath);
                mutableTrackers.insert(adjustedNewPath, item);

                // Optimistic update: render the new order immediately so there's
                // no flicker back to the old order while the DB write happens.
                setState(() => _pendingOrder = mutableTrackers);

                final repo = await ref.read(trackerRepositoryProvider.future);
                await repo.reorderTrackers(
                  mutableTrackers.map((t) => t.id).toList(),
                );

                // Isar stream now emits the confirmed order — clear pending.
                if (mounted) setState(() => _pendingOrder = null);
              },
              proxyDecorator: (widget, index, animation) {
                return Material(color: Colors.transparent, child: widget);
              },
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.only(
                top: 8,
                left: 8,
                right: 8,
                bottom: 80,
              ),
              itemCount:
                  displayTrackers.length + (vaultState.isVaultUnlocked ? 1 : 0),
              itemBuilder: (context, i) {
                final key = vaultState.isVaultUnlocked && i == 0
                    ? const ValueKey('vault_banner')
                    : ValueKey(
                        displayTrackers[vaultState.isVaultUnlocked ? i - 1 : i]
                            .id,
                      );

                // If vault is unlocked, show a lock banner at the very top
                if (vaultState.isVaultUnlocked && i == 0) {
                  return Padding(
                    key: key,
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
                final tracker = displayTrackers[trackerIndex];

                return ReorderableDelayedDragStartListener(
                  key: key,
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 0),
                    child: TrackerOverviewCard(
                      tracker: tracker,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TrackerCalendarScreen(tracker: tracker),
                          ),
                        );
                      },
                      onEdit: () =>
                          _openTrackerEditor(context, ref, existing: tracker),
                      onDelete: () => _deleteTracker(context, ref, tracker),
                    ),
                  ),
                );
              },
            );
          }

          return Stack(
            children: [
              GestureDetector(
                onTap: () {
                  if (_showVaultHeader) {
                    setState(() => _showVaultHeader = false);
                    _headerFocus.unfocus();
                  }
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.02),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey('tracker_list_${displayTrackers.length}_${vaultState.isVaultUnlocked}'),
                    child: listView,
                  ),
                ),
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
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                            readOnly: _isUnlocking,
                            decoration: const InputDecoration(
                              hintText: 'Passphrase',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onSubmitted: _isUnlocking ? null : _submitVaultPin,
                          ),
                        ),
                        if (_isUnlocking)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: () =>
                                _submitVaultPin(_pinController.text),
                          ),
                        if (vaultState.isBiometricsEnabled && !_isUnlocking)
                          IconButton(
                            icon: const Icon(Icons.fingerprint, size: 20),
                            onPressed: _unlockWithBiometrics,
                          ),
                        if (!_isUnlocking)
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
          );
        },
      ),
    );
  }
}
