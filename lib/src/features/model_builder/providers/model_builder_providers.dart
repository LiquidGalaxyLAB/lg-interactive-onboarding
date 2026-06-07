import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/data/model_project.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/data/model_repository.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// ─── Bundled Asset Models ──────────────────────────────────────────────

/// List of 3D model assets bundled with the app for quick testing.
class BundledModel {
  final String displayName;
  final String assetPath;
  final String fileName;

  const BundledModel({
    required this.displayName,
    required this.assetPath,
    required this.fileName,
  });
}

const bundledModels = [
  BundledModel(
    displayName: '3D Model (Triangulated)',
    assetPath: 'assets/models/3dmodel_tri.dae',
    fileName: '3dmodel_tri.dae',
  ),
  BundledModel(
    displayName: 'Car (Triangulated)',
    assetPath: 'assets/models/car_tri.dae',
    fileName: 'car_tri.dae',
  ),
  BundledModel(
    displayName: 'Pyramid',
    assetPath: 'assets/models/model_pyramid.dae',
    fileName: 'model_pyramid.dae',
  ),
];

// ─── ID Generator ──────────────────────────────────────────────────────

String _generateId() {
  final now = DateTime.now().millisecondsSinceEpoch;
  final rand = Random().nextInt(9999).toString().padLeft(4, '0');
  return '${now}_$rand';
}

// ─── Model Project State ─────────────────────────────────────────────

/// Manages the full state of the current 3D model builder project.
class ModelBuilderNotifier extends Notifier<ModelProject> {
  @override
  ModelProject build() => ModelProject.empty;

  // ─── File Import ─────────────────────────────────────────────────

  /// Opens file picker and imports a 3D model file.
  Future<bool> importModel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['dae', 'gltf', 'glb', 'kmz'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return false;

      final file = result.files.first;
      final filePath = file.path;
      if (filePath == null) return false;

      // Copy picked file to application documents directory to prevent OS cache pruning
      final appDir = await getApplicationDocumentsDirectory();
      final persistentFile = File('${appDir.path}/${p.basename(filePath)}');
      await File(filePath).copy(persistentFile.path);

      final fileInfo = await persistentFile.stat();
      final ext = p.extension(filePath).toLowerCase();

      state = state.copyWith(
        id: _generateId(),
        filePath: persistentFile.path,
        fileName: p.basename(filePath),
        fileSize: fileInfo.size,
        fileExtension: ext,
        isAsset: false,
        assetPath: null,
      );

      debugPrint(
          'Model imported: ${state.fileName} (${state.fileSizeFormatted})');
      return true;
    } catch (e) {
      debugPrint('File import failed: $e');
      return false;
    }
  }

  /// Loads a bundled asset model for testing. Returns null if successful, or error message.
  Future<String?> loadBundledModel(BundledModel bundled) async {
    try {
      // Copy asset to app documents directory so it can be read as a File and doesn't get pruned
      final byteData = await rootBundle.load(bundled.assetPath);
      final appDir = await getApplicationDocumentsDirectory();
      final localFile = File('${appDir.path}/${bundled.fileName}');
      
      // Safe conversion from ByteData to Uint8List
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      await localFile.writeAsBytes(bytes);

      final fileInfo = await localFile.stat();
      final ext = p.extension(bundled.fileName).toLowerCase();

      state = state.copyWith(
        id: _generateId(),
        filePath: localFile.path,
        fileName: bundled.fileName,
        fileSize: fileInfo.size,
        fileExtension: ext,
        isAsset: true,
        assetPath: bundled.assetPath,
      );

      debugPrint('Bundled model loaded: ${bundled.displayName}');
      return null;
    } catch (e) {
      debugPrint('Bundled model load failed: $e');
      return e.toString();
    }
  }

  // ─── Map Placement ──────────────────────────────────────────────

  /// Places the model at the given coordinates.
  void placeModel(double latitude, double longitude) {
    state = state.copyWith(
      latitude: latitude,
      longitude: longitude,
    );
  }

  // ─── Orientation Controls ───────────────────────────────────────

  void setHeading(double value) => state = state.copyWith(heading: value);
  void setTilt(double value) => state = state.copyWith(tilt: value);
  void setRoll(double value) => state = state.copyWith(roll: value);

  // ─── Scale Controls ─────────────────────────────────────────────

  void setScaleX(double value) => state = state.copyWith(scaleX: value);
  void setScaleY(double value) => state = state.copyWith(scaleY: value);
  void setScaleZ(double value) => state = state.copyWith(scaleZ: value);

  /// Sets uniform scale on all axes.
  void setUniformScale(double value) {
    state = state.copyWith(
      scaleX: value,
      scaleY: value,
      scaleZ: value,
    );
  }

  // ─── Altitude ───────────────────────────────────────────────────

  void setAltitude(double value) => state = state.copyWith(altitude: value);

  // ─── Reset ──────────────────────────────────────────────────────

  /// Resets all state to defaults.
  void reset() {
    state = ModelProject.empty;
  }

  /// Resets only orientation and scale to defaults.
  void resetAdjustments() {
    state = state.copyWith(
      heading: 0.0,
      tilt: 0.0,
      roll: 0.0,
      scaleX: 100.0,
      scaleY: 100.0,
      scaleZ: 100.0,
      altitude: 10.0,
    );
  }

  /// Regenerates the project unique ID so next modifications deploy as a new model.
  void regenerateId() {
    state = state.copyWith(id: _generateId());
  }
}

