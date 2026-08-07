import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/common/kml/orbit_generator.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/data/model_project.dart';
import 'package:lg_interactive_onboarding/src/features/settings/data/settings_service.dart';
import 'package:lg_interactive_onboarding/src/common/constants/app_constants.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/system_kml_service.dart';

/// Repository for 3D model operations: KML generation, file handling, SSH push.
///
/// Each deployed model uses ID-prefixed filenames so multiple models can
/// coexist on the LG rig and be removed individually.
///
/// Directory layout on LG master:
///   /var/www/html/model/              — DAE/model files
///   /var/www/html/3d_model_wrapper/   — individual model KMLs + wrapper master.kml
///   /var/www/html/kml/master.kml      — system master with NetworkLink to wrapper
class ModelRepository {
  final SSHService _sshService;
  final SettingsService _settingsService;
  final SystemKmlService _systemKmlService;

  ModelRepository(this._sshService, this._settingsService, this._systemKmlService);

  /// Session-level cache: avoids re-checking lxml on every push.
  /// (Python dependency for triangulation script).
  bool _lxmlVerified = false;

  // ─── Constants ───────────────────────────────────────────────────
  static const _modelDir = AppConstants.lgModelDir;
  static const _wrapperDir = AppConstants.lgWrapperDir;
  static const _wrapperMasterKml = AppConstants.lgWrapperMasterKml;

  /// Small delay between SSH channel operations to avoid channel exhaustion.
  Future<void> _channelDelay() => Future.delayed(AppConstants.sshChannelDelay);

  /// Executes an SSH command, optionally with sudo, and applies the channel delay.
  /// Returns the trimmed output string.
  Future<String> _execute(String command, {bool sudo = false}) async {
    final String finalCommand;
    if (sudo) {
      final password = _settingsService.password;
      finalCommand = '(echo $password; sleep 1) | sudo -S $command';
    } else {
      finalCommand = command;
    }
    
    final result = await _sshService.execute(finalCommand);
    return switch (result) {
      SSHExecSuccess(:final stdout) => stdout.trim(),
      SSHExecFailure(:final message) => throw Exception('Execution failed ($command): $message'),
    };
  }

  // ─── KML Generation ──────────────────────────────────────────────

