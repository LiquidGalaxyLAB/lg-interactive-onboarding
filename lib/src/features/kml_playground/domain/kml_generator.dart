import 'package:lg_interactive_onboarding/src/features/kml_playground/domain/kml_template.dart';

/// Generates valid KML XML strings from template parameters.
///
/// Each KML type has its own dedicated generation method. The public API
/// is [generate], which dispatches to the correct builder based on
/// [KmlTemplateType]. All methods return a complete, standalone KML
/// document string ready to be uploaded to Liquid Galaxy.
class KmlGenerator {
  const KmlGenerator();

  // ─── Public API ──────────────────────────────────────────────────

  /// Generates a complete KML document string for the given template
  /// type and parameter map.
  ///
  /// Returns `null` if the template type is not yet supported.
  String? generate(KmlTemplateType type, Map<String, dynamic> params) {
    switch (type) {
      case KmlTemplateType.placemark:
        return _generatePlacemark(params);
      case KmlTemplateType.polygon:
        return _generatePolygon(params);
      case KmlTemplateType.lineString:
        return _generateLineString(params);
      case KmlTemplateType.groundOverlay:
        return _generateGroundOverlay(params);
      case KmlTemplateType.screenOverlay:
        return _generateScreenOverlay(params);
      case KmlTemplateType.tour:
        return _generateTour(params);
    }
  }

  /// Generates a `<LookAt>` element string to fly the camera to a
  /// location derived from the given parameters.
  String generateLookAt(Map<String, dynamic> params) {
    final lat = _d(params, 'latitude');
    final lng = _d(params, 'longitude');
    final alt = _d(params, 'altitude');
    final heading = _d(params, 'heading');
    final tilt = _d(params, 'tilt', fallback: 45.0);
    final range = _d(params, 'range', fallback: 1000.0);

    return '<LookAt>'
        '<longitude>$lng</longitude>'
        '<latitude>$lat</latitude>'
        '<altitude>$alt</altitude>'
        '<heading>$heading</heading>'
        '<tilt>$tilt</tilt>'
        '<range>$range</range>'
        '<gx:altitudeMode>relativeToGround</gx:altitudeMode>'
        '</LookAt>';
  }

  // ─── Private Builders ────────────────────────────────────────────

  String _generatePlacemark(Map<String, dynamic> params) {
    final name = _s(params, 'name', fallback: 'Placemark');
    final lat = _d(params, 'latitude');
    final lng = _d(params, 'longitude');
    final scale = _d(params, 'scale', fallback: 1.0);
    final rawColor = _s(params, 'color', fallback: 'Red');
    final color = _mapColorToAbgr(rawColor);

    return _wrapDocument(
      name: name,
      body: '''
    <Style id="playgroundStyle">
      <IconStyle>
        <color>$color</color>
        <scale>$scale</scale>
        <Icon>
          <href>http://maps.google.com/mapfiles/kml/pushpin/ylw-pushpin.png</href>
        </Icon>
      </IconStyle>
    </Style>
    <Placemark>
      <name>$name</name>
      <styleUrl>#playgroundStyle</styleUrl>
      <Point>
        <coordinates>$lng,$lat,0</coordinates>
      </Point>
    </Placemark>''',
    );
  }

