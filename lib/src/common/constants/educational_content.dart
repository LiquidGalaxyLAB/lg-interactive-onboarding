class EducationalContent {
  final String title;
  final String description;
  final String? iconUrl;

  const EducationalContent({
    required this.title,
    required this.description,
    this.iconUrl,
  });
}

class EducationalConstants {
  static const Map<String, EducationalContent> modelContent = {

    'Car': EducationalContent(
      title: '3D Car Model',
      description:
          'Vehicles can be mapped in 3D to simulate traffic patterns or demonstrate city layouts. 3D models must be optimized before sending them to the Liquid Galaxy to ensure smooth rendering across all screens.',
      iconUrl:
          'http://lg1:81/kml_icons/car.png',
    ),
    'Pyramid': EducationalContent(
      title: '3D Pyramid Model',
      description:
          'Historical monuments like pyramids can be visualized to scale in Google Earth. This demonstrates the power of Liquid Galaxy in educational environments, allowing students to explore ancient architecture immersively.',
      iconUrl:
          'http://lg1:81/kml_icons/pyramid.png',
    ),

  };

  static const Map<String, EducationalContent> kmlContent = {
    'Placemark': EducationalContent(
      title: 'KML Placemark',
      description:
          'A Placemark is one of the most commonly used features in KML. It marks a position on the Earth\'s surface using a Point (latitude and longitude). You can customize its icon and add description balloons just like this one!',
      iconUrl:
          'http://lg1:81/kml_icons/placemark.png',
    ),
    'Polygon': EducationalContent(
      title: 'KML Polygon',
      description:
          'A Polygon is defined by an outer boundary and 0 or more inner boundaries (holes). They are great for highlighting specific regions, building footprints, or property lines in Liquid Galaxy.',
      iconUrl:
          'http://lg1:81/kml_icons/polygon.png',
    ),
    'LineString': EducationalContent(
      title: 'KML Path (LineString)',
      description:
          'A LineString is a connected set of line segments. In Google Earth, it is commonly used to draw paths, borders, or routes, such as a hiking trail or a bus route.',
      iconUrl:
          'http://lg1:81/kml_icons/linestring.png',
    ),
    'Ground Overlay': EducationalContent(
      title: 'Ground Overlay',
      description:
          'A Ground Overlay drapes an image directly onto the Earth\'s terrain. It is useful for overlaying historical maps, weather data, or custom imagery onto the globe in Liquid Galaxy.',
      iconUrl:
          'http://lg1:81/kml_icons/ground_overlay.png',
    ),
    'Screen Overlay': EducationalContent(
      title: 'Screen Overlay',
      description:
          'Unlike a Ground Overlay, a Screen Overlay is fixed to the screen regardless of the camera view. It is perfect for adding logos, legends, or HUD elements to your Liquid Galaxy presentation.',
      iconUrl:
          'http://lg1:81/kml_icons/screen_overlay.png',
    ),
    'Tour': EducationalContent(
      title: 'KML Tour',
      description:
          'A Tour takes the viewer on a scripted journey through the 3D environment. You can control the camera, add pauses, and toggle the visibility of features seamlessly.',
      iconUrl:
          'http://lg1:81/kml_icons/tour.png',
    ),
  };
}
