import 'dart:async';
import 'package:flutter/material.dart';
import '/data/database.dart';
import 'tracker_overview_card.dart';

class DragDropTrackerList extends StatefulWidget {
  const DragDropTrackerList({
    super.key,
    required this.trackers,
    required this.scrollController,
    required this.padding,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
    required this.onMerge,
    this.header,
    this.physics,
  });

  final List<Tracker> trackers;
  final ScrollController scrollController;
  final EdgeInsets padding;
  final void Function(Tracker) onTap;
  final void Function(Tracker) onEdit;
  final void Function(Tracker) onDelete;
  final void Function(List<String> newOrderIds) onReorder;
  final void Function(Tracker dragged, Tracker target) onMerge;
  final Widget? header;
  final ScrollPhysics? physics;

  @override
  State<DragDropTrackerList> createState() => _DragDropTrackerListState();
}

class _DragDropTrackerListState extends State<DragDropTrackerList> {
  String? _draggingId;
  bool _draggingIsFolder = false;
  bool _dragStarting = false;
  int _insertIndex = 0;
  double _draggedHeight = 100.0;
  String? _mergeTargetId;
  bool _mergeReady = false;
  Timer? _mergeTimer;
  final Map<String, GlobalKey> _keys = {};

  @override
  void dispose() {
    _mergeTimer?.cancel();
    super.dispose();
  }

  GlobalKey _key(String id) => _keys.putIfAbsent(id, () => GlobalKey());

  // Trackers excluding the one currently being dragged.
  List<Tracker> get _remaining =>
      widget.trackers.where((t) => t.id != _draggingId).toList();

  void _startDrag(Tracker tracker) {
    final originalIndex = widget.trackers.indexWhere((t) => t.id == tracker.id);
    final box =
        _keys[tracker.id]?.currentContext?.findRenderObject() as RenderBox?;
    setState(() {
      _draggingId = tracker.id;
      _draggingIsFolder = tracker.isFolder;
      _dragStarting = true;
      _draggedHeight = box?.size.height ?? 100.0;
      // In remaining (excl. dragged card), this index keeps the gap at the
      // card's original slot so nothing visually jumps on drag start.
      _insertIndex = originalIndex;
    });
  }

