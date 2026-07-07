import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates a v4 UUID for scene nodes and scenes.
String generateNodeId() => _uuid.v4();

// ─── Scene Node (Sealed Hierarchy) ──────────────────────────────────────────

/// Base class for all items in a scene tree.
///
/// The scene tree uses a flat-map architecture: all nodes live in
/// `Scene.nodes` keyed by [id], and parent-child relationships are
/// expressed via [parentGroupId] and [GroupNode.childIds].
sealed class SceneNode {
  /// Unique identifier for this node.
  final String id;

  /// User-visible name (model filename or user-defined group name).
  final String name;

  /// ID of the parent [GroupNode], or `null` if this node is at the scene root.
  final String? parentGroupId;

  const SceneNode({
    required this.id,
    required this.name,
    this.parentGroupId,
  });

  /// Serialises this node to a JSON-compatible map.
  Map<String, dynamic> toJson();

  /// Deserialises a [SceneNode] from a JSON map.
  ///
  /// Dispatches to [ModelNode.fromJson] or [GroupNode.fromJson] based on
  /// the `type` field.
  factory SceneNode.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return switch (type) {
      'model' => ModelNode.fromJson(json),
      'group' => GroupNode.fromJson(json),
      _ => throw FormatException('Unknown SceneNode type: $type'),
    };
  }

  /// Creates a deep copy with optional field overrides.
  SceneNode copyWith({String? id, String? name, String? parentGroupId});
}

// ─── ModelNode ──────────────────────────────────────────────────────────────

/// A single placed 3D model within a scene.
///
/// References a model file by path (copied to app documents dir on import).
/// Each [ModelNode] carries its own geospatial coordinates and transform
/// properties — KML generation reads these directly.
class ModelNode extends SceneNode {
  /// Original ModelProject.id for traceability (not the same as [id]).
  final String modelAssetId;

  /// Path to the model file on local device storage.
  final String filePath;

  /// Original filename of the model.
  final String fileName;

  /// File extension (e.g., '.dae', '.obj').
  final String? fileExtension;

  /// File size in bytes.
  final int? fileSize;

  /// Whether this model was loaded from a bundled asset.
  final bool isAsset;

  /// Asset path for bundled models.
  final String? assetPath;

  // ─── Geospatial Placement ──────────────────────────────────────────

  final double latitude;
  final double longitude;
  final double altitude;

  // ─── Orientation ───────────────────────────────────────────────────

  final double heading;
  final double tilt;
  final double roll;

  // ─── Scale ─────────────────────────────────────────────────────────

  final double scaleX;
  final double scaleY;
  final double scaleZ;

