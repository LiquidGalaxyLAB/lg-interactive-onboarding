import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/providers/model_builder_providers.dart';

/// Widget with sliders for adjusting heading, tilt, roll, and scale X/Y/Z.
class OrientationSlidersWidget extends ConsumerWidget {
  const OrientationSlidersWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(modelBuilderProvider);
    final notifier = ref.read(modelBuilderProvider.notifier);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.tune,
                    color: theme.colorScheme.secondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Orientation & Scale',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: notifier.resetAdjustments,
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: const Text('Reset'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ─── Orientation Section ───────────────────────────
            _SectionLabel(label: 'ORIENTATION', theme: theme),
            const SizedBox(height: 8),

            _SliderRow(
              label: 'Heading',
              value: project.heading,
              min: 0,
              max: 360,
              suffix: '°',
              icon: Icons.explore,
              color: const Color(0xFF6C5CE7),
              onChanged: notifier.setHeading,
            ),

            _SliderRow(
              label: 'Tilt',
              value: project.tilt,
              min: 0,
              max: 90,
              suffix: '°',
              icon: Icons.screen_rotation,
              color: const Color(0xFF00B894),
              onChanged: notifier.setTilt,
            ),

            _SliderRow(
              label: 'Roll',
              value: project.roll,
              min: 0,
              max: 360,
              suffix: '°',
              icon: Icons.rotate_right,
              color: const Color(0xFFFDAA5E),
              onChanged: notifier.setRoll,
            ),

            const SizedBox(height: 16),
            Divider(color: theme.dividerColor),
            const SizedBox(height: 8),

            // ─── Scale Section ──────────────────────────────────
            _SectionLabel(label: 'SCALE', theme: theme),
            const SizedBox(height: 8),

            _SliderRow(
              label: 'X',
              value: project.scaleX,
              min: 0.1,
              max: 500.0,
              suffix: '',
              icon: Icons.swap_horiz,
              color: const Color(0xFFE17055),
              onChanged: notifier.setScaleX,
              decimals: 1,
            ),

            _SliderRow(
              label: 'Y',
              value: project.scaleY,
              min: 0.1,
              max: 500.0,
              suffix: '',
              icon: Icons.swap_vert,
              color: const Color(0xFF0984E3),
              onChanged: notifier.setScaleY,
              decimals: 1,
            ),

            _SliderRow(
              label: 'Z',
              value: project.scaleZ,
              min: 0.1,
              max: 500.0,
              suffix: '',
              icon: Icons.height,
              color: const Color(0xFFA29BFE),
              onChanged: notifier.setScaleZ,
              decimals: 1,
            ),

            const SizedBox(height: 12),

            // ─── Uniform Scale Shortcut ─────────────────────────
            Row(
              children: [
                Icon(Icons.link,
                    size: 14,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.4)),
                const SizedBox(width: 6),
                Text(
                  'Uniform',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF636E72),
                      thumbColor: const Color(0xFF636E72),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: project.scaleX.clamp(0.1, 500.0),
                      min: 0.1,
                      max: 500.0,
                      onChanged: notifier.setUniformScale,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Divider(color: theme.dividerColor),
            const SizedBox(height: 8),

            // ─── Altitude ───────────────────────────────────────
            _SectionLabel(label: 'ALTITUDE', theme: theme),
            const SizedBox(height: 8),

            _SliderRow(
              label: 'Alt',
              value: project.altitude,
              min: 0,
              max: 1000,
              suffix: 'm',
              icon: Icons.flight_takeoff,
              color: const Color(0xFF00CEC9),
              onChanged: notifier.setAltitude,
              decimals: 0,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper Widgets ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final ThemeData theme;

  const _SectionLabel({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String suffix;
  final IconData icon;
  final Color color;
  final ValueChanged<double> onChanged;
  final int decimals;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.icon,
    required this.color,
    required this.onChanged,
    this.decimals = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.12),
                inactiveTrackColor: color.withValues(alpha: 0.15),
                trackHeight: 3,
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              '${value.toStringAsFixed(decimals)}$suffix',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
