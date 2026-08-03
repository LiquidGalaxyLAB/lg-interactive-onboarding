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
    'Tree': EducationalContent(
      title: '3D Tree Model',
      description: 'Trees are an essential part of the ecosystem. In Google Earth, placing 3D models like trees allows urban planners and educators to visualize green spaces. This specific model is exported as a Collada (.dae) file, which is perfectly supported by the Liquid Galaxy system.',
      iconUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/eb/Ash_Tree_-_geograph.org.uk_-_590710.jpg/320px-Ash_Tree_-_geograph.org.uk_-_590710.jpg', 
    ),
    'Car': EducationalContent(
      title: '3D Car Model',
      description: 'Vehicles can be mapped in 3D to simulate traffic patterns or demonstrate city layouts. 3D models must be optimized before sending them to the Liquid Galaxy to ensure smooth rendering across all screens.',
      iconUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a6/Automobile_icon.svg/200px-Automobile_icon.svg.png',
    ),
    'Pyramid': EducationalContent(
      title: '3D Pyramid Model',
      description: 'Historical monuments like pyramids can be visualized to scale in Google Earth. This demonstrates the power of Liquid Galaxy in educational environments, allowing students to explore ancient architecture immersively.',
      iconUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e3/Kheops-Pyramid.jpg/320px-Kheops-Pyramid.jpg',
    ),
    'Football': EducationalContent(
      title: '3D Football Model',
      description: 'A simple geometric sphere mapped with a texture. In Liquid Galaxy, models with custom textures require a KMZ package (a zipped KML + texture images) rather than just a simple KML file.',
      iconUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6e/Football_%28soccer_ball%29.svg/200px-Football_%28soccer_ball%29.svg.png',
    ),
  };

  static const Map<String, EducationalContent> kmlContent = {
    'Placemark': EducationalContent(
      title: 'KML Placemark',
      description: 'A Placemark is one of the most commonly used features in KML. It marks a position on the Earth\'s surface using a Point (latitude and longitude). You can customize its icon and add description balloons just like this one!',
      iconUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d1/Google_Maps_pin.svg/200px-Google_Maps_pin.svg.png',
    ),
    'Polygon': EducationalContent(
      title: 'KML Polygon',
      description: 'A Polygon is defined by an outer boundary and 0 or more inner boundaries (holes). They are great for highlighting specific regions, building footprints, or property lines in Liquid Galaxy.',
      iconUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/79/Vector-polygon.svg/200px-Vector-polygon.svg.png',
    ),
    'LineString': EducationalContent(
      title: 'KML Path (LineString)',
      description: 'A LineString is a connected set of line segments. In Google Earth, it is commonly used to draw paths, borders, or routes, such as a hiking trail or a bus route.',
      iconUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/86/Line-style-icon.svg/200px-Line-style-icon.svg.png',
    ),
    'Ground Overlay': EducationalContent(
      title: 'Ground Overlay',
      description: 'A Ground Overlay drapes an image directly onto the Earth\'s terrain. It is useful for overlaying historical maps, weather data, or custom imagery onto the globe in Liquid Galaxy.',
      iconUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/14/Image-x-generic.svg/200px-Image-x-generic.svg.png',
    ),
    'Screen Overlay': EducationalContent(
      title: 'Screen Overlay',
      description: 'Unlike a Ground Overlay, a Screen Overlay is fixed to the screen regardless of the camera view. It is perfect for adding logos, legends, or HUD elements to your Liquid Galaxy presentation.',
      iconUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/Monitor_icon.svg/200px-Monitor_icon.svg.png',
    ),
    'Tour': EducationalContent(
      title: 'KML Tour',
      description: 'A Tour takes the viewer on a scripted journey through the 3D environment. You can control the camera, add pauses, and toggle the visibility of features seamlessly.',
      iconUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e0/Video_icon.svg/200px-Video_icon.svg.png',
    ),
  };
}
