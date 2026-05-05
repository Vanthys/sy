import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/data/database.dart';
import '/data/providers.dart';
import '/data/tracker_config.dart';
import '/logic/vault_provider.dart';
import '/widgets/drag_drop_tracker_list.dart';
import '/widgets/folder_editor_sheet.dart';
import '/widgets/tracker_editor_sheet.dart';
import 'folder_tracker_screen.dart';
import 'settings_screen.dart';
import 'tracker_calendar_screen.dart';

class TrackerListScreen extends ConsumerStatefulWidget {
  const TrackerListScreen({super.key});

  @override
  ConsumerState<TrackerListScreen> createState() => _TrackerListScreenState();
}

class _TrackerListScreenState extends ConsumerState<TrackerListScreen> {
  bool _showVaultHeader = false;
  bool _isUnlocking = false;
  bool _isCheckingVault = false;
  List<String>? _pendingOrder; // optimistic visible-tracker ID order
  final _pinController = TextEditingController();
  final FocusNode _headerFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() async {
      try {
        await ref.read(refreshStreaksProvider(false).future);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pinController.dispose();
    _headerFocus.dispose();
    super.dispose();
  }

  Future<void> _openTrackerEditor(
    BuildContext context,
    WidgetRef ref, {
    Tracker? existing,
  }) async {
    final repo = await ref.read(trackerRepositoryProvider.future);
    if (!context.mounted) return;

    final bool? result;
    if (existing?.isFolder == true) {
      result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => FolderEditorSheet(repo: repo, existingFolder: existing),
      );
    } else {
      final vaultState = ref.read(vaultProvider);
      result = await showModalBottomSheet<bool>(
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
    }

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

  Future<void> _handleMerge(
    BuildContext context,
    Tracker dragged,
    Tracker target,
  ) async {
    final repo = await ref.read(trackerRepositoryProvider.future);

    if (target.isFolder) {
      final latest = await repo.getTrackerById(target.id) ?? target;
      final newChildIds = [...latest.childIds];
      if (!newChildIds.contains(dragged.id)) newChildIds.add(dragged.id);
      await repo.updateTracker(target.id, childIds: newChildIds);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${dragged.title}" to "${target.title}"'),
          ),
        );
      }
      return;
    }

    await repo.createTracker(
      title: target.title,
      streakType: StreakType.continued,
      config: const TrackerConfig(inputType: InputType.folder),
      childIds: [target.id, dragged.id],
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created folder "${target.title}"'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
    if (vaultState.isVaultUnlocked) return;

    final pixels = _scrollController.position.pixels;

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
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) _headerFocus.requestFocus();
        });
      } finally {
        _isCheckingVault = false;
      }
    } else if (pixels > 20 && _showVaultHeader) {
      if (mounted) {
        setState(() => _showVaultHeader = false);
        _headerFocus.unfocus();
      }
    }
  }

  Widget _buildVaultBanner(BuildContext context, VaultState vaultState) {
    return Padding(
      key: const ValueKey('vault_banner'),
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: () => ref.read(vaultProvider.notifier).lockVault(),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  vaultState.unlockedLevel == PrivacyLevel.secret
                      ? Icons.visibility_off
                      : Icons.lock_open,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  vaultState.unlockedLevel == PrivacyLevel.secret
                      ? 'Secret Vault Unlocked - Tap to Lock'
                      : 'Vault Unlocked - Tap to Lock',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
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

  @override
  Widget build(BuildContext context) {
    final trackersAsync = ref.watch(trackerListProvider);
    final vaultState = ref.watch(vaultProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trackers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
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
        error: (e, _) => Center(child: Text('Error loading data:\n$e')),
        data: (trackers) {
          final childIds = trackers
              .where((t) => t.isFolder)
              .expand((t) => t.childIds)
              .toSet();

          final List<Tracker> displayTrackers;
          if (_pendingOrder != null) {
            final map = {for (final t in trackers) t.id: t};
            displayTrackers = _pendingOrder!
                .map((id) => map[id])
                .whereType<Tracker>()
                .toList();
          } else {
            displayTrackers = trackers
                .where((t) => !childIds.contains(t.id))
                .toList();
          }

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
            listView = DragDropTrackerList(
              trackers: displayTrackers,
              scrollController: _scrollController,
              padding: const EdgeInsets.only(
                top: 8,
                left: 8,
                right: 8,
                bottom: 80,
              ),
              header: vaultState.isVaultUnlocked
                  ? _buildVaultBanner(context, vaultState)
                  : null,
              onTap: (t) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => t.isFolder
                      ? FolderTrackerScreen(folder: t)
                      : TrackerCalendarScreen(tracker: t),
                ),
              ),
              onEdit: (t) => _openTrackerEditor(context, ref, existing: t),
              onDelete: (t) => _deleteTracker(context, ref, t),
              onReorder: (newIds) async {
                setState(() => _pendingOrder = newIds);
                final repo = await ref.read(trackerRepositoryProvider.future);
                await repo.reorderTrackers(newIds);
                if (mounted) setState(() => _pendingOrder = null);
              },
              onMerge: (dragged, target) =>
                  _handleMerge(context, dragged, target),
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
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.02),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(
                      'tracker_list_${displayTrackers.length}_${vaultState.isVaultUnlocked}',
                    ),
                    child: listView,
                  ),
                ),
              ),

              // Dimming backdrop for vault header
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

              // Animated vault unlock header
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