  void _updateFromPointer(Offset globalPos) {
    if (_draggingId == null) return;
    _dragStarting = false;
    final remaining = _remaining;

    // --- Compute insert index (where the gap should appear) ---
    int newInsert = remaining.length;
    for (int i = 0; i < remaining.length; i++) {
      final box =
          _keys[remaining[i].id]?.currentContext?.findRenderObject()
              as RenderBox?;
      if (box == null) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (globalPos.dy < top + box.size.height / 2) {
        newInsert = i;
        break;
      }
    }

    // --- Compute merge target (center-zone hover) ---
    // Folders cannot be merged into other items.
    String? newMerge;
    if (!_draggingIsFolder) {
      for (final t in remaining) {
        final box =
            _keys[t.id]?.currentContext?.findRenderObject() as RenderBox?;
        if (box == null) continue;
        final top = box.localToGlobal(Offset.zero).dy;
        final h = box.size.height;
        if (globalPos.dy >= top && globalPos.dy <= top + h) {
          final localY = globalPos.dy - top;
          if (localY >= h * 0.3 && localY <= h * 0.7) newMerge = t.id;
          break;
        }
      }
    }

    final mergeChanged = newMerge != _mergeTargetId;
    if (mergeChanged) {
      _mergeTimer?.cancel();
      final isFolder =
          newMerge != null &&
          remaining.any((t) => t.id == newMerge && t.isFolder);
      setState(() {
        _mergeTargetId = newMerge;
        _mergeReady = isFolder; // folders accept immediately, no timer
      });
      if (newMerge != null && !isFolder) {
        _mergeTimer = Timer(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _mergeReady = true);
        });
      }
    }

    if (newInsert != _insertIndex || mergeChanged) {
      setState(() => _insertIndex = newInsert);
    }
  }

  void _onDrop(Tracker dragged) {
    _mergeTimer?.cancel();
    final mergeId = _mergeTargetId;
    final mergeReady = _mergeReady;
    final insertIndex = _insertIndex;
    setState(() {
      _draggingId = null;
      _draggingIsFolder = false;
      _dragStarting = false;
      _mergeTargetId = null;
      _mergeReady = false;
    });

    if (mergeId != null && mergeReady) {
      final target = widget.trackers.firstWhere((t) => t.id == mergeId);
      widget.onMerge(dragged, target);
    } else {
      final ids = widget.trackers
          .where((t) => t.id != dragged.id)
          .map((t) => t.id)
          .toList();
      ids.insert(insertIndex.clamp(0, ids.length), dragged.id);
      widget.onReorder(ids);
    }
  }

  void _cancelDrag() {
    _mergeTimer?.cancel();
    setState(() {
      _draggingId = null;
      _draggingIsFolder = false;
      _dragStarting = false;
      _mergeTargetId = null;
      _mergeReady = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasHeader = widget.header != null;
    // +1 for the trailing spacer item (handles insert-at-end).
    final itemCount = widget.trackers.length + (hasHeader ? 1 : 0) + 1;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerMove: (e) => _updateFromPointer(e.position),
      child: DragTarget<Tracker>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (d) => _onDrop(d.data),
        builder: (context, candidates, rejected) => ListView.builder(
          controller: widget.scrollController,
          physics:
              widget.physics ??
              const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
          padding: widget.padding,
          itemCount: itemCount,
          itemBuilder: (context, i) {
            // Header (vault banner etc.)
            if (hasHeader && i == 0) return widget.header!;

            final trackerIndex = hasHeader ? i - 1 : i;

            // Trailing end-of-list spacer
            if (trackerIndex == widget.trackers.length) {
              return AnimatedContainer(
                duration: (_draggingId != null && !_dragStarting)
                    ? const Duration(milliseconds: 200)
                    : Duration.zero,
                curve: Curves.easeOut,
                height:
                    _draggingId != null &&
                        _mergeTargetId == null &&
                        _insertIndex >= _remaining.length
                    ? _draggedHeight
                    : 0,
              );
            }

            return _buildItem(context, widget.trackers[trackerIndex]);
          },
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, Tracker tracker) {
    final cs = Theme.of(context).colorScheme;
    final isDragging = tracker.id == _draggingId;
    final isMergeTarget = tracker.id == _mergeTargetId && !isDragging;
    final showGlow = isMergeTarget && _mergeReady;
    final showHint = isMergeTarget && !_mergeReady;

    // Index of this card in the remaining list (excl. dragged card).
    final indexInRemaining = _remaining.indexWhere((t) => t.id == tracker.id);
    final showSpacer =
        _draggingId != null &&
        !isDragging &&
        _mergeTargetId == null &&
        indexInRemaining == _insertIndex;

    final feedbackWidth = MediaQuery.of(context).size.width - 16;

    return Column(
      key: _key(tracker.id),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Gap that opens at the insertion point as you drag.
        AnimatedContainer(
          duration: (_draggingId != null && !_dragStarting)
              ? const Duration(milliseconds: 200)
              : Duration.zero,
          curve: Curves.easeOut,
          height: showSpacer ? _draggedHeight : 0,
        ),
        LongPressDraggable<Tracker>(
          data: tracker,
          delay: const Duration(milliseconds: 350),
          onDragStarted: () => _startDrag(tracker),
          onDragEnd: (_) {
            // DragTarget.onAcceptWithDetails clears _draggingId first;
            // this guard handles the "dragged off-list" cancel case.
            if (_draggingId != null) _cancelDrag();
          },
          onDraggableCanceled: (velocity, offset) => _cancelDrag(),
          feedback: SizedBox(
            width: feedbackWidth,
            child: TrackerOverviewCard(
              tracker: tracker,
              onTap: () {},
              onEdit: () {},
              onDelete: () {},
            ),
          ),
          // Card vanishes from its original slot; the animated gap shows
          // where it will land — same feel as ReorderableListView.
          childWhenDragging: const SizedBox.shrink(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: showGlow
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.primary, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.25),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  )
                : showHint
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  )
                : const BoxDecoration(),
            child: TrackerOverviewCard(
              tracker: tracker,
              onTap: () => widget.onTap(tracker),
              onEdit: () => widget.onEdit(tracker),
              onDelete: () => widget.onDelete(tracker),
            ),
          ),
        ),
      ],
    );
  }
}
