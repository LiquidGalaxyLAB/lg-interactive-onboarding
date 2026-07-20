import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/data/model_project.dart';
import 'package:lg_interactive_onboarding/src/features/settings/data/settings_service.dart';
import 'package:lg_interactive_onboarding/src/common/constants/app_constants.dart';
import 'package:path/path.dart' as p;

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

  ModelRepository(this._sshService, this._settingsService);

  /// Session-level cache: avoids re-checking assimp installation on every push.
  /// Also caches lxml (Python dependency for triangulation script).
  bool _assimpVerified = false;
  bool _lxmlVerified = false;

  // ─── Constants ───────────────────────────────────────────────────
  static const _modelDir = AppConstants.lgModelDir;
  static const _wrapperDir = AppConstants.lgWrapperDir;
  static const _systemMasterKml = AppConstants.lgSystemMasterKml;
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

    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"
     xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>3D Model: ${project.fileName}</name>
    <Placemark>
      <name>${project.fileName}</name>
      <Model>
        <Link>
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
          <x>${project.scaleX}</x>
          <y>${project.scaleY}</y>
          <z>${project.scaleZ}</z>
        </Scale>
      </Model>
    </Placemark>
  </Document>
</kml>''';
  }

  /// Generates just the Model block (for KML preview).
  String generateModelBlock(ModelProject project) {
    final remoteModelFile = project.remoteModelFileName;

    return '''<Model>
  <Link>
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
    <x>${project.scaleX}</x>
    <y>${project.scaleY}</y>
    <z>${project.scaleZ}</z>
  </Scale>