  String _generatePolygon(Map<String, dynamic> params) {
    final name = _s(params, 'name', fallback: 'Polygon');
    final altitude = _d(params, 'altitude');
    final extrude = params['extrude'] == true;
    
    // Extrusion requires absolute or relativeToGround altitude mode
    String altitudeMode = _s(params, 'altitudeMode', fallback: 'clampToGround');
    if (extrude && altitudeMode == 'clampToGround') {
      altitudeMode = 'relativeToGround';
    }

    final lineWidth = _d(params, 'lineWidth', fallback: 2.0);

    // Resolve named colours → ABGR hex
    final rawFill = _s(params, 'fillColor', fallback: 'Green');
    final rawLine = _s(params, 'lineColor', fallback: 'White');
    final fillColor = _mapColorToAbgrFill(rawFill); // semi-transparent fill
    final lineColor = _mapColorToAbgr(rawLine);     // opaque outline

    // Build coordinate string from vertex list
    final vertices = params['vertices'];
    String coordString;
    if (vertices is List && vertices.length >= 3) {
      final buffer = StringBuffer();
      for (final v in vertices) {
        final lat = (v is Map) ? (v['lat'] as num?)?.toDouble() ?? 0.0 : 0.0;
        final lng = (v is Map) ? (v['lng'] as num?)?.toDouble() ?? 0.0 : 0.0;
        buffer.writeln('              $lng,$lat,$altitude');
      }
      // Close the loop — KML requires first == last
      final first = vertices.first;
      final closeLat = (first is Map) ? (first['lat'] as num?)?.toDouble() ?? 0.0 : 0.0;
      final closeLng = (first is Map) ? (first['lng'] as num?)?.toDouble() ?? 0.0 : 0.0;
      buffer.write('              $closeLng,$closeLat,$altitude');
      coordString = buffer.toString();
    } else {
      // Default placeholder square near New Delhi if no vertices set
      coordString = '''
              77.2080,28.6149,$altitude
              77.2100,28.6149,$altitude
              77.2100,28.6129,$altitude
              77.2080,28.6129,$altitude
              77.2080,28.6149,$altitude''';
    }

    return _wrapDocument(
      name: name,
      body: '''
    <Style id="polyStyle">
      <LineStyle>
        <color>$lineColor</color>
        <width>$lineWidth</width>
      </LineStyle>
      <PolyStyle>
        <color>$fillColor</color>
      </PolyStyle>
    </Style>
    <Placemark>
      <name>$name</name>
      <styleUrl>#polyStyle</styleUrl>
      <Polygon>
        ${extrude ? '<extrude>1</extrude>' : ''}
        <tessellate>1</tessellate>
        <altitudeMode>$altitudeMode</altitudeMode>
        <outerBoundaryIs>
          <LinearRing>
            <coordinates>
$coordString
            </coordinates>
          </LinearRing>
        </outerBoundaryIs>
      </Polygon>
    </Placemark>''',
    );
  }

  String _generateLineString(Map<String, dynamic> params) {
    final name = _s(params, 'name', fallback: 'Line');
    final startLat = _d(params, 'startLatitude');
    final startLng = _d(params, 'startLongitude');
    final endLat = _d(params, 'endLatitude', fallback: 1.0);
    final endLng = _d(params, 'endLongitude', fallback: 1.0);
    final rawColor = _s(params, 'lineColor', fallback: 'Red');
    final lineColor = _mapColorToAbgr(rawColor);
    final lineWidth = _d(params, 'lineWidth', fallback: 3.0);
    final altitudeMode = _s(params, 'altitudeMode', fallback: 'clampToGround');

    return _wrapDocument(
      name: name,
      body: '''
    <Style id="lineStyle">
      <LineStyle>
        <color>$lineColor</color>
        <width>$lineWidth</width>
      </LineStyle>
    </Style>
    <Placemark>
      <name>$name</name>
      <styleUrl>#lineStyle</styleUrl>
      <LineString>
        <tessellate>1</tessellate>
        <altitudeMode>$altitudeMode</altitudeMode>
        <coordinates>
          $startLng,$startLat,0
          $endLng,$endLat,0
        </coordinates>
      </LineString>
    </Placemark>''',
    );
  }

  String _generateGroundOverlay(Map<String, dynamic> params) {
    final name = _s(params, 'name', fallback: 'Ground Overlay');
    final lat = _d(params, 'latitude');
    final lng = _d(params, 'longitude');
    final size = _d(params, 'size', fallback: 0.01);
    final imageUrl = _s(params, 'imageUrl',
        fallback: 'https://developers.google.com/kml/documentation/images/rectangle.png');
    final opacity = _d(params, 'opacity', fallback: 1.0);

    // Hex opacity: convert 0.0-1.0 to 00-ff
    final opacityHex = (opacity * 255).round().toRadixString(16).padLeft(2, '0');
    final color = '${opacityHex}ffffff';

    final north = lat + size;
    final south = lat - size;
    final east = lng + size;
    final west = lng - size;

    return _wrapDocument(
      name: name,
      body: '''
    <GroundOverlay>
      <name>$name</name>
      <color>$color</color>
      <Icon>
        <href>$imageUrl</href>
      </Icon>
      <LatLonBox>
        <north>$north</north>
        <south>$south</south>
        <east>$east</east>
        <west>$west</west>
      </LatLonBox>
    </GroundOverlay>''',
    );
  }