  const ModelNode({
    required super.id,
    required super.name,
    super.parentGroupId,
    required this.modelAssetId,
    required this.filePath,
    required this.fileName,
    this.fileExtension,
    this.fileSize,
    this.isAsset = false,
    this.assetPath,
    required this.latitude,
    required this.longitude,
    this.altitude = 10.0,
    this.heading = 0.0,
    this.tilt = 0.0,
    this.roll = 0.0,
    this.scaleX = 1000.0,
    this.scaleY = 1000.0,
    this.scaleZ = 1000.0,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'model',
        'id': id,
        'name': name,
        'parentGroupId': parentGroupId,
        'modelAssetId': modelAssetId,
        'filePath': filePath,
        'fileName': fileName,
        'fileExtension': fileExtension,
        'fileSize': fileSize,
        'isAsset': isAsset,
        'assetPath': assetPath,
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'heading': heading,
        'tilt': tilt,
        'roll': roll,
        'scaleX': scaleX,
        'scaleY': scaleY,
        'scaleZ': scaleZ,
      };

  factory ModelNode.fromJson(Map<String, dynamic> json) => ModelNode(
        id: json['id'] as String,
        name: json['name'] as String,
        parentGroupId: json['parentGroupId'] as String?,
        modelAssetId: json['modelAssetId'] as String,
        filePath: json['filePath'] as String,
        fileName: json['fileName'] as String,
        fileExtension: json['fileExtension'] as String?,
        fileSize: json['fileSize'] as int?,
        isAsset: json['isAsset'] as bool? ?? false,
        assetPath: json['assetPath'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        altitude: (json['altitude'] as num?)?.toDouble() ?? 10.0,
        heading: (json['heading'] as num?)?.toDouble() ?? 0.0,
        tilt: (json['tilt'] as num?)?.toDouble() ?? 0.0,
        roll: (json['roll'] as num?)?.toDouble() ?? 0.0,
        scaleX: (json['scaleX'] as num?)?.toDouble() ?? 1000.0,
        scaleY: (json['scaleY'] as num?)?.toDouble() ?? 1000.0,
        scaleZ: (json['scaleZ'] as num?)?.toDouble() ?? 1000.0,
      );

  @override
  ModelNode copyWith({
    String? id,
    String? name,
    String? parentGroupId,
    String? modelAssetId,
    String? filePath,
    String? fileName,
    String? fileExtension,
    int? fileSize,
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
    return ModelNode(
      id: id ?? this.id,
      name: name ?? this.name,
      parentGroupId: parentGroupId ?? this.parentGroupId,
      modelAssetId: modelAssetId ?? this.modelAssetId,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileExtension: fileExtension ?? this.fileExtension,
      fileSize: fileSize ?? this.fileSize,
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

  /// The remote filename used on the LG server (matches ModelProject pattern).
  String get remoteModelFileName {
    final ext = fileExtension?.toLowerCase();
    if (ext != null && ext != '.kmz') {
      final withoutExt = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
      final safeName = withoutExt.replaceAll(' ', '_');
      return '${modelAssetId}_$safeName.dae';
    }
    return '${modelAssetId}_${fileName.replaceAll(' ', '_')}';
  }

  /// The remote KML filename.
  String get remoteKmlFileName =>
      '${modelAssetId}_${fileName.replaceAll(RegExp(r'\.[^.]+$'), '').replaceAll(' ', '_')}.kml';
}

// ─── GroupNode ───────────────────────────────────────────────────────────────

/// A logical group of models and/or nested groups.
///
/// Groups have no geospatial coordinates of their own — transforms are
/// applied as deltas to each child's individual coordinates.
///
/// Maximum nesting depth is capped at [Scene.maxNestingDepth].
class GroupNode extends SceneNode {
  /// Ordered list of child [SceneNode] IDs.
  final List<String> childIds;

  const GroupNode({
    required super.id,
    required super.name,
    super.parentGroupId,
    this.childIds = const [],
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'group',
        'id': id,
        'name': name,
        'parentGroupId': parentGroupId,
        'childIds': childIds,
      };

  factory GroupNode.fromJson(Map<String, dynamic> json) => GroupNode(
        id: json['id'] as String,
        name: json['name'] as String,
        parentGroupId: json['parentGroupId'] as String?,
        childIds: (json['childIds'] as List<dynamic>).cast<String>(),
      );

  @override
  GroupNode copyWith({
    String? id,
    String? name,
    String? parentGroupId,
    List<String>? childIds,
  }) {
    return GroupNode(
      id: id ?? this.id,
      name: name ?? this.name,
      parentGroupId: parentGroupId ?? this.parentGroupId,
      childIds: childIds ?? List.of(this.childIds),
    );
  }
}

// ─── Scene ──────────────────────────────────────────────────────────────────

/// Top-level scene container, serialisable to `.lgscene` JSON.
///
/// Uses a flat-map architecture: all [SceneNode]s live in [nodes] keyed by
/// their ID, and [rootNodeIds] defines the top-level ordering. Parent-child
/// relationships are expressed via [SceneNode.parentGroupId] and
/// [GroupNode.childIds].
class Scene {
  /// Maximum allowed nesting depth for groups.
  static const int maxNestingDepth = 5;

  /// Unique identifier for this scene.
  final String id;

  /// User-defined scene name.
  final String name;

  /// When the scene was first created.
  final DateTime createdAt;

  /// When the scene was last modified.
  final DateTime modifiedAt;

  /// Schema version for future migration support.
  final int version;

  /// Flat map of all nodes in the scene, keyed by node ID.
  final Map<String, SceneNode> nodes;

  /// Ordered list of top-level node IDs (nodes with no parent).
  final List<String> rootNodeIds;

  Scene({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.modifiedAt,
    this.version = 1,
    Map<String, SceneNode>? nodes,
    List<String>? rootNodeIds,
  })  : nodes = nodes ?? {},
        rootNodeIds = rootNodeIds ?? [];

  /// Creates a new empty scene with the given name.
  factory Scene.create(String name) {
    final now = DateTime.now();
    return Scene(
      id: generateNodeId(),
      name: name,
      createdAt: now,
      modifiedAt: now,
    );
  }

  /// Total count of [ModelNode]s in the scene (excludes groups).
  int get modelCount =>
      nodes.values.whereType<ModelNode>().length;

  /// Calculates the nesting depth of a given node.
  ///
  /// Returns 0 for root-level nodes, 1 for children of root groups, etc.
  int depthOf(String nodeId) {
    int depth = 0;
    String? currentId = nodes[nodeId]?.parentGroupId;
    while (currentId != null && depth < maxNestingDepth + 1) {
      depth++;
      currentId = nodes[currentId]?.parentGroupId;
    }
    return depth;
  }

  /// Returns all [ModelNode]s that are descendants of the given group,
  /// recursively walking nested groups.
  List<ModelNode> allModelDescendants(String groupId) {
    final result = <ModelNode>[];
    final group = nodes[groupId];
    if (group is! GroupNode) return result;

    for (final childId in group.childIds) {
      final child = nodes[childId];
      if (child is ModelNode) {
        result.add(child);
      } else if (child is GroupNode) {
        result.addAll(allModelDescendants(childId));
      }
    }
    return result;
  }

  /// Creates a deep copy with optional field overrides.
  Scene copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? modifiedAt,
    int? version,
    Map<String, SceneNode>? nodes,
    List<String>? rootNodeIds,
  }) {
    return Scene(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? DateTime.now(),
      version: version ?? this.version,
      nodes: nodes ?? Map.of(this.nodes),
      rootNodeIds: rootNodeIds ?? List.of(this.rootNodeIds),
    );
  }

  /// Serialises the entire scene to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'version': version,
        'nodes': nodes.map((k, v) => MapEntry(k, v.toJson())),
        'rootNodeIds': rootNodeIds,
      };

  /// Deserialises a [Scene] from a JSON map.
  factory Scene.fromJson(Map<String, dynamic> json) {
    final nodesMap = <String, SceneNode>{};
    final rawNodes = json['nodes'] as Map<String, dynamic>;
    for (final entry in rawNodes.entries) {
      nodesMap[entry.key] =
          SceneNode.fromJson(entry.value as Map<String, dynamic>);
    }

    return Scene(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      version: json['version'] as int? ?? 1,
      nodes: nodesMap,
      rootNodeIds: (json['rootNodeIds'] as List<dynamic>).cast<String>(),
    );
  }
}

// ─── Scene Metadata ─────────────────────────────────────────────────────────

/// Lightweight metadata stored in SharedPreferences for the scene index.
///
/// The full scene data lives on disk as a `.lgscene` JSON file.
class SceneMetadata {
  final String id;
  final String name;
  final DateTime lastModified;
  final int modelCount;

  const SceneMetadata({
    required this.id,
    required this.name,
    required this.lastModified,
    this.modelCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lastModified': lastModified.toIso8601String(),
        'modelCount': modelCount,
      };

  factory SceneMetadata.fromJson(Map<String, dynamic> json) => SceneMetadata(
        id: json['id'] as String,
        name: json['name'] as String,
        lastModified: DateTime.parse(json['lastModified'] as String),
        modelCount: json['modelCount'] as int? ?? 0,
      );
}