final modelBuilderProvider =
    NotifierProvider<ModelBuilderNotifier, ModelProject>(
  ModelBuilderNotifier.new,
);

// ─── Deployed Models Registry ──────────────────────────────────────────

/// Tracks all models currently deployed on the LG rig.
/// Allows individual removal without affecting other deployments.
class DeployedModelsNotifier extends Notifier<List<DeployedModel>> {
  @override
  List<DeployedModel> build() => [];

  /// Records a newly pushed model.
  void addDeployment(ModelProject project) {
    state = [
      ...state,
      DeployedModel(
        id: project.id,
        displayName: project.fileName ?? 'Unknown',
        remoteModelFileName: project.remoteModelFileName,
        remoteKmlFileName: project.remoteKmlFileName,
        latitude: project.latitude!,
        longitude: project.longitude!,
        deployedAt: DateTime.now(),
      ),
    ];
  }

  /// Removes a deployment record (after it's been deleted from LG).
  void removeDeployment(String id) {
    state = state.where((d) => d.id != id).toList();
  }

  /// Clears all deployment records.
  void clearAll() {
    state = [];
  }
}

final deployedModelsProvider =
    NotifierProvider<DeployedModelsNotifier, List<DeployedModel>>(
  DeployedModelsNotifier.new,
);

// ─── KML Preview ───────────────────────────────────────────────────────

/// Derived provider: generates KML string from the current project state.
final kmlPreviewProvider = Provider<String>((ref) {
  final project = ref.watch(modelBuilderProvider);
  final repo = ref.read(modelRepositoryProvider);
  return repo.generateKml(project);
});

/// Derived provider: generates only the Model block.
final kmlModelBlockProvider = Provider<String>((ref) {
  final project = ref.watch(modelBuilderProvider);
  final repo = ref.read(modelRepositoryProvider);
  return repo.generateModelBlock(project);
});

// ─── Push State ────────────────────────────────────────────────────────

/// Tracks the state of a push operation.
enum PushStatus { idle, pushing, success, error }

class PushState {
  final PushStatus status;
  final String? message;

  const PushState({this.status = PushStatus.idle, this.message});
}

class PushNotifier extends Notifier<PushState> {
  @override
  PushState build() => const PushState();

  Future<void> push({bool relaunch = true}) async {
    final project = ref.read(modelBuilderProvider);
    final repo = ref.read(modelRepositoryProvider);
    final deployed = ref.read(deployedModelsProvider);

    state =
        const PushState(status: PushStatus.pushing, message: 'Uploading...');

    final result = await repo.pushToLG(
      project,
      existingDeployments: deployed,
      relaunch: relaunch,
    );

    if (result.success) {
      // Register in the deployed models registry
      ref.read(deployedModelsProvider.notifier).addDeployment(project);
      // Regenerate ID for current state so next adjustments/pushes deploy as a new model
      ref.read(modelBuilderProvider.notifier).regenerateId();
    }

    state = PushState(
      status: result.success ? PushStatus.success : PushStatus.error,
      message: result.message,
    );

    // Auto-reset to idle after a delay
    await Future.delayed(const Duration(seconds: 3));
    if (state.status != PushStatus.pushing) {
      state = const PushState();
    }
  }

