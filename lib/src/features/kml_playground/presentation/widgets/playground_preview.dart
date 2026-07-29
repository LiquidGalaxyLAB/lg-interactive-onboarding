import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class PlaygroundPreview extends StatefulWidget {
  const PlaygroundPreview({super.key});

  @override
  State<PlaygroundPreview> createState() => _PlaygroundPreviewState();
}

class _PlaygroundPreviewState extends State<PlaygroundPreview> {
  bool _showCode = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toggle Bar
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Map Preview'),
                    icon: Icon(Icons.map),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('KML Code'),
                    icon: Icon(Icons.code),
                  ),
                ],
                selected: {_showCode},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _showCode = newSelection.first;
                  });
                },
              ),
            ],
          ),
        ),
        // Content Area
        Expanded(
          child: _showCode ? _buildCodeView(context) : _buildMapView(),
        ),
      ],
    );
  }

  Widget _buildMapView() {
    return FlutterMap(
      options: MapOptions(
        initialCenter: const LatLng(0, 0),
        initialZoom: 2.0,
        onTap: (tapPosition, point) {
          // TODO: Update coordinate parameters on map tap
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
              point: const LatLng(0, 0),
              width: 40,
              height: 40,
              child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCodeView(BuildContext context) {
    const placeholderCode = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>Sample Placemark</name>
    <Placemark>
      <name>My Pin</name>
      <Point>
        <coordinates>0.0,0.0,0</coordinates>
      </Point>
    </Placemark>
  </Document>
</kml>''';

    return Container(
      width: double.infinity,
      color: Colors.black87,
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: SelectableText(
          placeholderCode,
          style: const TextStyle(
            color: Colors.greenAccent,
            fontFamily: 'monospace',
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
