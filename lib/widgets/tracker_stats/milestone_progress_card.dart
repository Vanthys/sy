import 'package:flutter/material.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import '../../logic/tracker_stats_provider.dart';

class MilestoneProgressCard extends StatelessWidget {
  const MilestoneProgressCard({
    super.key,
    required this.stats,
    required this.accent,
  });

  final TrackerStats stats;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress =
        stats.currentStreak /
        (stats.nextMilestone == 0 ? 1 : stats.nextMilestone);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next Milestone: ${stats.nextMilestone} Days',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${stats.nextMilestone - stats.currentStreak} days remaining',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.local_fire_department, size: 16, color: accent),
                    const SizedBox(width: 4),
                    Text(
                      '${stats.currentStreak} day streak',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            height: 90,
            child: SleekCircularSlider(
              appearance: CircularSliderAppearance(
                customWidths: CustomSliderWidths(
                  progressBarWidth: 8,
                  trackWidth: 4,
                  handlerSize: 0,
                ),
                customColors: CustomSliderColors(
                  progressBarColor: accent,
                  trackColor: cs.outlineVariant,
                  hideShadow: true,
                ),
                infoProperties: InfoProperties(
                  mainLabelStyle: TextStyle(
                    color: cs.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  modifier: (double value) => '${(value).toInt()}%',
                ),
                startAngle: 270,
                angleRange: 360,
              ),
              min: 0,
              max: 100,
              initialValue: (progress * 100).clamp(0, 100).toDouble(),
            ),
          ),
        ],
      ),
    );
  }
}