  /// Generates a complete KML document for the given model project.
  String generateKml(ModelProject project) {
    final remoteModelFile = project.remoteModelFileName;
    
    // For zip files, the path is the extracted folder (which is remoteModelFileName without .zip)
    // plus the internal DAE path returned by the python script.
    final hrefPath = project.fileExtension == '.zip' && project.internalDaePath != null
        ? '${remoteModelFile.replaceAll('.zip', '')}/${project.internalDaePath}'
        : remoteModelFile;

    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"
     xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>3D Model: ${project.fileName}</name>
    <Placemark>
      <name>${project.fileName}</name>
      <Model>
        <Link>
          <href>http://lg1:${AppConstants.lgHttpPort}/model/$hrefPath</href>
          <href>http://lg1:${AppConstants.lgHttpPort}/model/$hrefPath</href>
        </Link>
        <Location>
          <latitude>${project.latitude ?? 0.0}</latitude>
          <longitude>${project.longitude ?? 0.0}</longitude>
          <altitude>${project.altitude}</altitude>
        </Location>
        <altitudeMode>relativeToGround</altitudeMode>
        <Orientation>
          <heading>${project.heading}</heading>
          <tilt>${project.tilt}</tilt>
          <roll>${project.roll}</roll>
        </Orientation>
        <Scale>
          <x>1.0</x>
          <y>1.0</y>
          <z>1.0</z>
        </Scale>
      </Model>
    </Placemark>
${_generateOrbitTour(project)}
  </Document>
</kml>''';
  }

  /// Generates a perfectly smooth KML Tour for orbiting this specific model.
  String _generateOrbitTour(ModelProject project) {
    if (!project.hasLocation) return '';

    final lat = project.latitude!;
    final lng = project.longitude!;
    final alt = project.altitude;
    // Increase the multiplier to push the camera back for tall models
    // clamp it higher so that models don't easily clip out of the narrow LG master screen FOV.
    final range = (alt + (project.scaleX * 250)).clamp(400.0, 300000.0);
    // Use a slightly lower tilt angle (more top-down) to keep tall models vertically centered in frame
    final tilt = 50.0;
    final String tourName = 'Orbit_${project.id}';

    return OrbitGenerator.generateOrbitTour(
      tourName: tourName,
      lat: lat,
      lng: lng,
      alt: alt,
      range: range,
      tilt: tilt,
    );
  }

  /// Generates just the Model block (for KML preview).
  String generateModelBlock(ModelProject project) {
    final remoteModelFile = project.remoteModelFileName;

    return '''<Model>
  <Link>
    <href>http://lg1:${AppConstants.lgHttpPort}/model/$remoteModelFile</href>
    <href>http://lg1:${AppConstants.lgHttpPort}/model/$remoteModelFile</href>
  </Link>
  <Location>
    <latitude>${project.latitude ?? 0.0}</latitude>
    <longitude>${project.longitude ?? 0.0}</longitude>
    <altitude>${project.altitude}</altitude>
  </Location>
  <altitudeMode>relativeToGround</altitudeMode>
  <Orientation>
    <heading>${project.heading}</heading>
    <tilt>${project.tilt}</tilt>
    <roll>${project.roll}</roll>
  </Orientation>
  <Scale>
    <x>1.0</x>
    <y>1.0</y>
    <z>1.0</z>
  </Scale>
</Model>''';
  }

  // ─── Python-Based DAE Triangulation ─────────────────────────────

  /// Ensures `lxml` (Python XML library) is installed on the LG master node.
  ///
  /// Checked once per session via [_lxmlVerified].
  Future<void> _ensureLxmlInstalled() async {
    if (_lxmlVerified) return;
    if (!_sshService.isConnected) throw Exception('SSH not connected.');

    try {
      // Quick import check
      final checkOutput = await _execute('python3 -c "import lxml" 2>&1');

      if (!checkOutput.contains('ModuleNotFoundError') &&
          !checkOutput.contains('No module named')) {
        debugPrint('Triangulate: lxml already installed');
        _lxmlVerified = true;
        return;
      }

      // Install lxml via pip
      debugPrint('Triangulate: lxml not found — installing...');
      final installOutput = await _execute('pip3 install lxml 2>&1', sudo: true);
      debugPrint('Triangulate: pip3 install lxml output: $installOutput');

      // Verify
      final verifyOutput = await _execute('python3 -c "import lxml" 2>&1');

      if (!verifyOutput.contains('ModuleNotFoundError') &&
          !verifyOutput.contains('No module named')) {
        debugPrint('Triangulate: lxml installed successfully');
        _lxmlVerified = true;
        return;
      }

      throw Exception('lxml installation failed. pip3 output: $installOutput');
    } catch (e) {
      throw Exception('lxml check failed: $e');
    }
  }

  /// Triangulates a remote .dae file in-place using the bundled Python script.
  ///
  /// The script converts all `<polylist>` and `<polygons>` primitives to
  /// `<triangles>`, which is the only primitive type Google Earth / Liquid
  /// Galaxy can render. Assimp's `-tri` flag doesn't do this — it
  /// triangulates the mesh but still exports `<polylist>` elements.
  ///
  /// Steps:
  ///   1. Upload `dae_triangulate.py` to `/tmp/` on the LG master.
  ///   2. Ensure `lxml` (Python dependency) is installed.
  ///   3. Run the script: input → temp output.
  ///   4. Overwrite the original with the triangulated result.
  Future<String?> _triangulateDaeWithScript(String remoteModelPath, double sx, double sy, double sz, {bool isZip = false}) async {
    if (!_sshService.isConnected) throw Exception('SSH not connected.');
    final triangulatedTempPath = '${remoteModelPath}_tri_tmp.dae';
    final extractDir = remoteModelPath.replaceAll('.zip', '');
    const remoteScriptPath = AppConstants.lgRemoteScriptPath;

    String? internalDaePath;

    try {
      debugPrint('Triangulate: Processing $remoteModelPath... (isZip: $isZip)');

      // 1. Upload the Python script from bundled assets
      final scriptContent = await rootBundle.loadString(
        'assets/scripts/dae_triangulate.py',
      );
      await _sshService.uploadFile(
        localData: scriptContent,
        remotePath: remoteScriptPath,
      );
      await _channelDelay();

      // 2. Ensure lxml is available
      await _ensureLxmlInstalled();

      // 3. Run the triangulation script with scaling
      final cmd = isZip 
          ? 'python3 $remoteScriptPath "$remoteModelPath" "$extractDir" --is-zip --scale-x $sx --scale-y $sy --scale-z $sz 2>&1'
          : 'python3 $remoteScriptPath "$remoteModelPath" "$triangulatedTempPath" --scale-x $sx --scale-y $sy --scale-z $sz 2>&1';
          
      final triOutput = await _execute(cmd);
      debugPrint('Triangulate: script output: $triOutput');

      if (isZip) {
          final lines = triOutput.split('\n');
          for (final line in lines) {
              if (line.startsWith('LG_DAE_PATH=')) {
                  internalDaePath = line.substring('LG_DAE_PATH='.length).trim();
              }
          }
          if (internalDaePath == null) {
              throw Exception('Could not extract LG_DAE_PATH from zip script output: $triOutput');
          }
          // Remove the original raw zip now that it's extracted
          await _execute('rm -f "$remoteModelPath"');
          // Update permissions for the extracted directory
          await _execute('chmod -R 755 "$extractDir"');
      } else {
          // 4. Verify the triangulated file was created
          final verifyOutput = await _execute('test -f "$triangulatedTempPath" && echo EXISTS');

          if (!verifyOutput.contains('EXISTS')) {
            throw Exception('Output file not created. Script output: $triOutput');
          }

          // 5. Overwrite the original .dae with the triangulated version
          await _execute('mv -f "$triangulatedTempPath" "$remoteModelPath"');
          debugPrint('Triangulate: Success — $remoteModelPath overwritten with triangulated version');
      }
      return internalDaePath;
    } catch (e) {
      // Cleanup temp file on failure
      if (isZip) {
         await _execute('rm -rf "$extractDir"').catchError((_) => '');
      } else {
         await _execute('rm -f "$triangulatedTempPath"').catchError((_) => '');
      }
      throw Exception('Triangulate failed: $e');
    }
  }

  // ─── SSH Push ────────────────────────────────────────────────────

  Future<PushResult> pushToLG(
    ModelProject project, {
    required List<DeployedModel> existingDeployments,
    bool relaunch = true,
  }) async {
    if (!_sshService.isConnected) {
      return PushResult(success: false, message: 'SSH not connected. Please connect first.');
    }
    if (!project.isReady) {
      return PushResult(success: false, message: 'Model or location not set.');
    }
    try {
      // 1. Ensure directories exist (single command)
      await _execute('mkdir -p $_modelDir && mkdir -p $_wrapperDir && mkdir -p /var/www/html/kml');

      // 2. Upload and process model file
      final fileBytes = await File(project.filePath!).readAsBytes();

      // The final path on the server (what KML will reference)
      final remoteModelPath = '$_modelDir/${project.remoteModelFileName}';

      // Upload directly to the final path
      await _sshService.uploadBytes(bytes: fileBytes, remotePath: remoteModelPath);
      await _channelDelay();

      // 3. Triangulate the model in-place using Python script
      String? internalDaePath;
      try {
        final isZip = project.fileExtension == '.zip';
        internalDaePath = await _triangulateDaeWithScript(remoteModelPath, project.scaleX, project.scaleY, project.scaleZ, isZip: isZip);
      } catch (e) {
        return PushResult(
          success: false,
          message: 'Model processing failed: $e',
        );
      }
      await _channelDelay();
      
      // Update the model project with the internal dae path so the KML points to it
      final projectForKml = project.copyWith(internalDaePath: internalDaePath);

      // 5. Generate and upload this model's KML to wrapper directory
      final kml = generateKml(projectForKml);
      await _sshService.uploadFile(
        localData: kml,
        remotePath: '$_wrapperDir/${project.remoteKmlFileName}',
      );
      await _channelDelay();

      // Set proper permissions for the web server to read the model and KML
      await _execute('chmod 644 "$_wrapperDir/${project.remoteKmlFileName}"');
      if (project.fileExtension != '.zip') {
        await _execute('chmod 644 "$_modelDir/${project.remoteModelFileName}"');
      }

      // 6. Build wrapper master.kml with NetworkLinks for ALL deployed models
      final allKmlFiles = <String>[
        ...existingDeployments.map((d) => d.remoteKmlFileName),
        project.remoteKmlFileName,
      ];
      await _writeWrapperMasterKml(allKmlFiles);
      await _channelDelay();

      // 7. System master KML is handled by SystemKmlService

      // 8. Force refresh
      await _forceRefresh();

      // 9. Relaunch if requested
      if (relaunch) {
        await _channelDelay();
        await _execute('/usr/local/bin/lg-relaunch', sudo: true);
      }

      return PushResult(success: true, message: 'Model and KML pushed successfully!');
    } catch (e) {
      debugPrint('Push to LG failed: $e');
      return PushResult(success: false, message: 'Push failed: $e');
    }
  }

  // ─── Remove a Single Deployed Model ──────────────────────────────

  Future<PushResult> removeFromLG(
    DeployedModel model, {
    required List<DeployedModel> remainingDeployments,
  }) async {
    if (!_sshService.isConnected) {
      return PushResult(success: false, message: 'SSH not connected. Please connect first.');
    }

    try {
      // 1. Rewrite wrapper master.kml with only the remaining models FIRST
      // This prevents Google Earth from trying to fetch a deleted model and throwing a 404 error
      // 1. Rewrite wrapper master.kml with only the remaining models FIRST
      // This prevents Google Earth from trying to fetch a deleted model and throwing a 404 error
      final remainingKmlFiles =
          remainingDeployments.map((d) => d.remoteKmlFileName).toList();

      if (remainingKmlFiles.isEmpty) {
        await _writeEmptyWrapperMasterKml();
      } else {
        await _writeWrapperMasterKml(remainingKmlFiles);
      }
      await _channelDelay();

      // 3. System master is handled by SystemKmlService

      // 4. Force refresh to unload the model in Google Earth
      // 4. Force refresh to unload the model in Google Earth
      await _forceRefresh();
      
      // Wait a moment for Google Earth to process the refresh before deleting files
      await Future.delayed(const Duration(seconds: 2));

      // 5. Now it is safe to remove the model file, its extracted folder (if zip), AND its KML file
      await _execute(
        'rm -f $_modelDir/${model.remoteModelFileName} && '
        'rm -rf $_modelDir/${model.remoteModelFileName.replaceAll(".zip", "")} && '
        'rm -f $_wrapperDir/${model.remoteKmlFileName}',
      );

      return PushResult(success: true, message: '${model.displayName} removed from LG.');
    } catch (e) {
      debugPrint('Remove from LG failed: $e');
      return PushResult(success: false, message: 'Remove failed: $e');
    }
  }

  // ─── Remove ALL Deployed Models ──────────────────────────────────

  Future<PushResult> removeAllFromLG(List<DeployedModel> models) async {
    if (!_sshService.isConnected) {
      return PushResult(success: false, message: 'SSH not connected.');
    }

    try {
      await _writeEmptyWrapperMasterKml();
      await _channelDelay();

      await _forceRefresh();
      
      await Future.delayed(const Duration(seconds: 2));
      await _execute('rm -rf $_modelDir/* && rm -rf $_wrapperDir/*');
      
      await Future.delayed(const Duration(seconds: 2));
      await _execute('rm -rf $_modelDir/* && rm -rf $_wrapperDir/*');

      return PushResult(success: true, message: 'All models removed from LG.');
    } catch (e) {
      debugPrint('Remove all failed: $e');
      return PushResult(success: false, message: 'Remove all failed: $e');
    }
  }

  /// Clears the wrapper and system master KMLs without deleting model files.
  Future<PushResult> writeEmptyMasterKml() async {
    if (!_sshService.isConnected) {
      return PushResult(success: false, message: 'SSH not connected.');
    }

    try {
      await _writeEmptyWrapperMasterKml();
      await _channelDelay();

      await _forceRefresh();

      return PushResult(success: true, message: 'Master KML cleared successfully.');
    } catch (e) {
      debugPrint('Clear master KML failed: $e');
      return PushResult(success: false, message: 'Clear master KML failed: $e');
    }
  }

  // ─── Deep Clean ─────────────────────────────────────────────────

  Future<PushResult> deepClean() async {
    if (!_sshService.isConnected) {
      return PushResult(success: false, message: 'SSH not connected.');
    }

    try {
      await _writeEmptyDeepCleanKmls();
      await _channelDelay();

      await _forceRefresh();

      await Future.delayed(const Duration(seconds: 2));
      await _execute('rm -rf $_modelDir/* && rm -rf $_wrapperDir/*');

      await Future.delayed(const Duration(seconds: 2));
      await _execute('rm -rf $_modelDir/* && rm -rf $_wrapperDir/*');

      return PushResult(success: true, message: 'Deep clean complete — all content removed.');
    } catch (e) {
      debugPrint('Deep clean failed: $e');
      return PushResult(success: false, message: 'Deep clean failed: $e');
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────

  Future<void> _writeWrapperMasterKml(List<String> kmlFileNames) async {
    final networkLinks = kmlFileNames.map((kmlFile) => '''
    <NetworkLink>
      <name>$kmlFile</name>
      <Link>
        <href>http://lg1:${AppConstants.lgHttpPort}/3d_model_wrapper/$kmlFile</href>
        <href>http://lg1:${AppConstants.lgHttpPort}/3d_model_wrapper/$kmlFile</href>
      </Link>
    </NetworkLink>''').join('\n');

    final wrapperKml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"
     xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>Deployed 3D Models</name>
$networkLinks
  </Document>
</kml>''';

    await _sshService.uploadFile(
      localData: wrapperKml,
      remotePath: _wrapperMasterKml,
    );
  }

