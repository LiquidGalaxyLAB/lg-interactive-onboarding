import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/data/model_project.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/data/model_repository.dart';
import 'package:lg_interactive_onboarding/src/common/constants/app_constants.dart';
import 'package:lg_interactive_onboarding/src/common/lg/lg_service.dart';
import 'package:lg_interactive_onboarding/src/common/kml/educational_balloon_kml_model.dart';
import 'package:lg_interactive_onboarding/src/common/constants/educational_content.dart';
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
    displayName: 'Tree',
    assetPath: 'assets/models/3dmodel_tri.dae',
    fileName: '3dmodel_tri.dae',
  ),
  BundledModel(
    displayName: 'Football',
    assetPath: 'assets/models/Ball DAE.dae',
    fileName: 'Ball DAE.dae',
  ),
  BundledModel(
    displayName: 'Car',
    assetPath: 'assets/models/Car.dae',
    fileName: 'Car.dae',
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
  final rand = Random().nextInt(AppConstants.idMaxRandom).toString().padLeft(AppConstants.idPaddingLength, '0');
  return '${now}_$rand';
}

// ─── Model Project State ─────────────────────────────────────────────

sealed class ImportResult {
  const ImportResult();
}

class ImportSuccess extends ImportResult {
  const ImportSuccess();
}

class ImportFailure extends ImportResult {
  final String message;
  const ImportFailure(this.message);
}

class ImportCanceled extends ImportResult {
  const ImportCanceled();
}

/// Manages the full state of the current 3D model builder project.
class ModelBuilderNotifier extends Notifier<ModelProject> {
  @override
  ModelProject build() => ModelProject.empty;

  // ─── File Import ─────────────────────────────────────────────────

