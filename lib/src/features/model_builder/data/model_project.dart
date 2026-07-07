import 'package:lg_interactive_onboarding/src/common/constants/app_constants.dart';

/// Data class representing a placed 3D model with all adjustable parameters.
///
/// Tracks file info, map location, orientation (heading/tilt/roll),
/// and scale (x/y/z) for KML generation.
class ModelProject {
  // ─── Supported 3D Formats ──────────────────────────────────────

  /// All file extensions the model builder can accept.
  /// Non-DAE formats are converted to DAE via assimp on the LG master.
  static const supportedExtensions = [
    // Common / Native formats
    '.dae', '.obj', '.fbx', '.blend', '.gltf', '.glb', '.kmz', '.stl', '.ply', '.3ds',
    // Extended Assimp formats
    '.3d', '.ac', '.ac3d', '.acc', '.ase', '.ask', '.assbin', '.b3d', '.bvh',
    '.cob', '.csm', '.dxf', '.enff', '.hmp', '.ifc', '.ifczip', '.irr', '.irrmesh',
    '.lwo', '.lws', '.lxo', '.md2', '.md3', '.md5anim', '.md5camera', '.md5mesh',
    '.mdc', '.mdl', '.mesh', '.mesh.xml', '.mot', '.ms3d', '.ndo', '.nff', '.off',
    '.ogex', '.pk3', '.prj', '.q3o', '.q3s', '.raw', '.scn', '.smd', '.ter',
    '.uc', '.vta', '.x', '.xgl', '.xml', '.zgl'
  ];

  /// The native format used by Google Earth / Liquid Galaxy.
  static const nativeExtension = '.dae';

  /// Unique identifier for tracking deployed models on the LG rig.
  final String id;

  /// Path to the selected model file on device storage.
  /// For bundled assets, this will be the temp path after extraction.
  final String? filePath;

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

  const ModelProject({
    this.id = '',
    this.filePath,
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
  });

  /// Whether a model file has been imported.
  bool get hasModel => filePath != null && filePath!.isNotEmpty;

  /// Whether a location has been placed on the map.
  bool get hasLocation => latitude != null && longitude != null;

  /// Whether the project is ready to generate KML and push.
  bool get isReady => hasModel && hasLocation;



  /// Whether this file needs assimp conversion to DAE before deployment.
  /// KMZ files have their own handling path and are excluded.
  bool get requiresConversion {
    final ext = fileExtension?.toLowerCase();
    return ext != null && ext != '.kmz';
  }

  /// The remote filename used on the LG server.
  /// Prefixed with the project ID to keep deployments isolated.
  /// Non-KMZ files always get a .dae suffix since they are converted/triangulated.
  String get remoteModelFileName {
    final baseName = fileName ?? '';
    if (requiresConversion) {
      // Replace original extension with .dae (e.g., model.obj → {id}_model.dae)
      final withoutExt = baseName.replaceAll(RegExp(r'\.[^.]+$'), '');
      final safeName = withoutExt.replaceAll(' ', '_');
      return '${id}_$safeName.dae';
    }
    return '${id}_${baseName.replaceAll(' ', '_')}';
  }

  /// The remote KML filename.
  String get remoteKmlFileName =>
      '${id}_${fileName?.replaceAll(RegExp(r'\.[^.]+$'), '').replaceAll(' ', '_')}.kml';

  /// Creates a copy with modified fields.
  ModelProject copyWith({
    String? id,
    String? filePath,
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
  }) {
    return ModelProject(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
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

  const DeployedModel({
    required this.id,
    required this.displayName,
    required this.remoteModelFileName,
    required this.remoteKmlFileName,
    required this.latitude,
    required this.longitude,
    required this.deployedAt,
  });
}
