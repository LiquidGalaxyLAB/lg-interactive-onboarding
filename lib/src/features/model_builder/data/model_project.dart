import 'package:lg_interactive_onboarding/src/common/constants/app_constants.dart';

/// Data class representing a placed 3D model with all adjustable parameters.
///
/// Tracks file info, map location, orientation (heading/tilt/roll),
/// and scale (x/y/z) for KML generation.
class ModelProject {
  // ─── Supported 3D Formats ──────────────────────────────────────

  /// All file extensions the model builder can accept.
  /// We strictly limit this to DAE (native) and ZIP (packaged DAE).
  static const supportedExtensions = [
    '.dae',
    '.zip'
  ];

  /// The native format used by Google Earth / Liquid Galaxy.
  static const nativeExtension = '.dae';

  /// Unique identifier for tracking deployed models on the LG rig.
  final String id;

  /// Path to the selected model file on device storage.
  /// For bundled assets, this will be the temp path after extraction.
  final String? filePath;
  
  /// The relative internal path to the .dae file if extracted from a .zip.
  /// (e.g., 'model_v2/source/main.dae'). Null if the source was a raw .dae.
  final String? internalDaePath;

  /// Original filename of the model.
  final String? fileName;

  /// File size in bytes.
  final int? fileSize;

  /// File extension (e.g., '.dae', '.glb', '.gltf', '.kmz').
  final String? fileExtension;

  /// Whether this model was loaded from a bundled asset.
  final bool isAsset;

  /// Asset path for bundled models (e.g., 'assets/models/model_pyramid.dae').
  final String? assetPath;

  /// Latitude of the model placement.
  final double? latitude;

  /// Longitude of the model placement.
  final double? longitude;

  /// Altitude of the model (meters above ground).
  final double altitude;

  /// Heading: rotation about the Z-axis (0–360°).
  final double heading;

  /// Tilt: rotation about the X-axis (0–90°).
  /// Default 0° (no correction). Adjust per-model as needed.
  final double tilt;

  /// Roll: rotation about the Y-axis (0–360°).
  final double roll;

  /// Scale factor on the X-axis.
  final double scaleX;

  /// Scale factor on the Y-axis.
  final double scaleY;

  /// Scale factor on the Z-axis.
  final double scaleZ;

  /// Whether a model is currently being imported and validated.
  final bool isImporting;

  const ModelProject({
    this.id = '',
    this.filePath,
    this.internalDaePath,
    this.fileName,
    this.fileSize,
    this.fileExtension,
    this.isAsset = false,
    this.assetPath,
    this.latitude,
    this.longitude,
    this.altitude = AppConstants.defaultAltitude,
    this.heading = 0.0,
    this.tilt = 0.0,
    this.roll = 0.0,
    this.scaleX = AppConstants.defaultScale,
    this.scaleY = AppConstants.defaultScale,
    this.scaleZ = AppConstants.defaultScale,
    this.isImporting = false,
  });

  /// Whether a model file has been imported.
  bool get hasModel => filePath != null && filePath!.isNotEmpty;

  /// Whether a location has been placed on the map.
  bool get hasLocation => latitude != null && longitude != null;

  /// Whether the project is ready to generate KML and push.
  bool get isReady => hasModel && hasLocation;

  /// The remote filename used on the LG server.
  /// Prefixed with the project ID to keep deployments isolated.
  String get remoteModelFileName {
    final baseName = fileName ?? '';
    return '${id}_${baseName.replaceAll(' ', '_')}';
  }

  /// The remote KML filename.
  String get remoteKmlFileName =>
      '${id}_${fileName?.replaceAll(RegExp(r'\.[^.]+$'), '').replaceAll(' ', '_')}.kml';

  /// Creates a copy with modified fields.
  ModelProject copyWith({
    String? id,
    String? filePath,
    String? internalDaePath,
    String? fileName,
    int? fileSize,
    String? fileExtension,
    bool? isAsset,
    String? assetPath,
    double? latitude,
    double? longitude,
    double? altitude,
    double? heading,
    double? tilt,
    double? roll,
    double? scaleX,
    double? scaleY,
    double? scaleZ,
    bool? isImporting,
  }) {
    return ModelProject(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      internalDaePath: internalDaePath ?? this.internalDaePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      fileExtension: fileExtension ?? this.fileExtension,
      isAsset: isAsset ?? this.isAsset,
      assetPath: assetPath ?? this.assetPath,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      heading: heading ?? this.heading,
      tilt: tilt ?? this.tilt,
      roll: roll ?? this.roll,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      scaleZ: scaleZ ?? this.scaleZ,
      isImporting: isImporting ?? this.isImporting,
    );
  }

  /// Returns a human-readable file size string.
  String get fileSizeFormatted {
    if (fileSize == null) return 'Unknown';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Returns a default empty project.
  static const empty = ModelProject();
}

/// Represents a model that has been pushed to the LG rig.
class DeployedModel {
  /// Unique ID matching the ModelProject.id that created it.
  final String id;

  /// Display name.
  final String displayName;

  /// Remote model filename on the server.
  final String remoteModelFileName;

  /// Remote KML filename on the server.
  final String remoteKmlFileName;

  /// Latitude where the model was placed.
  final double latitude;

  /// Longitude where the model was placed.
  final double longitude;

  /// Timestamp when the model was deployed.
  final DateTime deployedAt;

  /// Model's altitude for accurate camera framing during orbit.
  final double altitude;

  /// Camera range for orbit.
  final double range;

  /// Camera tilt for orbit.
  final double tilt;

  const DeployedModel({
    required this.id,
    required this.displayName,
    required this.remoteModelFileName,
    required this.remoteKmlFileName,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.range,
    required this.tilt,
    required this.deployedAt,
  });
}
