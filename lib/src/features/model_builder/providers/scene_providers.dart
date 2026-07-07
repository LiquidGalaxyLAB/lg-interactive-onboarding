import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lg_interactive_onboarding/src/features/model_builder/data/model_project.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/data/scene_models.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/data/scene_repository.dart';

// ─── Scene State ────────────────────────────────────────────────────────────

/// Immutable snapshot of the active scene and its UI-level selection state.
class SceneState {
  /// The currently active scene, or `null` if no scene is loaded.
  final Scene? activeScene;

  /// Set of currently selected node IDs in the outliner.
  final Set<String> selectedNodeIds;

  /// Whether the scene has unsaved modifications.
  final bool isDirty;

  const SceneState({
    this.activeScene,
    this.selectedNodeIds = const {},
    this.isDirty = false,
  });

  // ─── Derived Helpers ──────────────────────────────────────────────────

  /// Whether a scene is currently loaded.
  bool get hasScene => activeScene != null;

  /// Whether any nodes are selected.
  bool get hasSelection => selectedNodeIds.isNotEmpty;

  /// Whether the "Group" action is available (2+ nodes selected).
  bool get canGroup => selectedNodeIds.length >= 2;

  /// Whether the "Ungroup" action is available (exactly 1 group selected).
  bool get canUngroup {
    if (selectedNodeIds.length != 1) return false;
    final node = activeScene?.nodes[selectedNodeIds.first];
    return node is GroupNode;
  }

  /// Top-level nodes in display order.
  List<SceneNode> get rootNodes {
    final scene = activeScene;
    if (scene == null) return [];
    return scene.rootNodeIds
        .map((id) => scene.nodes[id])
        .whereType<SceneNode>()
        .toList();
  }

  /// Returns the children of a group node in display order.
  List<SceneNode> getChildrenOf(String groupId) {
    final scene = activeScene;
    if (scene == null) return [];
    final group = scene.nodes[groupId];
    if (group is! GroupNode) return [];
    return group.childIds
        .map((id) => scene.nodes[id])
        .whereType<SceneNode>()
        .toList();
  }

  SceneState copyWith({
    Scene? activeScene,
    Set<String>? selectedNodeIds,
    bool? isDirty,
  }) {
    return SceneState(
      activeScene: activeScene ?? this.activeScene,
      selectedNodeIds: selectedNodeIds ?? this.selectedNodeIds,
      isDirty: isDirty ?? this.isDirty,
    );
  }
}

// ─── Scene Notifier ─────────────────────────────────────────────────────────

/// Central Riverpod [Notifier] managing the active scene's full state.
///
/// This notifier is the bridge between the single-model [ModelBuilderNotifier]
/// and the multi-model scene system. When the user finishes configuring a
/// model via the existing import workflow, [addModelFromProject] snapshots
/// it into the active scene.
class SceneNotifier extends Notifier<SceneState> {
  @override
  SceneState build() => const SceneState();

  // ─── Scene Lifecycle ──────────────────────────────────────────────────

  /// Creates a new empty scene with the given name.
  void newScene(String name) {
    state = SceneState(
      activeScene: Scene.create(name),
      isDirty: true,
    );
    debugPrint('SceneNotifier: Created new scene "$name"');
  }

  /// Loads a scene from disk by its ID.
  Future<void> loadScene(String sceneId) async {
    final repo = ref.read(sceneRepositoryProvider);
    final scene = await repo.loadScene(sceneId);
    if (scene != null) {
      state = SceneState(activeScene: scene);
      debugPrint('SceneNotifier: Loaded scene "${scene.name}"');
    }
  }

  /// Saves the current scene to disk.
  Future<void> saveScene() async {
    final scene = state.activeScene;
    if (scene == null) return;

    final repo = ref.read(sceneRepositoryProvider);
    final updated = scene.copyWith(modifiedAt: DateTime.now());
    await repo.saveScene(updated);

    state = state.copyWith(activeScene: updated, isDirty: false);

    // Signal curriculum auto-verification
    ref.read(sceneSavedProvider.notifier).set(true);

    debugPrint('SceneNotifier: Saved scene "${updated.name}"');
  }

  /// Closes the active scene without saving.
  void closeScene() {
    state = const SceneState();
  }

  /// Renames the active scene.
  void renameScene(String newName) {
    final scene = state.activeScene;
    if (scene == null) return;

    state = state.copyWith(
      activeScene: scene.copyWith(name: newName),
      isDirty: true,
    );
  }

