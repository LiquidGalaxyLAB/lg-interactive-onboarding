import 'package:flutter/material.dart';

/// Represents the type of KML element
enum KmlTemplateType {
  placemark,
  polygon,
  lineString,
  screenOverlay,
  groundOverlay,
  tour,
}

/// The kind of UI control to render for a parameter
enum ParamFieldType {
  text,
  number,
  color,
  dropdown,
  url,
  coordinates,
  /// Free-form polygon vertex list — renders interactive map with tap-to-add
  polygonVertices,
  /// Two-point map — renders a map that lets the user pick Start and End pins
  twoPointMap,
  /// Boolean toggle switch
  boolean,
}

/// Represents a single editable parameter for a KML Template.
///
/// [fieldType] tells the UI which widget to render (text field, slider,
/// color picker, etc.). [options] is only used for [ParamFieldType.dropdown].
class KmlParameter {
  final String id;
  final String label;
  final dynamic defaultValue;
  final ParamFieldType fieldType;

  /// Optional minimum value for numeric fields.
  final double? min;

  /// Optional maximum value for numeric fields.
  final double? max;

  /// Options for dropdown fields.
  final List<String>? options;

  const KmlParameter({
    required this.id,
    required this.label,
    required this.defaultValue,
    required this.fieldType,
    this.min,
    this.max,
    this.options,
  });
}

/// Category grouping for the template catalog UI.
enum TemplateCategory {
  basics('Basic Geometries', Icons.place),
  overlays('Overlays', Icons.layers),
  advanced('Advanced', Icons.view_in_ar);

  final String displayName;
  final IconData icon;
  const TemplateCategory(this.displayName, this.icon);
}

/// Domain model representing a KML template that can be manipulated
/// in the playground.
///
/// Each template belongs to a [category] and carries a list of
/// [KmlParameter]s that determine which UI controls are shown and
/// what values are fed into [KmlGenerator.generate].
class KmlTemplate {
  final String id;
  final String name;
  final KmlTemplateType type;
  final TemplateCategory category;
  final String description;
  final IconData icon;
  final List<KmlParameter> parameters;

  /// Educational tooltip shown when this template is selected.
  final String? tip;

  const KmlTemplate({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    required this.description,
    required this.icon,
    required this.parameters,
    this.tip,
  });

  // ─── Predefined Template Catalog ─────────────────────────────────

