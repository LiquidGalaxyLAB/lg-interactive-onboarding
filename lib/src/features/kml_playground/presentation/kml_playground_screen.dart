import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';
import 'package:lg_interactive_onboarding/src/features/kml_playground/application/playground_controller.dart';
import 'package:lg_interactive_onboarding/src/features/kml_playground/domain/kml_template.dart';
import 'package:lg_interactive_onboarding/src/features/kml_playground/presentation/widgets/playground_map_widget.dart';
import 'package:lg_interactive_onboarding/src/features/kml_playground/presentation/widgets/polygon_vertex_map_widget.dart';
import 'package:lg_interactive_onboarding/src/features/kml_playground/presentation/widgets/two_point_map_widget.dart';

/// KML Playground — a vertical, card-based screen matching the Model Builder
/// layout pattern. Works in both portrait and landscape.
class KmlPlaygroundScreen extends ConsumerWidget {
  const KmlPlaygroundScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playgroundControllerProvider);
    final ssh = ref.watch(sshServiceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('KML Playground'),
        actions: [
          // Connection status
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (ssh.isConnected
                        ? const Color(0xFF7FB069)
                        : const Color(0xFFC0392B))
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ssh.isConnected
                          ? const Color(0xFF7FB069)
                          : const Color(0xFFC0392B),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    ssh.isConnected ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: ssh.isConnected
                          ? const Color(0xFF7FB069)
                          : const Color(0xFFC0392B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset All',
            onPressed: () {
              ref.read(playgroundControllerProvider.notifier).clear();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Playground reset')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Card 1: Template Selector ──────────────────────────────
          _TemplateSelectorCard(theme: theme),
          const SizedBox(height: 16),

          // ── Card 2: Tip / Did You Know ────────────────────────────
          if (state.activeTemplate?.tip != null) ...[
            _TipCard(tip: state.activeTemplate!.tip!, theme: theme),
            const SizedBox(height: 16),
          ],

          // ── Card 3: Visual Tweaker (Parameters) ───────────────────
          if (state.activeTemplate != null) ...[
            _ParametersCard(theme: theme),
            const SizedBox(height: 16),
          ],

          // ── Card 4: KML Code Viewer ───────────────────────────────
          if (state.generatedKml != null) ...[
            _KmlCodeCard(theme: theme),
            const SizedBox(height: 16),
          ],

          // ── Card 5: Push to LG ────────────────────────────────────
          if (state.activeTemplate != null) ...[
            _PushToLGCard(theme: theme),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TEMPLATE SELECTOR CARD
// ═══════════════════════════════════════════════════════════════════════

class _TemplateSelectorCard extends ConsumerWidget {
  final ThemeData theme;
  const _TemplateSelectorCard({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playgroundControllerProvider);
    final templates = KmlTemplate.predefinedTemplates;

    // Group by category
    final grouped = <TemplateCategory, List<KmlTemplate>>{};
    for (final t in templates) {
      grouped.putIfAbsent(t.category, () => []).add(t);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF009688).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.science, color: Color(0xFF009688), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Choose a Template',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      Text('Select a KML element to experiment with',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: state.activeTemplate != null
                        ? Colors.greenAccent.withValues(alpha: 0.15)
                        : theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    state.activeTemplate != null ? '✓ ${state.activeTemplate!.name}' : 'Step 1',
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: state.activeTemplate != null
                          ? Colors.greenAccent[400]
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Render each category
            for (final category in TemplateCategory.values) ...[
              if (grouped.containsKey(category)) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Text(
                    category.displayName.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF009688),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: grouped[category]!.map((t) {
                    final isActive = state.activeTemplate?.id == t.id;
                    return ChoiceChip(
                      avatar: Icon(t.icon, size: 18),
                      label: Text(t.name),
                      selected: isActive,
                      selectedColor: const Color(0xFF009688).withValues(alpha: 0.2),
                      onSelected: (_) {
                        ref.read(playgroundControllerProvider.notifier).setTemplate(t);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TIP CARD (Did You Know?)
// ═══════════════════════════════════════════════════════════════════════

class _TipCard extends StatelessWidget {
  final String tip;
  final ThemeData theme;
  const _TipCard({required this.tip, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF009688).withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lightbulb_outline, color: Color(0xFF009688), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tip,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PARAMETERS CARD (Visual Tweaker)
// ═══════════════════════════════════════════════════════════════════════

class _ParametersCard extends ConsumerWidget {
  final ThemeData theme;
  const _ParametersCard({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playgroundControllerProvider);
    final template = state.activeTemplate!;
    final params = state.activeParameters;
    final controller = ref.read(playgroundControllerProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.tune, color: Color(0xFF6C5CE7), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Visual Tweaker',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      Text('Adjust parameters — KML updates live',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.restart_alt, size: 20),
                  tooltip: 'Reset to defaults',
                  onPressed: () => controller.resetParameters(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Polygon vertex picker — shown when template uses 'vertices'
            if (template.parameters.any((p) => p.fieldType == ParamFieldType.polygonVertices)) ...[              
              PolygonVertexMapWidget(
                vertices: List<Map<String, double>>.from(
                  (params['vertices'] as List? ?? []).map(
                    (v) => Map<String, double>.from(v as Map),
                  ),
                ),
                onAddVertex: (lat, lng) => controller.addVertex(lat, lng),
                onRemoveVertex: (i) => controller.removeVertex(i),
                onClearAll: () => controller.clearVertices(),
              ),
              const SizedBox(height: 16),
            ] else if (template.parameters.any((p) => p.fieldType == ParamFieldType.twoPointMap)) ...[
              TwoPointMapWidget(
                startLat: (params['startLatitude'] as num?)?.toDouble() ?? 0.0,
                startLng: (params['startLongitude'] as num?)?.toDouble() ?? 0.0,
                endLat: (params['endLatitude'] as num?)?.toDouble() ?? 0.0,
                endLng: (params['endLongitude'] as num?)?.toDouble() ?? 0.0,
                onChanged: (lat, lng, {required isStart}) {
                  if (isStart) {
                    controller.updateParameter('startLatitude', lat);
                    controller.updateParameter('startLongitude', lng);
                  } else {
                    controller.updateParameter('endLatitude', lat);
                    controller.updateParameter('endLongitude', lng);
                  }
                },
              ),
              const SizedBox(height: 16),
            ] else if (template.parameters.any((p) => p.id == 'latitude') &&
                template.parameters.any((p) => p.id == 'longitude')) ...[
              PlaygroundMapWidget(
                latitude: (params['latitude'] as num?)?.toDouble() ?? 0.0,
                longitude: (params['longitude'] as num?)?.toDouble() ?? 0.0,
                onLocationChanged: (lat, lng) {
                  controller.updateParameter('latitude', lat);
                  controller.updateParameter('longitude', lng);
                },
              ),
              const SizedBox(height: 16),
            ],
            // Dynamic parameter fields
            for (final param in template.parameters) ...[
              if (param.id != 'latitude' && param.id != 'longitude' &&
                  param.id != 'startLatitude' && param.id != 'startLongitude' &&
                  param.id != 'endLatitude' && param.id != 'endLongitude' &&
                  param.fieldType != ParamFieldType.polygonVertices &&
                  param.fieldType != ParamFieldType.twoPointMap) ...[
                _buildField(context, ref, param, params[param.id], controller),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildField(BuildContext context, WidgetRef ref, KmlParameter param,
      dynamic value, PlaygroundController controller) {
    switch (param.fieldType) {
      case ParamFieldType.text:
        return TextFormField(
          key: ValueKey('${param.id}_text'),
          initialValue: value?.toString() ?? '',
          decoration: InputDecoration(
            labelText: param.label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => controller.updateParameter(param.id, v),
        );

      case ParamFieldType.number:
        final numValue = (value is num) ? value.toDouble() : 0.0;
        final hasSliderRange = param.min != null && param.max != null;
        // Use slider for bounded ranges, text field for large ranges
        if (hasSliderRange && (param.max! - param.min!) <= 500) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(param.label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
                  Text(numValue.toStringAsFixed(numValue.truncateToDouble() == numValue ? 1 : 4),
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                ],
              ),
              Slider(
                value: numValue.clamp(param.min!, param.max!),
                min: param.min!,
                max: param.max!,
                divisions: ((param.max! - param.min!) * 100).round().clamp(1, 1000),
                onChanged: (v) => controller.updateParameter(param.id, v),
              ),
            ],
          );
        }
        return TextFormField(
          key: ValueKey('${param.id}_num'),
          initialValue: numValue.toString(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: param.label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) {
            final parsed = double.tryParse(v);
            if (parsed != null) controller.updateParameter(param.id, parsed);
          },
        );

      case ParamFieldType.dropdown:
        return DropdownButtonFormField<String>(
          initialValue: value?.toString(),
          decoration: InputDecoration(
            labelText: param.label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          items: (param.options ?? [])
              .map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13))))
              .toList(),
          onChanged: (v) {
            if (v != null) controller.updateParameter(param.id, v);
          },
        );

      case ParamFieldType.url:
        return TextFormField(
          key: ValueKey('${param.id}_url'),
          initialValue: value?.toString() ?? '',
          decoration: InputDecoration(
            labelText: param.label,
            border: const OutlineInputBorder(),
            isDense: true,
            prefixIcon: const Icon(Icons.link, size: 18),
          ),
          onChanged: (v) => controller.updateParameter(param.id, v),
        );

      case ParamFieldType.color:
        return TextFormField(
          key: ValueKey('${param.id}_color'),
          initialValue: value?.toString() ?? '',
          decoration: InputDecoration(
            labelText: '${param.label} (ABGR hex)',
            border: const OutlineInputBorder(),
            isDense: true,
            prefixIcon: Container(
              width: 20, height: 20,
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _parseAbgrColor(value?.toString() ?? 'ffffffff'),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade400),
              ),
            ),
          ),
          onChanged: (v) => controller.updateParameter(param.id, v),
        );

      case ParamFieldType.coordinates:
        return TextFormField(
          key: ValueKey('${param.id}_coords'),
          initialValue: value?.toString() ?? '',
          decoration: InputDecoration(
            labelText: param.label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => controller.updateParameter(param.id, v),
        );

      case ParamFieldType.boolean:
        final boolValue = value is bool ? value : false;
        return SwitchListTile(
          title: Text(param.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          value: boolValue,
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          activeColor: const Color(0xFF00B894),
          onChanged: (v) => controller.updateParameter(param.id, v),
        );

      case ParamFieldType.polygonVertices:
      case ParamFieldType.twoPointMap:
        // Rendered by custom map widgets above, not via _buildField.
        return const SizedBox.shrink();
    }
  }

  Color _parseAbgrColor(String abgr) {
    try {
      if (abgr.length != 8) return Colors.grey;
      final a = int.parse(abgr.substring(0, 2), radix: 16);
      final b = int.parse(abgr.substring(2, 4), radix: 16);
      final g = int.parse(abgr.substring(4, 6), radix: 16);
      final r = int.parse(abgr.substring(6, 8), radix: 16);
      return Color.fromARGB(a, r, g, b);
    } catch (_) {
      return Colors.grey;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// KML CODE CARD (Read-Only Code Viewer)
// ═══════════════════════════════════════════════════════════════════════

class _KmlCodeCard extends ConsumerWidget {
  final ThemeData theme;
  const _KmlCodeCard({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playgroundControllerProvider);
    final kml = state.generatedKml ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE17055).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.code, color: Color(0xFFE17055), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Generated KML',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      Text(
                        state.isKmlValid ? 'Valid XML ✓' : 'Invalid XML ✗ ${state.validationError ?? ""}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: state.isKmlValid ? Colors.greenAccent[400] : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: 'Copy KML',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: kml));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('KML copied to clipboard')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? Colors.black54
                    : const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: SelectableText(
                    kml,
                    style: const TextStyle(
                      color: Color(0xFFA6E3A1),
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PUSH TO LG CARD
// ═══════════════════════════════════════════════════════════════════════

class _PushToLGCard extends ConsumerWidget {
  final ThemeData theme;
  const _PushToLGCard({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playgroundControllerProvider);
    final ssh = ref.watch(sshServiceProvider);
    final controller = ref.read(playgroundControllerProvider.notifier);

    final isReady = state.activeTemplate != null && state.isKmlValid && state.generatedKml != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0984E3).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.rocket_launch, color: Color(0xFF0984E3), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Push to Liquid Galaxy',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      Text(
                        !ssh.isConnected
                            ? 'Connect via Settings first'
                            : !isReady
                                ? 'Select a template and configure it'
                                : 'Send KML and fly to the location',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: !ssh.isConnected
                              ? Colors.redAccent
                              : !isReady
                                  ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                                  : const Color(0xFF0984E3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Checklist
            _CheckItem(label: 'Template selected', checked: state.activeTemplate != null, theme: theme),
            _CheckItem(label: 'KML is valid', checked: state.isKmlValid && state.generatedKml != null, theme: theme),
            _CheckItem(label: 'SSH connected', checked: ssh.isConnected, theme: theme),
            const SizedBox(height: 16),
            // Push button
            SizedBox(
              width: double.infinity, height: 52,
              child: FilledButton.icon(
                onPressed: (isReady && ssh.isConnected && !state.isPushing)
                    ? () async {
                        final success = await controller.pushToLG();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? 'KML pushed & flying to location!'
                                  : 'Failed to push KML'),
                              backgroundColor: success ? Colors.greenAccent[700] : Colors.redAccent,
                            ),
                          );
                        }
                      }
                    : null,
                icon: state.isPushing
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
                label: Text(state.isPushing ? 'Pushing...' : 'Push KML & Fly To'),
                style: FilledButton.styleFrom(
                  backgroundColor: isReady && ssh.isConnected ? const Color(0xFF0984E3) : null,
                ),
              ),
            ),
            // Clear button
            if (ssh.isConnected) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity, height: 44,
                child: OutlinedButton.icon(
                  onPressed: !state.isPushing
                      ? () async {
                          final success = await controller.clearFromLG();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(success ? 'KML cleared from LG' : 'Failed to clear')),
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.layers_clear),
                  label: const Text('Clear KML from LG'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ],
            // Optional Tour Playback Controls
            if (state.activeTemplate?.type == KmlTemplateType.tour) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.movie_creation, color: Colors.amber, size: 20),
                  const SizedBox(width: 10),
                  Text('Tour Playback', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: (!ssh.isConnected || !isReady || !state.isPushed) ? null : (state.isTourPlaying ? controller.stopTour : controller.playTour),
                      icon: Icon(state.isTourPlaying ? Icons.stop : Icons.play_arrow),
                      label: Text(state.isTourPlaying ? 'Stop Tour' : 'Play Tour'),
                      style: FilledButton.styleFrom(
                        backgroundColor: state.isTourPlaying ? theme.colorScheme.error : const Color(0xFF00B894),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (!ssh.isConnected || !isReady || !state.isPushed) ? null : controller.restartTour,
                      icon: const Icon(Icons.replay),
                      label: const Text('Restart'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (state.activeTemplate != null) ...[
              // Optional Orbit Playback Controls for Shapes
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.threesixty, color: Colors.blueAccent, size: 20),
                  const SizedBox(width: 10),
                  Text('Orbit Playback', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (!ssh.isConnected || !isReady || !state.isPushed) ? null : (state.isOrbiting ? controller.stopOrbit : controller.startOrbit),
                  icon: Icon(state.isOrbiting ? Icons.stop : Icons.play_arrow),
                  label: Text(state.isOrbiting ? 'Stop Orbit' : 'Start Orbit'),
                  style: FilledButton.styleFrom(
                    backgroundColor: state.isOrbiting ? theme.colorScheme.error : const Color(0xFF00B894),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════

class _CheckItem extends StatelessWidget {
  final String label;
  final bool checked;
  final ThemeData theme;
  const _CheckItem({required this.label, required this.checked, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: checked
                ? Colors.greenAccent[400]
                : theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: checked
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              decoration: checked ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}