  /// Opens file picker and imports a 3D model file.
  ///
  /// Returns `null` on success, or an error message on failure.
  ///
  /// Uses [FileType.any] because Android lacks MIME-type mappings for most
  /// 3D formats (.dae, .obj, .blend, etc.), causing [FileType.custom] to
  /// grey-out or silently ignore taps. Extension validation is done in Dart.
  ///
  /// On Android emulators the file_picker cache can vanish before we read it
  /// (the plugin logs "File not found" immediately after caching). We guard
  /// against this by:
  ///   1. Preferring [file.bytes] (in-memory, if available).
  ///   2. Verifying [file.path] actually exists before using it.
  ///   3. Falling back to [file.readStream] to stream directly from the
  ///      content provider.
  Future<ImportResult> importModel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
        withReadStream: true,
      );

      if (result == null || result.files.isEmpty) return const ImportCanceled();

      final file = result.files.first;
      final fileName = file.name;
      final ext = p.extension(fileName).toLowerCase();

      // Validate extension in Dart (the OS picker is unfiltered)
      if (!ModelProject.supportedExtensions.contains(ext)) {
        return ImportFailure('Unsupported format "$ext". '
            'Accepted: ${ModelProject.supportedExtensions.join(', ')}');
      }

      // Persist the file into the app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final persistentFile = File('${appDir.path}/$fileName');

      if (file.bytes != null && file.bytes!.isNotEmpty) {
        // ── Strategy 1: in-memory bytes (best case) ──
        await persistentFile.writeAsBytes(file.bytes!);
        debugPrint('Import: wrote ${file.bytes!.length} bytes from memory');
      } else if (file.path != null && await File(file.path!).exists()) {
        // ── Strategy 2: cached file still exists on disk ──
        await File(file.path!).copy(persistentFile.path);
        debugPrint('Import: copied from cached path ${file.path}');
      } else if (file.readStream != null) {
        // ── Strategy 3: stream directly from the content provider ──
        // This bypasses the vanishing-cache problem entirely.
        final chunks = <int>[];
        await for (final chunk in file.readStream!) {
          chunks.addAll(chunk);
        }
        if (chunks.isEmpty) {
          return const ImportFailure('File appears to be empty (0 bytes read from stream).');
        }
        await persistentFile.writeAsBytes(Uint8List.fromList(chunks));
        debugPrint('Import: streamed ${chunks.length} bytes from content provider');
      } else {
        return const ImportFailure('Could not read file data from device. '
            'Try copying the file to internal storage and retry.');
      }

      final fileInfo = await persistentFile.stat();

      state = state.copyWith(
        id: _generateId(),
        filePath: persistentFile.path,
        fileName: fileName,
        fileSize: fileInfo.size,
        fileExtension: ext,
        isAsset: false,
        assetPath: null,
      );

      debugPrint(
          'Model imported: ${state.fileName} (${state.fileSizeFormatted})');
      return const ImportSuccess(); // success
    } catch (e) {
      debugPrint('File import failed: $e');
      return ImportFailure('File import failed: $e');
    }
  }

  /// Loads a bundled asset model for testing. Returns null if successful, or error message.
  Future<ImportResult> loadBundledModel(BundledModel bundled) async {
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
      return const ImportSuccess();
    } catch (e) {
      debugPrint('Bundled import failed: $e');
      return ImportFailure('Failed to load bundled model: $e');
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
      scaleX: AppConstants.defaultScale,
      scaleY: AppConstants.defaultScale,
      scaleZ: AppConstants.defaultScale,
      altitude: AppConstants.defaultAltitude,
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
      // Signal curriculum engine — Module 2 auto-verify listens here
      ref.read(modelPushSuccessProvider.notifier).set(true);

      // Fly to the newly pushed model's location
      if (project.hasLocation) {
        // The 'range' parameter dictates how far the camera pulls back from the object.
        // We increase the multiplier here so the camera doesn't end up inside very large models.
        final range = (project.altitude + (project.scaleX * 15)).clamp(1000.0, 100000.0);
        
        ref.read(lgServiceProvider).flyToAndOrbit(
          latitude: project.latitude!,
          longitude: project.longitude!,
          altitude: project.altitude,
          heading: project.heading,
          // We use a fixed camera tilt for a nice bird's-eye 3D perspective.
          tilt: AppConstants.defaultCameraTilt, 
          range: range,
        );

        // Send Educational Balloon KML if applicable.
        String? key;
        final projectName = (project.fileName ?? project.assetPath ?? '').toLowerCase();
        if (projectName.contains('tree')) key = 'Tree';
        else if (projectName.contains('car')) key = 'Car';
        else if (projectName.contains('pyramid')) key = 'Pyramid';
        else if (projectName.contains('football') || projectName.contains('ball')) key = 'Football';

        if (key != null) {
          final content = EducationalConstants.modelContent[key];
          if (content != null) {
            final balloonKml = EducationalBalloonKmlModel.generateBalloonKml(
              id: key.toLowerCase(),
              title: content.title,
              description: content.description,
              iconUrl: content.iconUrl,
              latitude: project.latitude!,
              longitude: project.longitude!,
            );
            ref.read(lgServiceProvider).sendBalloonKml(balloonKml);
          }
        }
      }
    }

    state = PushState(
      status: result.success ? PushStatus.success : PushStatus.error,
      message: result.message,
    );

    // Auto-reset to idle after a delay
    await Future.delayed(AppConstants.pushStateResetDelay);
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
      ref.read(lgServiceProvider).cleanBalloonKML();
    }

    state = PushState(
      status: result.success ? PushStatus.success : PushStatus.error,
      message: result.message,
    );

    await Future.delayed(AppConstants.pushStateResetDelay);
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
      ref.read(lgServiceProvider).cleanBalloonKML();
    }

    state = PushState(
      status: result.success ? PushStatus.success : PushStatus.error,
      message: result.message,
    );

    await Future.delayed(AppConstants.pushStateResetDelay);
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

    await Future.delayed(AppConstants.pushStateResetDelay);
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

    // no logo action — logo lifecycle is managed by the SSH connection watcher
    if (result.success) {
      ref.read(deployedModelsProvider.notifier).clearAll();
      ref.read(lgServiceProvider).orbitStop();
      ref.read(lgServiceProvider).cleanBalloonKML();
    }

    state = PushState(
      status: result.success ? PushStatus.success : PushStatus.error,
      message: result.success ? 'Master KML cleared' : result.message,
    );

    await Future.delayed(AppConstants.pushStateResetDelay);
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

    // Disrupt any ongoing tours or orbits (this also calls stopTour internally)
    await ref.read(lgServiceProvider).orbitStop();

    final result = await repo.deepClean();

    if (result.success) {
      ref.read(deployedModelsProvider.notifier).clearAll();
    }

    state = PushState(
      status: result.success ? PushStatus.success : PushStatus.error,
      message: result.message,
    );

    await Future.delayed(AppConstants.pushStateResetDelay);
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

// ─── Curriculum Engine Integration Hooks ──────────────────────────────────────
// These lightweight providers expose observable state flags that the Curriculum
// Engine uses for auto-verification without coupling it to specific widgets.

class ModelPushSuccessNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

/// Set to `true` after a model push completes successfully.
///
/// The Curriculum Engine watches this to auto-verify Module 2.
/// Reset to `false` automatically 5 seconds after being set so the next
/// push attempt starts fresh.
final modelPushSuccessProvider = NotifierProvider<ModelPushSuccessNotifier, bool>(
  ModelPushSuccessNotifier.new,
);

class KmlPreviewOpenedNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

/// Set to `true` when the user expands the KML Preview panel.
///
/// The Curriculum Engine watches this to auto-verify Module 3.
/// Backed by [AnalyticsService] for persistence across restarts.
final kmlPreviewOpenedProvider = NotifierProvider<KmlPreviewOpenedNotifier, bool>(
  KmlPreviewOpenedNotifier.new,
);

class DeepCleanConfirmedNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

/// Set to `true` when the user confirms the Deep Clean dialog.
///
/// The Curriculum Engine watches this to auto-verify Module 7.
/// Backed by [AnalyticsService] for persistence across restarts.
final deepCleanConfirmedProvider = NotifierProvider<DeepCleanConfirmedNotifier, bool>(
  DeepCleanConfirmedNotifier.new,
);
