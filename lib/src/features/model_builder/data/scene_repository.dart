import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lg_interactive_onboarding/src/common/constants/app_constants.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/data/scene_models.dart';

/// Handles local file I/O for `.lgscene` files and the SharedPreferences
/// scene metadata index.
///
/// Scene files are stored as JSON at:
///   `ApplicationDocumentsDirectory/scenes/<scene_id>.lgscene`
///
/// The metadata index in SharedPreferences is a JSON-encoded list under
/// the key [_indexKey], allowing quick listing without reading every file.
class SceneRepository {
  static const _indexKey = 'scene_index';

  // ─── Scene File I/O ─────────────────────────────────────────────────────

  /// Returns the scenes directory, creating it if necessary.
  Future<Directory> _scenesDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/${AppConstants.scenesSubDir}');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Returns the full file path for a scene.
  Future<String> _sceneFilePath(String sceneId) async {
    final dir = await _scenesDir();
    return '${dir.path}/$sceneId${AppConstants.sceneFileExtension}';
  }

  /// Saves a [Scene] to disk and updates the metadata index.
  Future<void> saveScene(Scene scene) async {
    try {
      final filePath = await _sceneFilePath(scene.id);
      final jsonString = const JsonEncoder.withIndent('  ').convert(scene.toJson());
      await File(filePath).writeAsString(jsonString);

      // Update the metadata index
      await _updateIndex(SceneMetadata(
        id: scene.id,
        name: scene.name,
        lastModified: scene.modifiedAt,
        modelCount: scene.modelCount,
      ));

      debugPrint('SceneRepository: Saved scene "${scene.name}" to $filePath');
    } catch (e) {
      debugPrint('SceneRepository: Save failed: $e');
      rethrow;
    }
  }

  /// Loads a [Scene] from disk by its ID.
  ///
  /// Returns `null` if the file does not exist or is corrupt.
  Future<Scene?> loadScene(String sceneId) async {
    try {
      final filePath = await _sceneFilePath(sceneId);
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('SceneRepository: Scene file not found: $filePath');
        return null;
      }

      final jsonString = await file.readAsString();
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final scene = Scene.fromJson(json);

      debugPrint('SceneRepository: Loaded scene "${scene.name}" '
          '(${scene.modelCount} models)');
      return scene;
    } catch (e) {
      debugPrint('SceneRepository: Load failed for $sceneId: $e');
      return null;
    }
  }

  /// Deletes a scene file from disk and removes it from the metadata index.
  Future<void> deleteScene(String sceneId) async {
    try {
      final filePath = await _sceneFilePath(sceneId);
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      await _removeFromIndex(sceneId);
      debugPrint('SceneRepository: Deleted scene $sceneId');
    } catch (e) {
      debugPrint('SceneRepository: Delete failed for $sceneId: $e');
      rethrow;
    }
  }

  // ─── Metadata Index ─────────────────────────────────────────────────────

  /// Returns the list of all saved scene metadata from SharedPreferences.
  Future<List<SceneMetadata>> listScenes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final indexJson = prefs.getString(_indexKey);
      if (indexJson == null || indexJson.isEmpty) return [];

      final list = jsonDecode(indexJson) as List<dynamic>;
      return list
          .map((e) => SceneMetadata.fromJson(e as Map<String, dynamic>))
          .toList()
        // Most recently modified first
        ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
    } catch (e) {
      debugPrint('SceneRepository: Failed to list scenes: $e');
      return [];
    }
  }

  /// Adds or updates a scene's metadata in the SharedPreferences index.
  Future<void> _updateIndex(SceneMetadata meta) async {
    final prefs = await SharedPreferences.getInstance();
    final scenes = await listScenes();

    // Remove existing entry for this ID (if any), then add the new one
    scenes.removeWhere((s) => s.id == meta.id);
    scenes.insert(0, meta);

    final jsonString =
        jsonEncode(scenes.map((s) => s.toJson()).toList());
    await prefs.setString(_indexKey, jsonString);
  }

  /// Removes a scene from the SharedPreferences index.
  Future<void> _removeFromIndex(String sceneId) async {
    final prefs = await SharedPreferences.getInstance();
    final scenes = await listScenes();
    scenes.removeWhere((s) => s.id == sceneId);

    final jsonString =
        jsonEncode(scenes.map((s) => s.toJson()).toList());
    await prefs.setString(_indexKey, jsonString);
  }
}

// ─── Provider ──────────────────────────────────────────────────────────────

final sceneRepositoryProvider = Provider<SceneRepository>((ref) {
  return SceneRepository();
});