</Model>''';
  }

  // ─── KMZ Handling ────────────────────────────────────────────────

  Future<List<MapEntry<String, Uint8List>>> extractKmz(String kmzPath) async {
    final results = <MapEntry<String, Uint8List>>[];
    try {
      final bytes = await File(kmzPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive.files) {
        if (file.isFile) {
          final data = file.content as List<int>;
          results.add(MapEntry(file.name, Uint8List.fromList(data)));
        }
      }
    } catch (e) {
      debugPrint('KMZ extraction failed: $e');
    }
    return results;
  }

  // ─── Assimp Prerequisite Check ─────────────────────────────────

  /// Ensures `assimp` (assimp-utils) is installed on the LG master node.
  ///
  /// Checks once per session; subsequent calls return immediately.
  /// If missing, installs via `apt` using the stored SSH password.
  ///
  /// Uses the `(echo password; sleep 1) | sudo -S` pattern established
  /// across the codebase — the sleep keeps the pipe open long enough for
  /// sudo to read the password from stdin.
  Future<void> _ensureAssimpInstalled() async {
    if (_assimpVerified) return;
    if (!_sshService.isConnected) throw Exception('SSH not connected.');

    try {
      // Check if assimp is already available
      final whichOutput = await _execute('which assimp');

      if (whichOutput.isNotEmpty && !whichOutput.contains('not found')) {
        debugPrint('Assimp: Already installed at $whichOutput');
        _assimpVerified = true;
        return;
      }

      // ── Step 1: apt update ──
      debugPrint('Assimp: Not found — installing assimp-utils...');
      final updateOutput = await _execute('apt update -qq 2>&1', sudo: true);
      debugPrint('Assimp: apt update output: $updateOutput');

      // ── Step 2: apt install ──
      final installOutput = await _execute('apt install assimp-utils -y -qq 2>&1', sudo: true);
      debugPrint('Assimp: apt install output: $installOutput');

      // ── Step 3: Verify installation succeeded ──
      final verifyOutput = await _execute('which assimp');

      if (verifyOutput.isNotEmpty && !verifyOutput.contains('not found')) {
        debugPrint('Assimp: Installed successfully at $verifyOutput');
        _assimpVerified = true;
        return;
      }

      throw Exception('Installation failed — assimp not found after apt install.');
    } catch (e) {
      throw Exception('Prerequisite check failed: $e');
    }
  }

  // ─── Assimp Format Conversion ──────────────────────────────────

  /// Converts a non-DAE model file to COLLADA (.dae) using assimp on the
  /// LG master node.
  ///
  /// [uploadedFilePath] — the full remote path of the uploaded raw file
  ///   (e.g., `/var/www/html/model/123_car.obj`).
  /// [targetDaePath] — the desired output .dae path
  ///   (e.g., `/var/www/html/model/123_car.dae`).
  ///
  /// On success: the raw file is deleted, only the .dae remains.
  /// On failure: throws an [Exception] with a descriptive message.
  Future<void> _convertToCollada({
    required String uploadedFilePath,
    required String targetDaePath,
  }) async {

    try {
      debugPrint('Assimp: Converting $uploadedFilePath → $targetDaePath');

      final conversionOutput = await _execute('assimp export "$uploadedFilePath" "$targetDaePath" -tri 2>&1');

      // Verify the .dae was actually created
      final verifyOutput = await _execute('test -f "$targetDaePath" && echo EXISTS');

      if (!verifyOutput.contains('EXISTS')) {
        throw Exception(
          'Conversion failed: unsupported format or corrupt file. '
          'assimp output: $conversionOutput',
        );
      }

      // Cleanup: delete the original raw file to avoid clutter
      await _execute('rm -f "$uploadedFilePath"');

      debugPrint('Assimp: Conversion successful, raw file cleaned up');
    } catch (e) {
      // Cleanup on failure too — remove any partial output
      await _execute('rm -f "$targetDaePath"').catchError((_) => '');
      rethrow;
    }
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
  Future<void> _triangulateDaeWithScript(String remoteDaePath) async {
    if (!_sshService.isConnected) throw Exception('SSH not connected.');
    final triangulatedTempPath = '${remoteDaePath}_tri_tmp.dae';
    const remoteScriptPath = AppConstants.lgRemoteScriptPath;

    try {
      debugPrint('Triangulate: Processing $remoteDaePath...');

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

      // 3. Run the triangulation script
      final triOutput = await _execute('python3 $remoteScriptPath "$remoteDaePath" "$triangulatedTempPath" 2>&1');
      debugPrint('Triangulate: script output: $triOutput');

      // 4. Verify the triangulated file was created
      final verifyOutput = await _execute('test -f "$triangulatedTempPath" && echo EXISTS');

      if (!verifyOutput.contains('EXISTS')) {
        throw Exception('Output file not created. Script output: $triOutput');
      }

      // 5. Overwrite the original .dae with the triangulated version
      await _execute('mv -f "$triangulatedTempPath" "$remoteDaePath"');

      debugPrint('Triangulate: Success — $remoteDaePath overwritten with triangulated version');
    } catch (e) {
      // Cleanup temp file on failure
      await _execute('rm -f "$triangulatedTempPath"').catchError((_) => '');
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
    final ext = project.fileExtension?.toLowerCase() ?? '';

    try {
      // 1. Ensure directories exist (single command)
      await _execute('mkdir -p $_modelDir && mkdir -p $_wrapperDir && mkdir -p /var/www/html/kml');

      // 2. Upload and process model file
      if (ext == '.kmz') {
        // ── KMZ path: extract and upload contents (unchanged) ──
        final entries = await extractKmz(project.filePath!);
        for (final entry in entries) {
          final remotePath = '$_modelDir/${project.id}_${entry.key}';
          await _execute('mkdir -p ${p.posix.dirname(remotePath)}');
          await _sshService.uploadBytes(bytes: entry.value, remotePath: remotePath);
          await _channelDelay();
        }
      } else {
        // ── All other formats (DAE, OBJ, FBX, GLTF, GLB, etc.) ──
        final fileBytes = await File(project.filePath!).readAsBytes();

        // The final .dae path on the server (what KML will reference)
        final remoteDaePath = '$_modelDir/${project.remoteModelFileName}';

        // Upload with a "raw_" prefix, then let Assimp process/triangulate it
        final safeRawName = project.fileName?.replaceAll(' ', '_') ?? 'unnamed';
        final rawUploadPath = '$_modelDir/raw_${project.id}_$safeRawName';

        await _sshService.uploadBytes(bytes: fileBytes, remotePath: rawUploadPath);
        await _channelDelay();

        if (ext == '.dae') {
          // Bypass Assimp conversion since the file is already a DAE.
          // The Python script will handle triangulation next.
          await _execute('mv -f "$rawUploadPath" "$remoteDaePath"');
        } else {
          // Ensure assimp is available
          try {
            await _ensureAssimpInstalled();
          } catch (e) {
            await _execute('rm -f "$rawUploadPath"');
            return PushResult(
              success: false,
              message: 'Failed to install assimp: $e',
            );
          }

          // Convert/Triangulate to .dae (deletes the raw file on success)
          try {
            await _convertToCollada(
              uploadedFilePath: rawUploadPath,
              targetDaePath: remoteDaePath,
            );
          } catch (e) {
            return PushResult(
              success: false,
              message: 'Model conversion failed: $e',
            );
          }
          await _channelDelay();
        }

        // 3. Triangulate the .dae in-place using Python script
        //    (converts <polylist>/<polygons> → <triangles> for Google Earth)
        try {
          await _triangulateDaeWithScript(remoteDaePath);
        } catch (e) {
          return PushResult(
            success: false,
            message: 'DAE triangulation failed: $e',
          );
        }
        await _channelDelay();
      }

      // 5. Generate and upload this model's KML to wrapper directory
      final kml = generateKml(project);
      await _sshService.uploadFile(
        localData: kml,
        remotePath: '$_wrapperDir/${project.remoteKmlFileName}',
      );
      await _channelDelay();

      // Set proper permissions for the web server to read the model and KML
      await _execute('chmod 644 "$_wrapperDir/${project.remoteKmlFileName}"');
      if (ext != '.kmz') {
        await _execute('chmod 644 "$_modelDir/${project.remoteModelFileName}"');
      }

      // 6. Build wrapper master.kml with NetworkLinks for ALL deployed models
      final allKmlFiles = <String>[
        ...existingDeployments.map((d) => d.remoteKmlFileName),
        project.remoteKmlFileName,
      ];
      await _writeWrapperMasterKml(allKmlFiles);
      await _channelDelay();

      // 7. Write system master.kml with NetworkLink to wrapper master
      await _writeSystemMasterKml();
      await _channelDelay();

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
      final remainingKmlFiles =
          remainingDeployments.map((d) => d.remoteKmlFileName).toList();

      if (remainingKmlFiles.isEmpty) {
        await _writeEmptyWrapperMasterKml();
      } else {
        await _writeWrapperMasterKml(remainingKmlFiles);
      }
      await _channelDelay();

      // 3. Update system master
      await _writeSystemMasterKml();
      await _channelDelay();

      // 4. Force refresh to unload the model in Google Earth
      await _forceRefresh();
      
      // Wait a moment for Google Earth to process the refresh before deleting files
      await Future.delayed(const Duration(seconds: 2));

      // 5. Now it is safe to remove the model file AND its KML file
      await _execute(
        'rm -f $_modelDir/${model.remoteModelFileName} && '
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

      await _writeSystemMasterKml();
      await _channelDelay();

      await _forceRefresh();
      
      await Future.delayed(const Duration(seconds: 2));
      await _execute('rm -f $_modelDir/* && rm -f $_wrapperDir/*');

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

      await _writeSystemMasterKml();
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
      await _writeEmptyWrapperMasterKml();
      await _channelDelay();

      await _writeSystemMasterKml();
      await _channelDelay();

      await _forceRefresh();

      await Future.delayed(const Duration(seconds: 2));
      await _execute('rm -rf $_modelDir/* && rm -rf $_wrapperDir/*');

      return PushResult(success: true, message: 'Deep clean complete — all model files removed.');
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

  Future<void> _writeSystemMasterKml() async {
    final systemKml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"
     xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>LG Content Studio</name>
    <NetworkLink>
      <name>3D Model Wrapper</name>
      <Link>
        <href>http://lg1:${AppConstants.lgHttpPort}/3d_model_wrapper/master.kml</href>
      </Link>
    </NetworkLink>
  </Document>
</kml>''';

    await _sshService.uploadFile(
      localData: systemKml,
      remotePath: _systemMasterKml,
    );

    final rigsCount = _settingsService.rigs;
    for (int i = 2; i <= rigsCount; i++) {
      await _channelDelay();
      await _sshService.uploadFile(
        localData: systemKml,
        remotePath: '${AppConstants.lgSlaveKmlDir}/slave_$i.kml',
      );
    }
  }

  /// Forces LG to refresh the master KML by toggling refresh interval.
  /// Both sed commands are batched into a single call with a sleep between.
  Future<void> _forceRefresh() async {
    try {
      // Batch both sed commands with a sleep between them into ONE channel
      await _execute(
        'sed -i "s|<href>[^<]*master.kml<\\/href>|&<refreshMode>onInterval<\\/refreshMode><refreshInterval>1<\\/refreshInterval>|" ~/earth/kml/master/myplaces.kml && '
        'sleep 1 && '
        'sed -i "s|<href>[^<]*master.kml<\\/href><refreshMode>onInterval<\\/refreshMode><refreshInterval>[0-9]\\+<\\/refreshInterval>|<href>##LG_PHPIFACE##kml/master.kml<\\/href>|" ~/earth/kml/master/myplaces.kml',
      );
    } catch (e) {
      debugPrint('Force refresh failed: $e');
    }
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
  );
});
