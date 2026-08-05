class EducationalBalloonKmlModel {
  static String generateBalloonKml({
    required String id,
    required String title,
    required String description,
    String? iconUrl,
    double latitude = 0.0,
    double longitude = 0.0,
  }) {
    // Highly decorative and overwhelming styling, but with safe CSS for KML
    final imageHtml = iconUrl != null && iconUrl.isNotEmpty
        ? '<div style="margin-bottom: 40px;"><img src="$iconUrl" style="width: 240px; height: 240px; object-fit: cover; border-radius: 120px; border: 8px solid #00e5ff;" /></div>'
        : '';

    final cleanId = id.replaceAll(' ', '_');
    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"
     xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>${title} Information</name>
    <Style id="educational_balloon_style_$cleanId">
      <IconStyle>
        <scale>0</scale>
      </IconStyle>
      <BalloonStyle>
        <bgColor>ff1e1e1e</bgColor>
        <text><![CDATA[
          <div style="font-family: 'Impact', 'Roboto', Arial, sans-serif; color: #ffffff; padding: 40px; width: 900px; text-align: center; background-color: #001a4d; border-radius: 30px; border: 8px solid #ff007f;">
            <h1 style="color: #00e5ff; font-size: 72px; margin: 0 0 20px 0; text-transform: uppercase; letter-spacing: 4px;">$title</h1>
            <hr style="border: 0; height: 4px; background-color: #ffeb3b; margin: 30px 0;" />
            $imageHtml
            <div style="background-color: #000000; padding: 40px; border-radius: 20px; text-align: left; font-size: 40px; line-height: 1.8; color: #e0f7fa; border: 4px dashed #ffeb3b;">
              <p style="margin: 0;">$description</p>
            </div>
            <hr style="border: 0; height: 4px; background-color: #ff007f; margin: 30px 0 10px 0;" />
            <div style="font-size: 24px; color: #ffeb3b; font-style: italic;">*** Interactive LG Experience ***</div>
          </div>
        ]]></text>
      </BalloonStyle>
    </Style>

    <Placemark id="balloon_$cleanId">
      <name>$title</name>
      <description><![CDATA[Educational Balloon for $title]]></description>
      <styleUrl>#educational_balloon_style_$cleanId</styleUrl>
      <gx:balloonVisibility>1</gx:balloonVisibility>
      <Point>
        <coordinates>$longitude,$latitude,0</coordinates>
      </Point>
    </Placemark>
  </Document>
</kml>''';
  }
}