  static List<KmlTemplate> get predefinedTemplates => [
        // ── Basics ──────────────────────────────────────────────────

        const KmlTemplate(
          id: 'basic_placemark',
          name: 'Placemark',
          type: KmlTemplateType.placemark,
          category: TemplateCategory.basics,
          description: 'A simple pin on the map.',
          icon: Icons.location_on,
          tip: '💡 KML colors use ABGR format (not RGB). "ff0000ff" means fully opaque red. The first two hex digits are alpha (opacity).',
          parameters: [
            KmlParameter(id: 'name', label: 'Name', defaultValue: 'My Pin', fieldType: ParamFieldType.text),
            KmlParameter(id: 'latitude', label: 'Latitude', defaultValue: 28.6139, fieldType: ParamFieldType.number, min: -90, max: 90),
            KmlParameter(id: 'longitude', label: 'Longitude', defaultValue: 77.2090, fieldType: ParamFieldType.number, min: -180, max: 180),
            KmlParameter(id: 'scale', label: 'Scale', defaultValue: 1.2, fieldType: ParamFieldType.number, min: 0.1, max: 5.0),
            KmlParameter(
              id: 'color', label: 'Pin Color', defaultValue: 'Red',
              fieldType: ParamFieldType.dropdown,
              options: ['Red', 'Blue', 'Green', 'Yellow', 'Purple', 'Orange'],
            ),
          ],
        ),

        const KmlTemplate(
          id: 'basic_polygon',
          name: 'Polygon',
          type: KmlTemplateType.polygon,
          category: TemplateCategory.basics,
          description: 'A filled shape on the map.',
          icon: Icons.polyline,
          tip: '💡 Tap the map to place vertices. Try turning on "Extrude" and setting a high Altitude to create instant 3D buildings purely from KML!',
          parameters: [
            KmlParameter(id: 'name', label: 'Name', defaultValue: 'My Polygon', fieldType: ParamFieldType.text),
            KmlParameter(
              id: 'vertices',
              label: 'Vertices',
              defaultValue: <Map<String, double>>[],
              fieldType: ParamFieldType.polygonVertices,
            ),
            KmlParameter(id: 'altitude', label: 'Altitude (m)', defaultValue: 0.0, fieldType: ParamFieldType.number, min: 0, max: 100000),
            KmlParameter(id: 'extrude', label: 'Extrude to Ground', defaultValue: false, fieldType: ParamFieldType.boolean),
            KmlParameter(
              id: 'fillColor', label: 'Fill Color', defaultValue: 'Green',
              fieldType: ParamFieldType.dropdown,
              options: ['Red', 'Blue', 'Green', 'Yellow', 'Purple', 'Orange', 'White', 'Cyan'],
            ),
            KmlParameter(
              id: 'lineColor', label: 'Outline Color', defaultValue: 'White',
              fieldType: ParamFieldType.dropdown,
              options: ['Red', 'Blue', 'Green', 'Yellow', 'Purple', 'Orange', 'White', 'Black'],
            ),
            KmlParameter(id: 'lineWidth', label: 'Outline Width', defaultValue: 2.0, fieldType: ParamFieldType.number, min: 0.5, max: 10.0),
            KmlParameter(
              id: 'altitudeMode', label: 'Altitude Mode', defaultValue: 'clampToGround',
              fieldType: ParamFieldType.dropdown,
              options: ['clampToGround', 'relativeToGround', 'absolute'],
            ),
          ],
        ),

        const KmlTemplate(
          id: 'basic_linestring',
          name: 'LineString',
          type: KmlTemplateType.lineString,
          category: TemplateCategory.basics,
          description: 'A path connecting two points.',
          icon: Icons.timeline,
          tip: '💡 A LineString can have many more than 2 points. In production KML, lines often trace GPS routes with hundreds of coordinates.',
          parameters: [
            KmlParameter(id: 'name', label: 'Name', defaultValue: 'My Line', fieldType: ParamFieldType.text),
            KmlParameter(
              id: 'startEndMap',
              label: 'Start / End Points',
              defaultValue: null,
              fieldType: ParamFieldType.twoPointMap,
            ),
            KmlParameter(id: 'startLatitude', label: 'Start Latitude', defaultValue: 28.6139, fieldType: ParamFieldType.number, min: -90, max: 90),
            KmlParameter(id: 'startLongitude', label: 'Start Longitude', defaultValue: 77.2090, fieldType: ParamFieldType.number, min: -180, max: 180),
            KmlParameter(id: 'endLatitude', label: 'End Latitude', defaultValue: 19.0760, fieldType: ParamFieldType.number, min: -90, max: 90),
            KmlParameter(id: 'endLongitude', label: 'End Longitude', defaultValue: 72.8777, fieldType: ParamFieldType.number, min: -180, max: 180),
            KmlParameter(
              id: 'lineColor', label: 'Line Color', defaultValue: 'Red',
              fieldType: ParamFieldType.dropdown,
              options: ['Red', 'Blue', 'Green', 'Yellow', 'Purple', 'Orange', 'White', 'Cyan'],
            ),
            KmlParameter(id: 'lineWidth', label: 'Line Width', defaultValue: 3.0, fieldType: ParamFieldType.number, min: 0.5, max: 10.0),
            KmlParameter(
              id: 'altitudeMode', label: 'Altitude Mode', defaultValue: 'clampToGround',
              fieldType: ParamFieldType.dropdown,
              options: ['clampToGround', 'relativeToGround', 'absolute'],
            ),
          ],
        ),

        // ── Overlays ────────────────────────────────────────────────

        const KmlTemplate(
          id: 'ground_overlay',
          name: 'Ground Overlay',
          type: KmlTemplateType.groundOverlay,
          category: TemplateCategory.overlays,
          description: 'An image draped on the terrain.',
          icon: Icons.landscape,
          tip: '💡 GroundOverlay drapes an image onto the Earth\'s surface like a sticker. Use it for custom maps, satellite tiles, or historical imagery.',
          parameters: [
            KmlParameter(id: 'name', label: 'Name', defaultValue: 'Ground Image', fieldType: ParamFieldType.text),
            KmlParameter(id: 'latitude', label: 'Center Latitude', defaultValue: 28.6139, fieldType: ParamFieldType.number, min: -90, max: 90),
            KmlParameter(id: 'longitude', label: 'Center Longitude', defaultValue: 77.2090, fieldType: ParamFieldType.number, min: -180, max: 180),
            KmlParameter(id: 'size', label: 'Size (degrees)', defaultValue: 0.01, fieldType: ParamFieldType.number, min: 0.001, max: 10.0),
            KmlParameter(id: 'imageUrl', label: 'Image URL', defaultValue: 'https://developers.google.com/kml/documentation/images/rectangle.png', fieldType: ParamFieldType.url),
            KmlParameter(id: 'opacity', label: 'Opacity', defaultValue: 0.8, fieldType: ParamFieldType.number, min: 0.0, max: 1.0),
          ],
        ),

        const KmlTemplate(
          id: 'screen_overlay',
          name: 'Screen Overlay',
          type: KmlTemplateType.screenOverlay,
          category: TemplateCategory.overlays,
          description: 'An image fixed on the screen.',
          icon: Icons.image,
          tip: '💡 ScreenOverlay is pinned to the screen, not the Earth. It\'s perfect for branding logos or informational banners on the LG rig.',
          parameters: [
            KmlParameter(id: 'name', label: 'Name', defaultValue: 'Screen Logo', fieldType: ParamFieldType.text),
            KmlParameter(id: 'imageUrl', label: 'Image URL', defaultValue: 'https://developers.google.com/kml/documentation/images/rectangle.png', fieldType: ParamFieldType.url),
            KmlParameter(id: 'overlayX', label: 'Position X (0–1)', defaultValue: 0.0, fieldType: ParamFieldType.number, min: 0.0, max: 1.0),
            KmlParameter(id: 'overlayY', label: 'Position Y (0–1)', defaultValue: 1.0, fieldType: ParamFieldType.number, min: 0.0, max: 1.0),
            KmlParameter(id: 'sizeX', label: 'Width (fraction)', defaultValue: 0.15, fieldType: ParamFieldType.number, min: 0.01, max: 1.0),
            KmlParameter(id: 'sizeY', label: 'Height (fraction)', defaultValue: 0.15, fieldType: ParamFieldType.number, min: 0.01, max: 1.0),
          ],
        ),

        // ── Advanced ────────────────────────────────────────────────

        const KmlTemplate(
          id: 'simple_tour',
          name: 'Tour',
          type: KmlTemplateType.tour,
          category: TemplateCategory.advanced,
          description: 'A simple flying tour between two points.',
          icon: Icons.flight_takeoff,
          tip: '💡 gx:Tour uses a Playlist of FlyTo and Wait steps. Tap the map to set Start and End points. Use Stop/Restart buttons to control playback!',
          parameters: [
            KmlParameter(id: 'name', label: 'Tour Name', defaultValue: 'My Tour', fieldType: ParamFieldType.text),
            KmlParameter(
              id: 'startEndMap',
              label: 'Start / End Points',
              defaultValue: null,
              fieldType: ParamFieldType.twoPointMap,
            ),
            KmlParameter(id: 'startLatitude', label: 'Start Latitude', defaultValue: 28.6139, fieldType: ParamFieldType.number, min: -90, max: 90),
            KmlParameter(id: 'startLongitude', label: 'Start Longitude', defaultValue: 77.2090, fieldType: ParamFieldType.number, min: -180, max: 180),
            KmlParameter(id: 'endLatitude', label: 'End Latitude', defaultValue: 48.8566, fieldType: ParamFieldType.number, min: -90, max: 90),
            KmlParameter(id: 'endLongitude', label: 'End Longitude', defaultValue: 2.3522, fieldType: ParamFieldType.number, min: -180, max: 180),
            KmlParameter(id: 'duration', label: 'Fly Duration (s)', defaultValue: 5.0, fieldType: ParamFieldType.number, min: 1, max: 30),
            KmlParameter(id: 'range', label: 'Camera Range (m)', defaultValue: 5000.0, fieldType: ParamFieldType.number, min: 100, max: 50000),
            KmlParameter(id: 'tilt', label: 'Camera Tilt (°)', defaultValue: 45.0, fieldType: ParamFieldType.number, min: 0, max: 90),
          ],
        ),
      ];
}