  // ─── Model Management ─────────────────────────────────────────────────

  /// Snapshots a [ModelProject] into a [ModelNode] and adds it to the
  /// scene root.
  ///
  /// This is the primary bridge between the existing single-model import
  /// workflow and the scene system.
  void addModelFromProject(ModelProject project) {
    final scene = state.activeScene;
    if (scene == null) return;

    if (!project.hasModel || !project.hasLocation) {
      debugPrint('SceneNotifier: Cannot add incomplete project to scene');
      return;
    }

    final nodeId = generateNodeId();
    final modelNode = ModelNode(
      id: nodeId,
      name: project.fileName ?? 'Unnamed Model',
      modelAssetId: project.id,
      filePath: project.filePath!,
      fileName: project.fileName!,
      fileExtension: project.fileExtension,
      fileSize: project.fileSize,
      isAsset: project.isAsset,
      assetPath: project.assetPath,
      latitude: project.latitude!,
      longitude: project.longitude!,
      altitude: project.altitude,
      heading: project.heading,
      tilt: project.tilt,
      roll: project.roll,
      scaleX: project.scaleX,
      scaleY: project.scaleY,
      scaleZ: project.scaleZ,
    );

    final updatedNodes = Map<String, SceneNode>.of(scene.nodes);
    updatedNodes[nodeId] = modelNode;

    final updatedRootIds = List<String>.of(scene.rootNodeIds)..add(nodeId);

    state = state.copyWith(
      activeScene: scene.copyWith(
        nodes: updatedNodes,
        rootNodeIds: updatedRootIds,
      ),
      isDirty: true,
    );

    debugPrint('SceneNotifier: Added model "${modelNode.name}" to scene');
  }

  /// Removes a node (model or group) from the scene.
  ///
  /// If removing a group, all descendants are also removed.
  void removeNode(String nodeId) {
    final scene = state.activeScene;
    if (scene == null) return;

    final node = scene.nodes[nodeId];
    if (node == null) return;

    final updatedNodes = Map<String, SceneNode>.of(scene.nodes);
    final updatedRootIds = List<String>.of(scene.rootNodeIds);
    final updatedSelection = Set<String>.of(state.selectedNodeIds);

    // Collect all IDs to remove (node + descendants if group)
    final idsToRemove = <String>{nodeId};
    if (node is GroupNode) {
      _collectDescendantIds(node, scene, idsToRemove);
    }

    // Remove from parent's childIds
    if (node.parentGroupId != null) {
      final parent = updatedNodes[node.parentGroupId!];
      if (parent is GroupNode) {
        updatedNodes[parent.id] = parent.copyWith(
          childIds: parent.childIds.where((id) => id != nodeId).toList(),
        );
      }
    }

    // Remove from root if at root level
    updatedRootIds.removeWhere(idsToRemove.contains);

    // Remove all collected nodes
    updatedNodes.removeWhere((id, _) => idsToRemove.contains(id));

    // Clean up selection
    updatedSelection.removeAll(idsToRemove);

    state = state.copyWith(
      activeScene: scene.copyWith(
        nodes: updatedNodes,
        rootNodeIds: updatedRootIds,
      ),
      selectedNodeIds: updatedSelection,
      isDirty: true,
    );
  }

  /// Recursively collects all descendant IDs of a group.
  void _collectDescendantIds(
      GroupNode group, Scene scene, Set<String> ids) {
    for (final childId in group.childIds) {
      ids.add(childId);
      final child = scene.nodes[childId];
      if (child is GroupNode) {
        _collectDescendantIds(child, scene, ids);
      }
    }
  }