  Future<void> _writeEmptyWrapperMasterKml() async {
    final emptyKml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>Empty</name>
  </Document>
</kml>''';

    await _sshService.uploadFile(
      localData: emptyKml,
      remotePath: _wrapperMasterKml,
    );
  }

  Future<void> _writeEmptyDeepCleanKmls() async {
    final emptyKml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>Empty</name>
  </Document>
</kml>''';

    await _sshService.uploadFile(
      localData: emptyKml,
      remotePath: _wrapperMasterKml,
    );
    await _channelDelay();
    await _sshService.uploadFile(
      localData: emptyKml,
      remotePath: '/var/www/html/kml/playground.kml',
    );
    await _channelDelay();
    await _sshService.uploadFile(
      localData: emptyKml,
      remotePath: '/var/www/html/kml/balloon.kml',
    );
  }

  Future<void> _forceRefresh() async {
    await _systemKmlService.forceRefreshAll();
  }

  // ─── DAE Info Extraction ─────────────────────────────────────────

  Future<int?> extractDaeVertexCount(String filePath) async {
    try {
      // Run heavy regex parsing in a background isolate to avoid blocking the main UI thread.
      // Blocking the main thread stalls network I/O and causes SSH socket aborts.
      return await compute(_parseDaeVertices, filePath);
    } catch (e) {
      debugPrint('DAE parsing failed: $e');
      return null;
    }
  }

  // Top-level/static function required for `compute` isolate spawning.
  static int? _parseDaeVertices(String filePath) {
    try {
      final content = File(filePath).readAsStringSync();
      final regex = RegExp(r'<float_array[^>]*count="(\d+)"');
      final matches = regex.allMatches(content);

      int totalFloats = 0;
      for (final match in matches) {
        totalFloats += int.tryParse(match.group(1) ?? '0') ?? 0;
      }
      return totalFloats > 0 ? totalFloats ~/ 3 : null;
    } catch (_) {
      return null;
    }
  }
}

/// Result of a push or remove operation.
class PushResult {
  final bool success;
  final String message;

  PushResult({required this.success, required this.message});
}

// ─── Provider ──────────────────────────────────────────────────────────

final modelRepositoryProvider = Provider<ModelRepository>((ref) {
  return ModelRepository(
    ref.watch(sshServiceProvider),
    ref.watch(settingsServiceProvider),
    ref.watch(systemKmlServiceProvider),
  );
});
