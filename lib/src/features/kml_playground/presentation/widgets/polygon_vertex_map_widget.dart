import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Interactive map that lets the user build a polygon by tapping vertices,
/// just like placing points in Google Earth Pro.
///
/// Shows:
/// - Numbered markers for each vertex
/// - A filled polygon preview (with semi-transparent fill + outline)
/// - A vertex list with remove buttons below the map
class PolygonVertexMapWidget extends StatefulWidget {
  final List<Map<String, double>> vertices;
  final void Function(double lat, double lng) onAddVertex;
  final void Function(int index) onRemoveVertex;
  final void Function() onClearAll;

  const PolygonVertexMapWidget({
    super.key,
    required this.vertices,
    required this.onAddVertex,
    required this.onRemoveVertex,
    required this.onClearAll,
  });

  @override
  State<PolygonVertexMapWidget> createState() => _PolygonVertexMapWidgetState();
}

class _PolygonVertexMapWidgetState extends State<PolygonVertexMapWidget> {
  late final MapController _mapController;
  static const _defaultCenter = LatLng(28.6139, 77.2090);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teal = const Color(0xFF009688);

    final latLngs = widget.vertices
        .map((v) => LatLng(v['lat'] ?? 0, v['lng'] ?? 0))
        .toList();

    // The polygon preview list — closes automatically for the fill layer
    final polygons = <Polygon>[];
    if (latLngs.length >= 3) {
      polygons.add(Polygon(
        points: [...latLngs, latLngs.first],
        color: teal.withValues(alpha: 0.25),
        borderColor: teal,
        borderStrokeWidth: 2.5,
      ));
    }

    // Markers — numbered
    final markers = <Marker>[];
    for (int i = 0; i < latLngs.length; i++) {
      markers.add(Marker(
        point: latLngs[i],
        width: 28,
        height: 28,
        child: Container(
          decoration: BoxDecoration(
            color: teal,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${i + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ));
    }

    final center = latLngs.isNotEmpty
        ? LatLng(
            latLngs.map((p) => p.latitude).reduce((a, b) => a + b) / latLngs.length,
            latLngs.map((p) => p.longitude).reduce((a, b) => a + b) / latLngs.length,
          )
        : _defaultCenter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Header row ──────────────────────────────────────────────
        Row(
          children: [
            Text('Draw Polygon',
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            if (widget.vertices.isNotEmpty)
              TextButton.icon(
                onPressed: widget.onClearAll,
                icon: const Icon(Icons.delete_sweep, size: 14),
                label: const Text('Clear all'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  textStyle: const TextStyle(fontSize: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: widget.vertices.length >= 3
                    ? Colors.greenAccent.withValues(alpha: 0.15)
                    : teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.vertices.length >= 3
                    ? '${widget.vertices.length} pts ✓'
                    : '${widget.vertices.length} / 3+ pts',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: widget.vertices.length >= 3
                      ? Colors.greenAccent[400]
                      : teal,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ─── Map ─────────────────────────────────────────────────────
        Container(
          height: 260,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: teal.withValues(alpha: 0.3)),
          ),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 14,
                  onTap: (tapPosition, latLng) {
                    widget.onAddVertex(latLng.latitude, latLng.longitude);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.lg_interactive_onboarding',
                  ),
                  if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
                  MarkerLayer(markers: markers),
                ],
              ),
              // Instruction badge
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.vertices.isEmpty
                          ? 'Tap on the map to add vertices'
                          : widget.vertices.length < 3
                              ? 'Add ${3 - widget.vertices.length} more point(s) to form a polygon'
                              : 'Tap to add more · Tap a number badge to remove',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ─── Vertex List ─────────────────────────────────────────────
        if (widget.vertices.isNotEmpty) ...[
          Text('Vertices', style: theme.textTheme.labelSmall?.copyWith(
              color: teal, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          ...List.generate(widget.vertices.length, (i) {
            final v = widget.vertices[i];
            final lat = v['lat'] ?? 0;
            final lng = v['lng'] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: teal.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: teal.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(color: teal, shape: BoxShape.circle),
                      child: Center(
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${lat.toStringAsFixed(5)},  ${lng.toStringAsFixed(5)}',
                        style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => widget.onRemoveVertex(i),
                      child: Icon(Icons.remove_circle_outline,
                          size: 20, color: theme.colorScheme.error),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