  /// Duplicates a node (and its descendants if a group) at the same level.
  void duplicateNode(String nodeId) {
    final scene = state.activeScene;
    if (scene == null) return;

    final node = scene.nodes[nodeId];
    if (node == null) return;

    final updatedNodes = Map<String, SceneNode>.of(scene.nodes);
    final updatedRootIds = List<String>.of(scene.rootNodeIds);

    final newId = generateNodeId();
    final SceneNode duplicated;

    if (node is ModelNode) {
      duplicated = node.copyWith(
        id: newId,
        name: '${node.name} (copy)',
        modelAssetId: generateNodeId(), // New asset ID for isolation
      );
    } else if (node is GroupNode) {
      // Deep-duplicate the group and all its children
      final idMapping = <String, String>{}; // old ID → new ID
      idMapping[nodeId] = newId;
      _buildDuplicateMapping(node, scene, idMapping);

      // Create duplicated children
      for (final entry in idMapping.entries) {
        if (entry.key == nodeId) continue; // Skip the group itself for now
        final original = scene.nodes[entry.key];
        if (original is ModelNode) {
          updatedNodes[entry.value] = original.copyWith(
            id: entry.value,
            name: original.name,
            modelAssetId: generateNodeId(),
            parentGroupId: idMapping[original.parentGroupId!],
          );
        } else if (original is GroupNode) {
          updatedNodes[entry.value] = original.copyWith(
            id: entry.value,
            name: original.name,
            parentGroupId: original.parentGroupId != null
                ? idMapping[original.parentGroupId!]
                : null,
            childIds: original.childIds
                .map((cid) => idMapping[cid] ?? cid)
                .toList(),
          );
        }
      }

      duplicated = (node as GroupNode).copyWith(
        id: newId,
        name: '${node.name} (copy)',
        childIds: node.childIds
            .map((cid) => idMapping[cid] ?? cid)
            .toList(),
      );
    } else {
      return;
    }

    updatedNodes[newId] = duplicated;

    // Insert at the same level
    if (node.parentGroupId != null) {
      final parent = updatedNodes[node.parentGroupId!];
      if (parent is GroupNode) {
        final idx = parent.childIds.indexOf(nodeId);
        final newChildIds = List<String>.of(parent.childIds)
          ..insert(idx + 1, newId);
        updatedNodes[parent.id] = parent.copyWith(childIds: newChildIds);
      }
    } else {
      final idx = updatedRootIds.indexOf(nodeId);
      updatedRootIds.insert(idx + 1, newId);
    }

    state = state.copyWith(
      activeScene: scene.copyWith(
        nodes: updatedNodes,
        rootNodeIds: updatedRootIds,
      ),
      isDirty: true,
    );
  }

  void _buildDuplicateMapping(
      GroupNode group, Scene scene, Map<String, String> mapping) {
    for (final childId in group.childIds) {
      mapping[childId] = generateNodeId();
      final child = scene.nodes[childId];
      if (child is GroupNode) {
        _buildDuplicateMapping(child, scene, mapping);
      }
    }
  }

  // ─── Scene Relocation ─────────────────────────────────────────────────

  /// Relocates the entire scene to a new center coordinate, maintaining the
  /// relative distances between all models.
  ///
  /// The first model found in the scene tree acts as the anchor. It is moved
  /// exactly to [targetLat] and [targetLng], and all other models are shifted
  /// by the exact same delta.
  void relocateScene(double targetLat, double targetLng) {
    final scene = state.activeScene;
    if (scene == null) return;

    // Find the first model node to use as an anchor
    ModelNode? anchor;
    void findAnchor(List<String> nodeIds) {
      if (anchor != null) return;
      for (final id in nodeIds) {
        final node = scene.nodes[id];
        if (node is ModelNode) {
          anchor = node;
          return;
        } else if (node is GroupNode) {
          findAnchor(node.childIds);
        }
      }
    }
    findAnchor(scene.rootNodeIds);

    if (anchor == null) {
      debugPrint('SceneNotifier: Cannot relocate scene with no models.');
      return;
    }

    final deltaLat = targetLat - anchor!.latitude;
    final deltaLng = targetLng - anchor!.longitude;

    final updatedNodes = Map<String, SceneNode>.of(scene.nodes);

    for (final entry in updatedNodes.entries) {
      final node = entry.value;
      if (node is ModelNode) {
        updatedNodes[entry.key] = node.copyWith(
          latitude: node.latitude + deltaLat,
          longitude: node.longitude + deltaLng,
        );
      }
    }

    state = state.copyWith(
      activeScene: scene.copyWith(nodes: updatedNodes),
      isDirty: true,
    );
    debugPrint('SceneNotifier: Relocated scene to $targetLat, $targetLng');
  }

  // ─── Grouping ─────────────────────────────────────────────────────────

