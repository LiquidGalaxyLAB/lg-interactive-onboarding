class OrbitGenerator {
  /// Generates a perfectly smooth KML Tour for orbiting a specific location.
  static String generateOrbitTour({
    required String tourName,
    required double lat,
    required double lng,
    required double alt,
    required double range,
    required double tilt,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('    <gx:Tour>');
    buffer.writeln('      <name>$tourName</name>');
    buffer.writeln('      <gx:Playlist>');

    // Generate 20 orbits (about 15 minutes of continuous smooth orbiting)
    for (int orbit = 0; orbit < 20; orbit++) {
      for (int i = 0; i <= 360; i += 10) {
        if (i == 0 && orbit > 0) {
          // At the start of every orbit (except the first), we need to reset the heading from 360 back to 0.
          // If we use smooth interpolation, Google Earth will violently spin backwards 360 degrees.
          // By using a duration of 0.0, we instantly teleport the heading to 0.
          // Since 360 and 0 are visually identical, this teleportation is completely invisible to the user!
          buffer.writeln('        <gx:FlyTo>');
          buffer.writeln('          <gx:duration>0.0</gx:duration>');
          buffer.writeln('          <gx:flyToMode>bounce</gx:flyToMode>');
          buffer.writeln('          <LookAt>');
          buffer.writeln('            <longitude>$lng</longitude>');
          buffer.writeln('            <latitude>$lat</latitude>');
          buffer.writeln('            <altitude>$alt</altitude>');
          buffer.writeln('            <heading>0</heading>');
          buffer.writeln('            <tilt>$tilt</tilt>');
          buffer.writeln('            <range>$range</range>');
          buffer.writeln('            <gx:altitudeMode>relativeToGround</gx:altitudeMode>');
          buffer.writeln('          </LookAt>');
          buffer.writeln('        </gx:FlyTo>');
        } else {
          buffer.writeln('        <gx:FlyTo>');
          buffer.writeln('          <gx:duration>1.2</gx:duration>');
          buffer.writeln('          <gx:flyToMode>smooth</gx:flyToMode>');
          buffer.writeln('          <LookAt>');
          buffer.writeln('            <longitude>$lng</longitude>');
          buffer.writeln('            <latitude>$lat</latitude>');
          buffer.writeln('            <altitude>$alt</altitude>');
          buffer.writeln('            <heading>$i</heading>');
          buffer.writeln('            <tilt>$tilt</tilt>');
          buffer.writeln('            <range>$range</range>');
          buffer.writeln('            <gx:altitudeMode>relativeToGround</gx:altitudeMode>');
          buffer.writeln('          </LookAt>');
          buffer.writeln('        </gx:FlyTo>');
        }
      }
    }

    buffer.writeln('      </gx:Playlist>');
    buffer.writeln('    </gx:Tour>');
    return buffer.toString();
  }
}