  String _generateScreenOverlay(Map<String, dynamic> params) {
    final name = _s(params, 'name', fallback: 'Screen Overlay');
    final imageUrl = _s(params, 'imageUrl',
        fallback: 'https://developers.google.com/kml/documentation/images/rectangle.png');
    final overlayX = _d(params, 'overlayX');
    final overlayY = _d(params, 'overlayY');
    final sizeX = _d(params, 'sizeX', fallback: 0.2);
    final sizeY = _d(params, 'sizeY', fallback: 0.2);

    return _wrapDocument(
      name: name,
      body: '''
    <ScreenOverlay>
      <name>$name</name>
      <Icon>
        <href>$imageUrl</href>
      </Icon>
      <overlayXY x="$overlayX" y="$overlayY" xunits="fraction" yunits="fraction"/>
      <screenXY x="$overlayX" y="$overlayY" xunits="fraction" yunits="fraction"/>
      <size x="$sizeX" y="$sizeY" xunits="fraction" yunits="fraction"/>
    </ScreenOverlay>''',
    );
  }

  String _generateTour(Map<String, dynamic> params) {
    final name = _s(params, 'name', fallback: 'Simple Tour');
    final startLat = _d(params, 'startLatitude');
    final startLng = _d(params, 'startLongitude');
    final endLat = _d(params, 'endLatitude', fallback: 10.0);
    final endLng = _d(params, 'endLongitude', fallback: 10.0);
    final duration = _d(params, 'duration', fallback: 5.0);
    final range = _d(params, 'range', fallback: 5000.0);
    final tilt = _d(params, 'tilt', fallback: 45.0);

    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"
     xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>$name</name>
    <open>1</open>
    <gx:Tour>
      <name>$name</name>
      <gx:Playlist>
        <gx:FlyTo>
          <gx:duration>0.1</gx:duration>
          <gx:flyToMode>bounce</gx:flyToMode>
          <LookAt>
            <longitude>$startLng</longitude>
            <latitude>$startLat</latitude>
            <altitude>0</altitude>
            <heading>0</heading>
            <tilt>$tilt</tilt>
            <range>$range</range>
          </LookAt>
        </gx:FlyTo>
        <gx:Wait>
          <gx:duration>2</gx:duration>
        </gx:Wait>
        <gx:FlyTo>
          <gx:duration>$duration</gx:duration>
          <gx:flyToMode>smooth</gx:flyToMode>
          <LookAt>
            <longitude>$endLng</longitude>
            <latitude>$endLat</latitude>
            <altitude>0</altitude>
            <heading>0</heading>
            <tilt>$tilt</tilt>
            <range>$range</range>
          </LookAt>
        </gx:FlyTo>
      </gx:Playlist>
    </gx:Tour>
  </Document>
</kml>''';
  }

  // ─── Helpers ─────────────────────────────────────────────────────

  /// Wraps the inner body with the standard KML document boilerplate.
  String _wrapDocument({required String name, required String body}) {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"
     xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>$name</name>
    <open>1</open>$body
  </Document>
</kml>''';
  }

  /// Safely reads a [double] from the params map with an optional fallback.
  double _d(Map<String, dynamic> params, String key, {double fallback = 0.0}) {
    final value = params[key];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Safely reads a [String] from the params map with an optional fallback.
  String _s(Map<String, dynamic> params, String key, {String fallback = ''}) {
    final value = params[key];
    if (value is String) return value;
    if (value != null) return value.toString();
    return fallback;
  }

  /// Maps common color names to KML ABGR hex codes.
  String _mapColorToAbgr(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'red': return 'ff0000ff';
      case 'blue': return 'ffff0000';
      case 'green': return 'ff00ff00';
      case 'yellow': return 'ff00ffff';
      case 'purple': return 'ffff0080';
      case 'orange': return 'ff0080ff';
      case 'white': return 'ffffffff';
      case 'black': return 'ff000000';
      case 'cyan': return 'ffffff00';
      default: return colorName; // Fallback to raw value if not matched
    }
  }

  /// Maps color names to semi-transparent (~50%) ABGR for polygon fills.
  String _mapColorToAbgrFill(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'red': return '7f0000ff';
      case 'blue': return '7fff0000';
      case 'green': return '7f00ff00';
      case 'yellow': return '7f00ffff';
      case 'purple': return '7fff0080';
      case 'orange': return '7f0080ff';
      case 'white': return '7fffffff';
      case 'cyan': return '7fffff00';
      default: return colorName;
    }
  }
}