  /// Groups the currently selected nodes into a new group.
  ///
  /// All selected nodes must be at the same level (same parent).
  /// The new group is inserted at the position of the first selected node.
  void groupSelected(String groupName) {
    final scene = state.activeScene;
    if (scene == null || state.selectedNodeIds.length < 2) return;

    final selectedIds = state.selectedNodeIds.toList();

    // Verify all selected nodes share the same parent
    final parents = selectedIds
        .map((id) => scene.nodes[id]?.parentGroupId)
        .toSet();
    if (parents.length != 1) {
      debugPrint('SceneNotifier: Cannot group nodes from different parents');
      return;
    }

    final parentId = parents.first; // null = root level

    // Check nesting depth limit
    if (parentId != null) {
      final parentDepth = scene.depthOf(parentId);
      if (parentDepth + 1 >= Scene.maxNestingDepth) {
        debugPrint('SceneNotifier: Maximum nesting depth reached');
        return;
      }
    }

    final groupId = generateNodeId();
    final updatedNodes = Map<String, SceneNode>.of(scene.nodes);

    // Update each selected node's parentGroupId
    for (final id in selectedIds) {
      final node = updatedNodes[id]!;
      updatedNodes[id] = node.copyWith(parentGroupId: groupId);
    }

    // Create the group node
    final group = GroupNode(
      id: groupId,
      name: groupName,
      parentGroupId: parentId,
      childIds: selectedIds,
    );
    updatedNodes[groupId] = group;

    // Update the parent's child list
    if (parentId != null) {
      final parent = updatedNodes[parentId] as GroupNode;
      final newChildIds = List<String>.of(parent.childIds);
      // Find the position of the first selected item
      final insertIdx = newChildIds.indexWhere(selectedIds.contains);
      // Remove all selected items
      newChildIds.removeWhere(selectedIds.contains);
      // Insert the group at the first selected item's position
      newChildIds.insert(insertIdx.clamp(0, newChildIds.length), groupId);
      updatedNodes[parentId] = parent.copyWith(childIds: newChildIds);
    } else {
      // Root level
      final updatedRootIds = List<String>.of(scene.rootNodeIds);
      final insertIdx = updatedRootIds.indexWhere(selectedIds.contains);
      updatedRootIds.removeWhere(selectedIds.contains);
      updatedRootIds.insert(
          insertIdx.clamp(0, updatedRootIds.length), groupId);

      state = state.copyWith(
        activeScene: scene.copyWith(
          nodes: updatedNodes,
          rootNodeIds: updatedRootIds,
        ),
        selectedNodeIds: {groupId},
        isDirty: true,
      );

      // Signal curriculum auto-verification
      ref.read(groupCreatedProvider.notifier).set(true);
      return;
    }

    state = state.copyWith(
      activeScene: scene.copyWith(nodes: updatedNodes),
      selectedNodeIds: {groupId},
      isDirty: true,
    );

    // Signal curriculum auto-verification
    ref.read(groupCreatedProvider.notifier).set(true);
  }

  /// Breaks a group back into its individual children.
  ///
  /// The children are promoted to the group's parent level.
  void ungroupNode(String groupId) {
    final scene = state.activeScene;
    if (scene == null) return;

    final group = scene.nodes[groupId];
    if (group is! GroupNode) return;

    final updatedNodes = Map<String, SceneNode>.of(scene.nodes);
    final parentId = group.parentGroupId;

    // Update each child's parentGroupId to the group's parent
    for (final childId in group.childIds) {
      final child = updatedNodes[childId]!;
      updatedNodes[childId] = child.copyWith(parentGroupId: parentId);
    }

    // Remove the group node itself
    updatedNodes.remove(groupId);

    if (parentId != null) {
      // Insert children into parent at the group's position
      final parent = updatedNodes[parentId] as GroupNode;
      final newChildIds = List<String>.of(parent.childIds);
      final idx = newChildIds.indexOf(groupId);
      newChildIds.removeAt(idx);
      newChildIds.insertAll(idx, group.childIds);
      updatedNodes[parentId] = parent.copyWith(childIds: newChildIds);

      state = state.copyWith(
        activeScene: scene.copyWith(nodes: updatedNodes),
        selectedNodeIds: group.childIds.toSet(),
        isDirty: true,
      );
    } else {
      // Root level
      final updatedRootIds = List<String>.of(scene.rootNodeIds);
      final idx = updatedRootIds.indexOf(groupId);
      updatedRootIds.removeAt(idx);
      updatedRootIds.insertAll(idx, group.childIds);

      state = state.copyWith(
        activeScene: scene.copyWith(
          nodes: updatedNodes,
          rootNodeIds: updatedRootIds,
        ),
        selectedNodeIds: group.childIds.toSet(),
        isDirty: true,
      );
    }
  }

