import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/data/scene_models.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/providers/model_builder_providers.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/providers/scene_providers.dart';

/// An OpenStreetMap widget that lets the user tap to place a model marker.
///
/// Uses flutter_map with OSM tiles — no API key required.
///
/// When a scene is active, all placed models are shown as markers:
///   - Purple: current import placement
///   - Blue: scene models (not selected)
///   - Orange: scene models (selected in outliner)
class MapPlacementWidget extends ConsumerStatefulWidget {
  const MapPlacementWidget({super.key});

  @override
  ConsumerState<MapPlacementWidget> createState() => _MapPlacementWidgetState();
}

class _MapPlacementWidgetState extends ConsumerState<MapPlacementWidget> {
  final MapController _mapController = MapController();

  static const _initialPosition = LatLng(40.7128, -74.0060); // New York default

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(modelBuilderProvider);
    final sceneState = ref.watch(sceneProvider);
    final theme = Theme.of(context);
    final hasLocation = project.hasLocation;

    final markers = <Marker>[];

    // Scene model markers (blue/orange)
    if (sceneState.hasScene) {
      final scene = sceneState.activeScene!;
      for (final node in scene.nodes.values) {
        if (node is ModelNode) {
          final isSelected = sceneState.selectedNodeIds.contains(node.id);
          markers.add(
            Marker(
              point: LatLng(node.latitude, node.longitude),
              width: 32,
              height: 32,
              child: Tooltip(
                message: node.name,
                child: GestureDetector(
                  onTap: () =>
                      ref.read(sceneProvider.notifier).selectNode(node.id),
                  child: Icon(
                    Icons.location_on,
                    color: isSelected
                        ? const Color(0xFFFDAA5E)
                        : const Color(0xFF0984E3),
                    size: 32,
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    // Current import placement marker (purple, on top)
    if (hasLocation) {
      markers.add(
        Marker(
          point: LatLng(project.latitude!, project.longitude!),
          width: 40,
          height: 40,
          child: const Icon(
            Icons.location_on,
            color: Color(0xFF6C5CE7),
            size: 40,
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.place,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Place on Map',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        hasLocation
                            ? '${project.latitude!.toStringAsFixed(5)}, ${project.longitude!.toStringAsFixed(5)}'
                            : 'Tap on the map to place your model',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasLocation)
                  IconButton(
                    icon: const Icon(Icons.my_location, size: 20),
                    tooltip: 'Center on placement',
                    onPressed: () {
                      _mapController.move(
                        LatLng(project.latitude!, project.longitude!),
                        15,
                      );
                    },
                  ),
              ],
            ),
          ),

          // ─── Map ───────────────────────────────────────────────
          SizedBox(
            height: 280,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: hasLocation
                    ? LatLng(project.latitude!, project.longitude!)
                    : _initialPosition,
                initialZoom: hasLocation ? 15 : 4,
                onTap: (tapPosition, latLng) {
                  ref.read(modelBuilderProvider.notifier).placeModel(
                        latLng.latitude,
                        latLng.longitude,
                      );
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.lg_interactive_onboarding',
                ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),

          // ─── Coordinates Display ───────────────────────────────
          if (hasLocation)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _CoordChip(
                    label: 'LAT',
                    value: project.latitude!.toStringAsFixed(6),
                    icon: Icons.north,
                    theme: theme,
                  ),
                  const SizedBox(width: 8),
                  _CoordChip(
                    label: 'LON',
                    value: project.longitude!.toStringAsFixed(6),
                    icon: Icons.east,
                    theme: theme,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CoordChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final ThemeData theme;

  const _CoordChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              '$label: ',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
