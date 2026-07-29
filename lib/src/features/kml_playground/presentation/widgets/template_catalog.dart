import 'package:flutter/material.dart';

class TemplateCatalog extends StatelessWidget {
  const TemplateCatalog({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'KML Templates',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search templates...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _buildCategoryHeader(context, 'Basic Geometries'),
                _buildTemplateTile(context, 'Placemark', Icons.location_on, 'A simple point on the map.'),
                _buildTemplateTile(context, 'Polygon', Icons.polyline, 'A customized filled shape.'),
                _buildTemplateTile(context, 'LineString', Icons.timeline, 'A path connecting multiple points.'),
                _buildCategoryHeader(context, 'Overlays'),
                _buildTemplateTile(context, 'Screen Overlay', Icons.image, 'An image fixed to the screen.'),
                _buildTemplateTile(context, 'Ground Overlay', Icons.layers, 'An image draped on the terrain.'),
                _buildCategoryHeader(context, 'Advanced'),
                _buildTemplateTile(context, '3D Model', Icons.view_in_ar, 'Import a .dae 3D model.'),
                _buildTemplateTile(context, 'Tour', Icons.flight_takeoff, 'A simple flying tour.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildTemplateTile(BuildContext context, String title, IconData icon, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: () {
        // TODO: Update state with selected template
      },
    );
  }
}
