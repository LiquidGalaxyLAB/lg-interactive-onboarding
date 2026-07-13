import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/data/scene_models.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/providers/model_builder_providers.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/providers/scene_providers.dart';

const double _scaleMin = 0.1;
const double _scaleMax = 10000.0;

/// Widget with sliders/inputs for adjusting heading, tilt, roll, and scale X/Y/Z.
///
/// Scene-aware: when exactly one [ModelNode] is selected in the scene outliner,
/// sliders bind to that node's transforms via [SceneNotifier]. Otherwise,
/// they control the current import via [ModelBuilderNotifier].
class OrientationSlidersWidget extends ConsumerWidget {
  const OrientationSlidersWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(modelBuilderProvider);
    final notifier = ref.read(modelBuilderProvider.notifier);
    // final sceneState = ref.watch(sceneProvider);
    final theme = Theme.of(context);

    /*
    // ── Scene-aware mode: editing a selected scene node ────────────
    final ModelNode? editingNode;
    if (sceneState.hasScene &&
        sceneState.selectedNodeIds.length == 1) {
      final node = sceneState.activeScene!
          .nodes[sceneState.selectedNodeIds.first];
      editingNode = node is ModelNode ? node : null;
    } else {
      editingNode = null;
    }
    */

    /*
    // Resolve the values and setters based on mode
    final double heading;
    final double tilt;
    final double roll;
    final double scaleX;
    final double scaleY;
    final double scaleZ;
    final double altitude;
    final void Function(double) onHeading;
    final void Function(double) onTilt;
    final void Function(double) onRoll;
    final void Function(double) onScaleX;
    final void Function(double) onScaleY;
    final void Function(double) onScaleZ;
    final void Function(double) onUniformScale;
    final void Function(double) onAltitude;
    final VoidCallback onReset;

    if (editingNode != null) {
      // Reading from scene node
      heading = editingNode.heading;
      tilt = editingNode.tilt;
      roll = editingNode.roll;
      scaleX = editingNode.scaleX;
      scaleY = editingNode.scaleY;
      scaleZ = editingNode.scaleZ;
      altitude = editingNode.altitude;

      final nodeId = editingNode.id;
      final sceneNotifier = ref.read(sceneProvider.notifier);
      onHeading = (v) => sceneNotifier.setNodeTransform(nodeId, heading: v);
      onTilt = (v) => sceneNotifier.setNodeTransform(nodeId, tilt: v);
      onRoll = (v) => sceneNotifier.setNodeTransform(nodeId, roll: v);
      onScaleX = (v) => sceneNotifier.setNodeTransform(nodeId, scaleX: v);
      onScaleY = (v) => sceneNotifier.setNodeTransform(nodeId, scaleY: v);
      onScaleZ = (v) => sceneNotifier.setNodeTransform(nodeId, scaleZ: v);
      onUniformScale = (v) => sceneNotifier.setNodeTransform(
            nodeId,
            scaleX: v,
            scaleY: v,
            scaleZ: v,
          );
      onAltitude = (v) => sceneNotifier.setNodeTransform(nodeId, altitude: v);
      onReset = () => sceneNotifier.setNodeTransform(
            nodeId,
            heading: 0,
            tilt: 0,
            roll: 0,
            scaleX: 1000,
            scaleY: 1000,
            scaleZ: 1000,
            altitude: 10,
          );
    } else {
      // Default: editing the current import project
      heading = project.heading;
      tilt = project.tilt;
      roll = project.roll;
      scaleX = project.scaleX;
      scaleY = project.scaleY;
      scaleZ = project.scaleZ;
      altitude = project.altitude;
      onHeading = notifier.setHeading;
      onTilt = notifier.setTilt;
      onRoll = notifier.setRoll;
      onScaleX = notifier.setScaleX;
      onScaleY = notifier.setScaleY;
      onScaleZ = notifier.setScaleZ;
      onUniformScale = notifier.setUniformScale;
      onAltitude = notifier.setAltitude;
      onReset = notifier.resetAdjustments;
    }
    */

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