  /// Moves a node into a group (drag-and-drop target).
  void moveNodeToGroup(String nodeId, String targetGroupId) {
    final scene = state.activeScene;
    if (scene == null) return;

    final node = scene.nodes[nodeId];
    final targetGroup = scene.nodes[targetGroupId];
    if (node == null || targetGroup is! GroupNode) return;

    // Prevent circular references
    if (nodeId == targetGroupId) return;
    if (node is GroupNode && _isDescendant(targetGroupId, nodeId, scene)) {
      return;
    }

    // Check nesting depth
    final targetDepth = scene.depthOf(targetGroupId);
    int nodeMaxDepth = 0;
    if (node is GroupNode) {
      nodeMaxDepth = _maxChildDepth(node, scene);
    }
    if (targetDepth + 1 + nodeMaxDepth >= Scene.maxNestingDepth) {
      debugPrint('SceneNotifier: Move would exceed max nesting depth');
      return;
    }

    final updatedNodes = Map<String, SceneNode>.of(scene.nodes);
    final updatedRootIds = List<String>.of(scene.rootNodeIds);

    // Remove from current parent
    final oldParentId = node.parentGroupId;
    if (oldParentId != null) {
      final oldParent = updatedNodes[oldParentId] as GroupNode;
      updatedNodes[oldParentId] = oldParent.copyWith(
        childIds: oldParent.childIds.where((id) => id != nodeId).toList(),
      );
    } else {
      updatedRootIds.remove(nodeId);
    }

    // Add to target group
    updatedNodes[nodeId] = node.copyWith(parentGroupId: targetGroupId);
    final updatedTarget = updatedNodes[targetGroupId] as GroupNode;
    updatedNodes[targetGroupId] = updatedTarget.copyWith(
      childIds: [...updatedTarget.childIds, nodeId],
    );

    state = state.copyWith(
      activeScene: scene.copyWith(
        nodes: updatedNodes,
        rootNodeIds: updatedRootIds,
      ),
      isDirty: true,
    );
  }

  /// Moves a node to the scene root level.
  void moveNodeToRoot(String nodeId) {
    final scene = state.activeScene;
    if (scene == null) return;

    final node = scene.nodes[nodeId];
    if (node == null || node.parentGroupId == null) return;

    final updatedNodes = Map<String, SceneNode>.of(scene.nodes);

    // Remove from current parent
    final oldParent = updatedNodes[node.parentGroupId!] as GroupNode;
    updatedNodes[node.parentGroupId!] = oldParent.copyWith(
      childIds: oldParent.childIds.where((id) => id != nodeId).toList(),
    );

    // Set parent to null and add to root
    updatedNodes[nodeId] = node.copyWith(parentGroupId: null);
    final updatedRootIds = List<String>.of(scene.rootNodeIds)..add(nodeId);

    state = state.copyWith(
      activeScene: scene.copyWith(
        nodes: updatedNodes,
        rootNodeIds: updatedRootIds,
      ),
      isDirty: true,
    );
  }

  /// Checks if [potentialDescendantId] is a descendant of [ancestorId].
  bool _isDescendant(
      String potentialDescendantId, String ancestorId, Scene scene) {
    final ancestor = scene.nodes[ancestorId];
    if (ancestor is! GroupNode) return false;
    for (final childId in ancestor.childIds) {
      if (childId == potentialDescendantId) return true;
      if (_isDescendant(potentialDescendantId, childId, scene)) return true;
    }
    return false;
  }

  /// Returns the maximum depth of children under a group.
  int _maxChildDepth(GroupNode group, Scene scene) {
    int maxDepth = 0;
    for (final childId in group.childIds) {
      final child = scene.nodes[childId];
      if (child is GroupNode) {
        maxDepth =
            maxDepth > (1 + _maxChildDepth(child, scene))
                ? maxDepth
                : 1 + _maxChildDepth(child, scene);
      }
    }
    return maxDepth;
  }

  // ─── Selection ────────────────────────────────────────────────────────

  /// Selects a single node (clears previous selection).
  void selectNode(String nodeId) {
    state = state.copyWith(selectedNodeIds: {nodeId});
  }

  /// Toggles a node's selection (for multi-select).
  void toggleNodeSelection(String nodeId) {
    final current = Set<String>.of(state.selectedNodeIds);
    if (current.contains(nodeId)) {
      current.remove(nodeId);
    } else {
      current.add(nodeId);
    }
    state = state.copyWith(selectedNodeIds: current);
  }

