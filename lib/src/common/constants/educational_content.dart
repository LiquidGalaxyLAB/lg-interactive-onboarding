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
      // Using a placeholder image icon from a reliable CDN or leave empty
      iconUrl: 'https://cdn-icons-png.flaticon.com/512/2991/2991176.png', 
    ),
    'Car': EducationalContent(
      title: '3D Car Model',
      description: 'Vehicles can be mapped in 3D to simulate traffic patterns or demonstrate city layouts. 3D models must be optimized before sending them to the Liquid Galaxy to ensure smooth rendering across all screens.',
      iconUrl: 'https://cdn-icons-png.flaticon.com/512/3204/3204121.png',
    ),
    'Pyramid': EducationalContent(
      title: '3D Pyramid Model',
      description: 'Historical monuments like pyramids can be visualized to scale in Google Earth. This demonstrates the power of Liquid Galaxy in educational environments, allowing students to explore ancient architecture immersively.',
      iconUrl: 'https://cdn-icons-png.flaticon.com/512/3069/3069151.png',
    ),
    'Football': EducationalContent(
      title: '3D Football Model',
      description: 'A simple geometric sphere mapped with a texture. In Liquid Galaxy, models with custom textures require a KMZ package (a zipped KML + texture images) rather than just a simple KML file.',
      iconUrl: 'https://cdn-icons-png.flaticon.com/512/1165/1165187.png',
    ),
  };

  static const Map<String, EducationalContent> kmlContent = {
    'Placemark': EducationalContent(
      title: 'KML Placemark',
      description: 'A Placemark is one of the most commonly used features in KML. It marks a position on the Earth\'s surface using a Point (latitude and longitude). You can customize its icon and add description balloons just like this one!',
      iconUrl: 'https://cdn-icons-png.flaticon.com/512/3082/3082383.png',
    ),
    'Polygon': EducationalContent(
      title: 'KML Polygon',
      description: 'A Polygon is defined by an outer boundary and 0 or more inner boundaries (holes). They are great for highlighting specific regions, building footprints, or property lines in Liquid Galaxy.',
      iconUrl: 'https://cdn-icons-png.flaticon.com/512/2723/2723049.png',
    ),
    'LineString': EducationalContent(
      title: 'KML Path (LineString)',
      description: 'A LineString is a connected set of line segments. In Google Earth, it is commonly used to draw paths, borders, or routes, such as a hiking trail or a bus route.',
      iconUrl: 'https://cdn-icons-png.flaticon.com/512/3603/3603953.png',
    ),
    'Ground Overlay': EducationalContent(
      title: 'Ground Overlay',
      description: 'A Ground Overlay drapes an image directly onto the Earth\'s terrain. It is useful for overlaying historical maps, weather data, or custom imagery onto the globe in Liquid Galaxy.',
      iconUrl: 'https://cdn-icons-png.flaticon.com/512/2600/2600021.png',
    ),
    'Screen Overlay': EducationalContent(
      title: 'Screen Overlay',
      description: 'A Screen Overlay fixes an image to the screen, independent of the Earth\'s rotation. This is commonly used for displaying logos, legends, or head-up displays on the Liquid Galaxy screens.',
      iconUrl: 'https://cdn-icons-png.flaticon.com/512/3342/3342137.png',
    ),
    'Tour': EducationalContent(
      title: 'KML Tour',
      description: 'A KML Tour provides a controlled flight experience through the 3D environment. You can script camera movements, pauses, and feature toggles to create guided presentations in Liquid Galaxy.',
      iconUrl: 'https://cdn-icons-png.flaticon.com/512/3468/3468306.png',
    ),
  };
}
