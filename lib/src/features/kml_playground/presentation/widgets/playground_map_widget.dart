import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// A reusable map widget for the KML Playground to pick coordinates.
class PlaygroundMapWidget extends StatefulWidget {
  final double latitude;
  final double longitude;
  final void Function(double lat, double lng) onLocationChanged;

  const PlaygroundMapWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.onLocationChanged,
  });

  @override
  State<PlaygroundMapWidget> createState() => _PlaygroundMapWidgetState();
}

class _PlaygroundMapWidgetState extends State<PlaygroundMapWidget> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(PlaygroundMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the external values changed significantly, we might want to pan the map,
    // but doing so on every slider tick is jerky, so we only update markers.
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final center = LatLng(widget.latitude, widget.longitude);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Location', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
            Text('${widget.latitude.toStringAsFixed(4)}, ${widget.longitude.toStringAsFixed(4)}',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
          ),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14,
              onTap: (tapPosition, latLng) {
                widget.onLocationChanged(latLng.latitude, latLng.longitude);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.lg_interactive_onboarding',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: center,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_on,
                      color: Color(0xFFE17055),
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text('Tap map to move element',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 10)),
        ),
      ],
    );
  }
}
