class EducationalBalloonKmlModel {
  static String generateBalloonKml({
    required String id,
    required String title,
    required String description,
    String? iconUrl,
    double latitude = 0.0,
    double longitude = 0.0,
  }) {
    // Dark Theme: #1e1e1e background, white text.
    final backgroundColor = '#1e1e1e';
    final textColor = '#ffffff';
    final highlightColor = '#4caf50'; // A nice green for headers or accents

    final imageHtml = iconUrl != null && iconUrl.isNotEmpty
        ? '<div style="margin-bottom: 20px;"><img src="$iconUrl" style="width: 120px; height: 120px; object-fit: contain;" /></div>'
        : '';

    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"
     xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>${title} Information</name>
    <Style id="educational_balloon_style_$id">
      <BalloonStyle>
        <bgColor>ff1e1e1e</bgColor>
        <text><![CDATA[
          <div style="font-family: 'Roboto', Arial, sans-serif; color: $textColor; padding: 20px; width: 450px; text-align: center; background-color: $backgroundColor; border-radius: 12px; border: 2px solid #333;">
            <h1 style="color: $highlightColor; font-size: 36px; margin: 0 0 15px 0;">$title</h1>
            $imageHtml
            <div style="background-color: #2a2a2a; padding: 20px; border-radius: 8px; text-align: left; font-size: 20px; line-height: 1.6;">
              <p>$description</p>
            </div>
          </div>
        ]]></text>
      </BalloonStyle>
    </Style>

    <Placemark id="balloon_$id">
      <name>$title</name>
      <styleUrl>#educational_balloon_style_$id</styleUrl>
      <gx:balloonVisibility>1</gx:balloonVisibility>
      <Point>
        <coordinates>$longitude,$latitude,0</coordinates>
      </Point>
    </Placemark>
  </Document>
</kml>''';
  }
}
