import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/data/model_project.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/data/model_repository.dart';
import 'package:lg_interactive_onboarding/src/common/constants/app_constants.dart';
import 'package:lg_interactive_onboarding/src/common/lg/lg_service.dart';
import 'package:lg_interactive_onboarding/src/common/kml/educational_balloon_kml_model.dart';
import 'package:lg_interactive_onboarding/src/common/constants/educational_content.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';

// ─── Local Model Validation ──────────────────────────────────────────────

/// Runs in an Isolate to parse a DAE file and ensure no mesh has > 65535 vertices.
/// This guarantees Google Earth compatibility before uploading.
Future<bool> _validateDaeVertices(String filePath) async {
  return await compute(_checkDaeVerticesInIsolate, filePath);
}

class MissingDaeException implements Exception {
  final String message;
  const MissingDaeException(this.message);
  @override
  String toString() => message;
}

bool _checkDaeVerticesInIsolate(String filePath) {
  try {
    final file = File(filePath);
    final ext = p.extension(filePath).toLowerCase();

    List<String> xmlContents = [];

    if (ext == '.zip') {
      final bytes = file.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final archiveFile in archive) {
        if (archiveFile.isFile && archiveFile.name.toLowerCase().endsWith('.dae')) {
          final data = archiveFile.content as List<int>;
          xmlContents.add(String.fromCharCodes(data));
        }
      }
      
      // If no DAE was found in the zip, fail early
      if (xmlContents.isEmpty) {
        throw const MissingDaeException('No .dae file found inside the ZIP archive.');
      }
    } else {
      xmlContents.add(file.readAsStringSync());
    }

    final regex = RegExp(r'<float_array[^>]*count="([0-9]+)"');
    for (final content in xmlContents) {
      final matches = regex.allMatches(content);
      for (final match in matches) {
        final countStr = match.group(1);
        if (countStr != null) {
          final count = int.tryParse(countStr) ?? 0;
          // 65535 vertices max. Each vertex is X, Y, Z (3 floats).
          if (count > 65535 * 3) {
            return false;
          }
        }
      }
    }
    return true; // Valid
  } on MissingDaeException {
    rethrow; // Pass this specific error up to show the user
  } catch (e) {
    // If it fails to parse (e.g. malformed), we let it pass here and fail on the Python script.
    return true; 
  }
}

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
        withReadStream: true,
      );

      if (result == null || result.files.isEmpty) return const ImportCanceled();

      state = state.copyWith(isImporting: true);

      final file = result.files.first;
      final fileName = file.name;
      final ext = p.extension(fileName).toLowerCase();

      // Validate extension in Dart (the OS picker is unfiltered)
      if (!ModelProject.supportedExtensions.contains(ext)) {
        state = state.copyWith(isImporting: false);
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
          state = state.copyWith(isImporting: false);
          return const ImportFailure('File appears to be empty (0 bytes read from stream).');
        }
        await persistentFile.writeAsBytes(Uint8List.fromList(chunks));
        debugPrint('Import: streamed ${chunks.length} bytes from content provider');
      } else {
        debugPrint('Import: Failed to obtain file bytes (all strategies exhausted).');
        state = state.copyWith(isImporting: false);
        return const ImportFailure('Failed to load file contents.');
      }

      // ── Local Validation ──
      if (ext == '.dae' || ext == '.zip') {
        final isValid = await _validateDaeVertices(persistentFile.path);
        if (!isValid) {
          await persistentFile.delete();
          state = state.copyWith(isImporting: false);
          return ImportFailure(
            'This model is too complex for Google Earth. Please decimate it in Blender to under 64,000 vertices per mesh and try again.'
          );
        }
      }

      final modelSize = await persistentFile.length();

      state = state.copyWith(
        id: _generateId(),
        filePath: persistentFile.path,
        fileName: fileName,
        fileSize: modelSize,
        fileExtension: ext,
        isAsset: false,
        assetPath: null,
        isImporting: false,
      );

      debugPrint(
          'Model imported: ${state.fileName} (${state.fileSizeFormatted})');
      return const ImportSuccess(); // success
    } catch (e) {
      debugPrint('File import failed: $e');
      state = state.copyWith(isImporting: false);
      return ImportFailure('File import failed: $e');
    }
  }

  /// Loads a bundled asset model for testing. Returns null if successful, or error message.
  Future<ImportResult> loadBundledModel(BundledModel bundled) async {
    try {
      state = state.copyWith(isImporting: true);

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
        isImporting: false,
      );

      debugPrint('Bundled model loaded: ${bundled.displayName}');
      return const ImportSuccess();
    } catch (e) {
      debugPrint('Load bundled asset failed: $e');
      state = state.copyWith(isImporting: false);
      return ImportFailure('Failed to load bundled asset: $e');
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
    final range = (project.altitude + (project.scaleX * 150)).clamp(2000.0, 250000.0);
    state = [
      ...state,
      DeployedModel(
        id: project.id,
        displayName: project.fileName ?? 'Unknown',
        remoteModelFileName: project.remoteModelFileName,
        remoteKmlFileName: project.remoteKmlFileName,
        latitude: project.latitude!,
        longitude: project.longitude!,
        altitude: project.altitude,
        range: range,
        tilt: AppConstants.defaultCameraTilt,
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
    if (state.status == PushStatus.pushing) return;
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
        // We adjust the multiplier here so the camera doesn't end up inside huge models.
        final range = (project.altitude + (project.scaleX * 250)).clamp(400.0, 300000.0);
        
        ref.read(lgServiceProvider).flyTo(
          latitude: project.latitude!,
          longitude: project.longitude!,
          altitude: project.altitude,
          heading: project.heading,
          // We use a fixed camera tilt (slightly more top-down) to ensure tall models fit
          tilt: 50.0, 
          range: range,
        );

        // Send Educational Balloon KML if applicable.
        String? key;
        final projectName = (project.fileName ?? project.assetPath ?? '').toLowerCase();
        if (projectName.contains('tree')) {
          key = 'Tree';
        } else if (projectName.contains('car')) {
          key = 'Car';
        } else if (projectName.contains('pyramid')) {
          key = 'Pyramid';
        } else if (projectName.contains('football') || projectName.contains('ball')) {
          key = 'Football';
        }

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
        } else if (!project.isAsset) {
          // Provide a custom educational balloon for user-imported models.
          final balloonKml = EducationalBalloonKmlModel.generateBalloonKml(
            id: 'custom_dae',
            title: '3D COLLADA DAE Model',
            description: 'COLLADA (COLLAborative Design Activity) is an XML-based file format (.dae) used to exchange digital assets among various graphics software. Liquid Galaxy uses the DAE format natively within Google Earth. This custom imported model was dynamically converted, optimized, and pushed to the rig in real-time, allowing users to visualize personalized 3D architectures and objects across the immersive panoramic screens.',
            iconUrl: 'http://lg1:81/kml_icons/custom_model.png',
            latitude: project.latitude!,
            longitude: project.longitude!,
          );
          ref.read(lgServiceProvider).sendBalloonKml(balloonKml);
        }
      }
    }

    // Delay success status if pushing was successful to let Google Earth finish the physical 
    // flyTo animation. Otherwise, clicking "Start Orbit" instantly will abort the camera flight.
    if (result.success) {
      await Future.delayed(AppConstants.lgFlyToDuration);
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
    if (state.status == PushStatus.pushing) return;
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
      ref.read(lgServiceProvider).orbitStop();
      ref.read(orbitingModelIdProvider.notifier).setOrbiting(null);
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
    if (state.status == PushStatus.pushing) return;
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
      ref.read(lgServiceProvider).orbitStop();
      ref.read(orbitingModelIdProvider.notifier).setOrbiting(null);
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
    if (state.status == PushStatus.pushing) return;
    final repo = ref.read(modelRepositoryProvider);

    state = const PushState(
      status: PushStatus.pushing,
      message: 'Wiping LG rig files...',
    );

    final result = await repo.removeAllFromLG([]);

    ref.read(lgServiceProvider).orbitStop();
    ref.read(orbitingModelIdProvider.notifier).setOrbiting(null);

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

  /// Clears the active master KML display and removes files from the directory.
  Future<void> clearMasterKml() async {
    if (state.status == PushStatus.pushing) return;
    final repo = ref.read(modelRepositoryProvider);
    final deployed = ref.read(deployedModelsProvider);

    state = const PushState(
      status: PushStatus.pushing,
      message: 'Clearing master KML...',
    );

    ref.read(lgServiceProvider).orbitStop();
    ref.read(orbitingModelIdProvider.notifier).setOrbiting(null);
    ref.read(lgServiceProvider).cleanBalloonKML();

    final result = await repo.removeAllFromLG(deployed);

    // no logo action — logo lifecycle is managed by the SSH connection watcher
    if (result.success) {
      ref.read(deployedModelsProvider.notifier).clearAll();
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
    if (state.status == PushStatus.pushing) return;
    final repo = ref.read(modelRepositoryProvider);

    state = const PushState(
      status: PushStatus.pushing,
      message: 'Deep cleaning LG rig...',
    );

    // Disrupt any ongoing tours or orbits (this also calls stopTour internally)
    await ref.read(lgServiceProvider).orbitStop();
    ref.read(orbitingModelIdProvider.notifier).setOrbiting(null);

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

/// Tracks the ID of the model currently being orbited, if any.
class OrbitingModelNotifier extends Notifier<String?> {
  Timer? _timer;
  
  @override
  String? build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
    return null;
  }

  void setOrbiting(String? modelId) {
    state = modelId;
    _timer?.cancel();
    
    if (modelId != null) {
      // The tour generates 20 orbits at ~43.2 seconds each (approx 864 seconds total).
      // We automatically reset the UI state back to "Start Orbit" when the tour naturally finishes.
      _timer = Timer(const Duration(seconds: 864), () {
        if (state == modelId) {
          state = null;
        }
      });
    }
  }
}

final orbitingModelIdProvider = NotifierProvider<OrbitingModelNotifier, String?>(
  OrbitingModelNotifier.new,
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
