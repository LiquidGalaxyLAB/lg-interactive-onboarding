import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// A two-tap map that lets the user place a **Start** pin and an **End** pin.
///
/// Used by LineString and Tour templates to replace raw lat/lng sliders.
/// The user taps once → sets Start; taps again → sets End; repeats to cycle.
class TwoPointMapWidget extends StatefulWidget {
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  final void Function(double lat, double lng, {required bool isStart}) onChanged;

  const TwoPointMapWidget({
    super.key,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    required this.onChanged,
  });

  @override
  State<TwoPointMapWidget> createState() => _TwoPointMapWidgetState();
}

enum _NextTap { start, end }

class _TwoPointMapWidgetState extends State<TwoPointMapWidget> {
  late final MapController _mapController;
  _NextTap _nextTap = _NextTap.start;

  static const _startColor = Color(0xFF00B894); // Teal
  static const _endColor = Color(0xFFE17055);   // Coral

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

    final startPoint = LatLng(widget.startLat, widget.startLng);
    final endPoint = LatLng(widget.endLat, widget.endLng);

    // Centre map between both points
    final midLat = (widget.startLat + widget.endLat) / 2;
    final midLng = (widget.startLng + widget.endLng) / 2;

    final markers = <Marker>[
      Marker(
        point: startPoint,
        width: 72,
        height: 56,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: _startColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('START', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const Icon(Icons.location_on, color: _startColor, size: 28),
          ],
        ),
      ),
      Marker(
        point: endPoint,
        width: 64,
        height: 56,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: _endColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('END', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const Icon(Icons.location_on, color: _endColor, size: 28),
          ],
        ),
      ),
    ];

    final polylines = <Polyline>[
      Polyline(
        points: [startPoint, endPoint],
        color: Colors.blueGrey.shade300,
        strokeWidth: 2.0,
        pattern: StrokePattern.dashed(segments: const [8, 4]),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Tab toggle ──────────────────────────────────────────────
        Row(
          children: [
            Text('Set Location', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            _TabToggle(
              selected: _nextTap,
              onChanged: (v) => setState(() => _nextTap = v),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ── Map ─────────────────────────────────────────────────────
        Container(
          height: 220,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
          ),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(midLat, midLng),
                  initialZoom: 4,
                  onTap: (tapPosition, latLng) {
                    widget.onChanged(
                      latLng.latitude,
                      latLng.longitude,
                      isStart: _nextTap == _NextTap.start,
                    );
                    // Cycle to next
                    setState(() {
                      _nextTap = _nextTap == _NextTap.start
                          ? _NextTap.end
                          : _NextTap.start;
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.lg_interactive_onboarding',
                  ),
                  PolylineLayer(polylines: polylines),
                  MarkerLayer(markers: markers),
                ],
              ),
              Positioned(
                bottom: 8, left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _nextTap == _NextTap.start
                          ? 'Tap to move the  START  point'
                          : 'Tap to move the  END  point',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── Coordinate chips ────────────────────────────────────────
        Row(
          children: [
            _CoordChip(
              label: 'START',
              lat: widget.startLat,
              lng: widget.startLng,
              color: _startColor,
              theme: theme,
            ),
            const SizedBox(width: 8),
            _CoordChip(
              label: 'END',
              lat: widget.endLat,
              lng: widget.endLng,
              color: _endColor,
              theme: theme,
            ),
          ],
        ),
      ],
    );
  }
}

class _TabToggle extends StatelessWidget {
  final _NextTap selected;
  final void Function(_NextTap) onChanged;

  const _TabToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          _Tab(
            label: 'Start',
            color: const Color(0xFF00B894),
            isSelected: selected == _NextTap.start,
            onTap: () => onChanged(_NextTap.start),
          ),
          const SizedBox(width: 4),
          _Tab(
            label: 'End',
            color: const Color(0xFFE17055),
            isSelected: selected == _NextTap.end,
            onTap: () => onChanged(_NextTap.end),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

class _CoordChip extends StatelessWidget {
  final String label;
  final double lat;
  final double lng;
  final Color color;
  final ThemeData theme;

  const _CoordChip({
    required this.label,
    required this.lat,
    required this.lng,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 1)),
            const SizedBox(height: 2),
            Text(
              '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
              style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