  /// Removes a single deployed model from the LG rig.
  Future<void> removeModel(DeployedModel model) async {
    final repo = ref.read(modelRepositoryProvider);
    final deployed = ref.read(deployedModelsProvider);
    final remaining = deployed.where((d) => d.id != model.id).toList();

    state = PushState(
      status: PushStatus.pushing,
      message: 'Removing ${model.displayName}...',
    );

    final result = await repo.removeFromLG(
      model,
      remainingDeployments: remaining,
    );

    if (result.success) {
      ref.read(deployedModelsProvider.notifier).removeDeployment(model.id);
    }

    state = PushState(
      status: result.success ? PushStatus.success : PushStatus.error,
      message: result.message,
    );

    await Future.delayed(const Duration(seconds: 3));
    if (state.status != PushStatus.pushing) {
      state = const PushState();
    }
  }

  /// Removes all deployed models from the LG rig.
  Future<void> removeAll() async {
    final repo = ref.read(modelRepositoryProvider);
    final deployed = ref.read(deployedModelsProvider);

    if (deployed.isEmpty) return;

    state = const PushState(
      status: PushStatus.pushing,
      message: 'Removing all models...',
    );

    final result = await repo.removeAllFromLG(deployed);

    if (result.success) {
      ref.read(deployedModelsProvider.notifier).clearAll();
    }

    state = PushState(
      status: result.success ? PushStatus.success : PushStatus.error,
      message: result.message,
    );

    await Future.delayed(const Duration(seconds: 3));
    if (state.status != PushStatus.pushing) {
      state = const PushState();
    }
  }

  /// Wipes all remote model and KML files from the LG rig and clears the local registry.
  Future<void> wipeLgRig() async {
    final repo = ref.read(modelRepositoryProvider);

    state = const PushState(
      status: PushStatus.pushing,
      message: 'Wiping LG rig files...',
    );

    final result = await repo.removeAllFromLG([]);

    if (result.success) {
      ref.read(deployedModelsProvider.notifier).clearAll();
    }

    state = PushState(
      status: result.success ? PushStatus.success : PushStatus.error,
      message: result.success ? 'LG rig wiped successfully' : result.message,
    );

    await Future.delayed(const Duration(seconds: 3));
    if (state.status != PushStatus.pushing) {
      state = const PushState();
    }
  }

  /// Clears only the active master KML display without deleting the files from directory.
  Future<void> clearMasterKml() async {
    final repo = ref.read(modelRepositoryProvider);

    state = const PushState(
      status: PushStatus.pushing,
      message: 'Clearing master KML...',
    );

    final result = await repo.writeEmptyMasterKml();

    state = PushState(
      status: result.success ? PushStatus.success : PushStatus.error,
      message: result.success ? 'Master KML cleared' : result.message,
    );

    await Future.delayed(const Duration(seconds: 3));
    if (state.status != PushStatus.pushing) {
      state = const PushState();
    }
  }

  /// Deep cleans all 3D model content from the LG rig.
  /// Removes everything from /model and /3d_model_wrapper, clears master KML.
  Future<void> deepClean() async {
    final repo = ref.read(modelRepositoryProvider);

    state = const PushState(
      status: PushStatus.pushing,
      message: 'Deep cleaning LG rig...',
    );

    final result = await repo.deepClean();

    if (result.success) {
      ref.read(deployedModelsProvider.notifier).clearAll();
    }

    state = PushState(
      status: result.success ? PushStatus.success : PushStatus.error,
      message: result.message,
    );

    await Future.delayed(const Duration(seconds: 3));
    if (state.status != PushStatus.pushing) {
      state = const PushState();
    }
  }
}

final pushProvider = NotifierProvider<PushNotifier, PushState>(
  PushNotifier.new,
);

// ─── Vertex Count (async) ──────────────────────────────────────────────

/// Asynchronously extracts vertex count for DAE files.
final vertexCountProvider = FutureProvider<int?>((ref) async {
  final project = ref.watch(modelBuilderProvider);
  if (project.fileExtension?.toLowerCase() != '.dae' ||
      project.filePath == null) {
    return null;
  }

  final repo = ref.read(modelRepositoryProvider);
  return repo.extractDaeVertexCount(project.filePath!);
});