            // ─── Scale Section (with slider/manual toggle) ─────
            _ScaleSection(
              project: project,
              notifier: notifier,
              theme: theme,
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

// ─── Scale Section ───────────────────────────────────────────────────────────

/// Stateful section that owns the slider ↔ manual-entry toggle for X/Y/Z scale.
class _ScaleSection extends StatefulWidget {
  final dynamic project;
  final dynamic notifier;
  final ThemeData theme;

  const _ScaleSection({
    required this.project,
    required this.notifier,
    required this.theme,
  });

  @override
  State<_ScaleSection> createState() => _ScaleSectionState();
}

class _ScaleSectionState extends State<_ScaleSection> {
  bool _manualMode = false;

  // Controllers for manual entry — initialised lazily in initState.
  late final TextEditingController _xCtrl;
  late final TextEditingController _yCtrl;
  late final TextEditingController _zCtrl;

  @override
  void initState() {
    super.initState();
    _xCtrl = TextEditingController(
        text: widget.project.scaleX.toStringAsFixed(1));
    _yCtrl = TextEditingController(
        text: widget.project.scaleY.toStringAsFixed(1));
    _zCtrl = TextEditingController(
        text: widget.project.scaleZ.toStringAsFixed(1));
  }

  /// Sync text controllers when slider values change externally (e.g. Reset).
  @override
  void didUpdateWidget(_ScaleSection old) {
    super.didUpdateWidget(old);
    if (!_manualMode) {
      _xCtrl.text = widget.project.scaleX.toStringAsFixed(1);
      _yCtrl.text = widget.project.scaleY.toStringAsFixed(1);
      _zCtrl.text = widget.project.scaleZ.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _xCtrl.dispose();
    _yCtrl.dispose();
    _zCtrl.dispose();
    super.dispose();
  }

  void _applyManual(TextEditingController ctrl, void Function(double) setter) {
    final v = double.tryParse(ctrl.text);
    if (v != null) {
      // No upper cap in manual mode — the user intentionally typed a large value.
      // Only enforce the minimum to prevent zero/negative scales.
      setter(v < _scaleMin ? _scaleMin : v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final project = widget.project;
    final notifier = widget.notifier;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── SCALE header + toggle ──────────────────────────────
        Row(
          children: [
            _SectionLabel(label: 'SCALE', theme: theme),
            const Spacer(),
            // Pill toggle: Slider | Manual
            _ModeToggle(
              manualMode: _manualMode,
              isDark: isDark,
              onChanged: (val) {
                setState(() {
                  _manualMode = val;
                  if (val) {
                    // Entering manual: populate fields with current values.
                    _xCtrl.text = project.scaleX.toStringAsFixed(1);
                    _yCtrl.text = project.scaleY.toStringAsFixed(1);
                    _zCtrl.text = project.scaleZ.toStringAsFixed(1);
                  }
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ─── Slider mode ────────────────────────────────────────
        if (!_manualMode) ...[
          _SliderRow(
            label: 'X',
            value: project.scaleX,
            min: _scaleMin,
            max: _scaleMax,
            suffix: '',
            icon: Icons.swap_horiz,
            color: const Color(0xFFE17055),
            onChanged: notifier.setScaleX,
            decimals: 1,
          ),
          _SliderRow(
            label: 'Y',
            value: project.scaleY,
            min: _scaleMin,
            max: _scaleMax,
            suffix: '',
            icon: Icons.swap_vert,
            color: const Color(0xFF0984E3),
            onChanged: notifier.setScaleY,
            decimals: 1,
          ),
          _SliderRow(
            label: 'Z',
            value: project.scaleZ,
            min: _scaleMin,
            max: _scaleMax,
            suffix: '',
            icon: Icons.height,
            color: const Color(0xFFA29BFE),
            onChanged: notifier.setScaleZ,
            decimals: 1,
          ),
          const SizedBox(height: 12),
          // Uniform slider
          Row(
            children: [
              Icon(Icons.link,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text(
                'Uniform',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
                    value: project.scaleX.clamp(_scaleMin, _scaleMax),
                    min: _scaleMin,
                    max: _scaleMax,
                    onChanged: notifier.setUniformScale,
                  ),
                ),
              ),
            ],
          ),
        ],

        // ─── Manual entry mode ──────────────────────────────────
        if (_manualMode) ...[
          _ManualScaleField(
            label: 'X',
            icon: Icons.swap_horiz,
            color: const Color(0xFFE17055),
            controller: _xCtrl,
            isDark: isDark,
            onSubmit: () => _applyManual(_xCtrl, notifier.setScaleX),
          ),
          const SizedBox(height: 10),
          _ManualScaleField(
            label: 'Y',
            icon: Icons.swap_vert,
            color: const Color(0xFF0984E3),
            controller: _yCtrl,
            isDark: isDark,
            onSubmit: () => _applyManual(_yCtrl, notifier.setScaleY),
          ),
          const SizedBox(height: 10),
          _ManualScaleField(
            label: 'Z',
            icon: Icons.height,
            color: const Color(0xFFA29BFE),
            controller: _zCtrl,
            isDark: isDark,
            onSubmit: () => _applyManual(_zCtrl, notifier.setScaleZ),
          ),
          const SizedBox(height: 12),
          // Apply all button
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () {
                _applyManual(_xCtrl, notifier.setScaleX);
                _applyManual(_yCtrl, notifier.setScaleY);
                _applyManual(_zCtrl, notifier.setScaleZ);
                FocusScope.of(context).unfocus();
              },
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Apply Scale'),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Pill Toggle Widget ───────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final bool manualMode;
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const _ModeToggle({
    required this.manualMode,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pillBg = isDark ? const Color(0xFF1C2236) : const Color(0xFFF0F0F5);
    final activeBg = theme.colorScheme.primary;
    final inactiveText =
        theme.colorScheme.onSurface.withValues(alpha: 0.5);

    Widget pill(String label, IconData icon, bool active, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: active ? Colors.white : inactiveText,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : inactiveText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pill(
            'Slider',
            Icons.tune,
            !manualMode,
            () => onChanged(false),
          ),
          pill(
            'Manual',
            Icons.edit_rounded,
            manualMode,
            () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

// ─── Manual Scale Field ───────────────────────────────────────────────────────

class _ManualScaleField extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final TextEditingController controller;
  final bool isDark;
  final VoidCallback onSubmit;

  const _ManualScaleField({
    required this.label,
    required this.icon,
    required this.color,
    required this.controller,
    required this.isDark,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        SizedBox(
          width: 28,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              hintText: '0.1 – 10000',
              hintStyle: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: color.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: color, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: color.withValues(alpha: isDark ? 0.25 : 0.2),
                ),
              ),
              suffixIcon: IconButton(
                icon: Icon(Icons.check_circle_outline,
                    size: 18, color: color),
                onPressed: onSubmit,
                tooltip: 'Apply',
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(
            double.tryParse(controller.text)
                    ?.toStringAsFixed(1)
                    .toString() ??
                '—',
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

// ─── Helper Widgets ──────────────────────────────────────────────────────────

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