  /// Clears all selection.
  void clearSelection() {
    state = state.copyWith(selectedNodeIds: {});
  }

  // ─── Transforms ───────────────────────────────────────────────────────

  /// Updates the transform properties of a specific model node.
  void setNodeTransform(
    String nodeId, {
    double? heading,
    double? tilt,
    double? roll,
    double? scaleX,
    double? scaleY,
    double? scaleZ,
    double? altitude,
    double? latitude,
    double? longitude,
  }) {
    final scene = state.activeScene;
    if (scene == null) return;

    final node = scene.nodes[nodeId];
    if (node is! ModelNode) return;

    final updatedNodes = Map<String, SceneNode>.of(scene.nodes);
    updatedNodes[nodeId] = node.copyWith(
      heading: heading,
      tilt: tilt,
      roll: roll,
      scaleX: scaleX,
      scaleY: scaleY,
      scaleZ: scaleZ,
      altitude: altitude,
      latitude: latitude,
      longitude: longitude,
    );

    state = state.copyWith(
      activeScene: scene.copyWith(nodes: updatedNodes),
      isDirty: true,
    );
  }

  /// Moves all selected model nodes by a lat/lon delta.
  ///
  /// For groups, recursively applies the delta to all descendant ModelNodes.
  void moveSelectedBy({double dLat = 0, double dLon = 0}) {
    final scene = state.activeScene;
    if (scene == null) return;

    final updatedNodes = Map<String, SceneNode>.of(scene.nodes);
    final modelIds = _resolveSelectedModelIds(scene);

    for (final id in modelIds) {
      final node = updatedNodes[id] as ModelNode;
      updatedNodes[id] = node.copyWith(
        latitude: node.latitude + dLat,
        longitude: node.longitude + dLon,
      );
    }

    state = state.copyWith(
      activeScene: scene.copyWith(nodes: updatedNodes),
      isDirty: true,
    );
  }

  /// Rotates all selected models by a heading delta.
  void rotateSelected(double deltaHeading) {
    final scene = state.activeScene;
    if (scene == null) return;

    final updatedNodes = Map<String, SceneNode>.of(scene.nodes);
    final modelIds = _resolveSelectedModelIds(scene);

    for (final id in modelIds) {
      final node = updatedNodes[id] as ModelNode;
      updatedNodes[id] = node.copyWith(
        heading: (node.heading + deltaHeading) % 360,
      );
    }

    state = state.copyWith(
      activeScene: scene.copyWith(nodes: updatedNodes),
      isDirty: true,
    );
  }

  /// Scales all selected models by a factor.
  void scaleSelected(double factor) {
    final scene = state.activeScene;
    if (scene == null) return;

    final updatedNodes = Map<String, SceneNode>.of(scene.nodes);
    final modelIds = _resolveSelectedModelIds(scene);

    for (final id in modelIds) {
      final node = updatedNodes[id] as ModelNode;
      updatedNodes[id] = node.copyWith(
        scaleX: node.scaleX * factor,
        scaleY: node.scaleY * factor,
        scaleZ: node.scaleZ * factor,
      );
    }

    state = state.copyWith(
      activeScene: scene.copyWith(nodes: updatedNodes),
      isDirty: true,
    );
  }

  /// Resolves selected node IDs into a flat set of ModelNode IDs,
  /// expanding any selected groups into their descendant models.
  Set<String> _resolveSelectedModelIds(Scene scene) {
    final result = <String>{};
    for (final id in state.selectedNodeIds) {
      final node = scene.nodes[id];
      if (node is ModelNode) {
        result.add(id);
      } else if (node is GroupNode) {
        result.addAll(
          scene.allModelDescendants(id).map((m) => m.id),
        );
      }
    }
    return result;
  }
}

// ─── Provider ──────────────────────────────────────────────────────────────

final sceneProvider = NotifierProvider<SceneNotifier, SceneState>(
  SceneNotifier.new,
);

// ─── Curriculum Integration Hooks ──────────────────────────────────────────

class GroupCreatedNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

/// Set to `true` after a group is created in the active scene.
final groupCreatedProvider = NotifierProvider<GroupCreatedNotifier, bool>(
  GroupCreatedNotifier.new,
);

class SceneSavedNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

/// Set to `true` after the active scene is saved to disk.
final sceneSavedProvider = NotifierProvider<SceneSavedNotifier, bool>(
  SceneSavedNotifier.new,
);
