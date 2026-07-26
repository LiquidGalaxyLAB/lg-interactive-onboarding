/// Utility functions for geographic and geometric calculations.
class GeoMath {
  /// Calculates the centroid (average latitude and longitude) for a polygon's vertices.
  /// 
  /// The [vertices] parameter should be a list of maps, each containing 'lat' and 'lng' keys.
  /// If the vertices list is empty or invalid, returns (0.0, 0.0).
  static (double lat, double lng) calculateCentroid(dynamic vertices) {
    if (vertices is! List || vertices.isEmpty) {
      return (0.0, 0.0);
    }
    
    double sumLat = 0;
    double sumLng = 0;
    int count = 0;
    
    for (final v in vertices) {
      if (v is Map) {
        sumLat += (v['lat'] as num?)?.toDouble() ?? 0.0;
        sumLng += (v['lng'] as num?)?.toDouble() ?? 0.0;
        count++;
      }
    }
    
    if (count > 0) {
      return (sumLat / count, sumLng / count);
    }
    
    return (0.0, 0.0);
  }

  /// Extracts a double from a dynamic map value, safely handling int or string types.
  static double? extractDouble(Map<String, dynamic> params, String key) {
    final value = params[key];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
