import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/data/model_project.dart';
import 'package:lg_interactive_onboarding/src/features/settings/data/settings_service.dart';
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

  // ─── Constants ───────────────────────────────────────────────────
  static const _modelDir = '/var/www/html/model';
  static const _wrapperDir = '/var/www/html/3d_model_wrapper';
  static const _systemMasterKml = '/var/www/html/kml/master.kml';
  static const _wrapperMasterKml = '/var/www/html/3d_model_wrapper/master.kml';

  /// Small delay between SSH channel operations to avoid channel exhaustion.
  Future<void> _channelDelay() => Future.delayed(const Duration(milliseconds: 500));

  // ─── KML Generation ──────────────────────────────────────────────

  /// Generates a complete KML document for the given model project.
  String generateKml(ModelProject project) {
    final masterIp = _settingsService.host;
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
          <href>http://$masterIp:81/model/$remoteModelFile</href>
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
    final masterIp = _settingsService.host;
    final remoteModelFile = project.remoteModelFileName;

    return '''<Model>
  <Link>
    <href>http://$masterIp:81/model/$remoteModelFile</href>
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

  // ─── DAE Triangulation ──────────────────────────────────────────

  /// Ensures `dae_triangulate.py` and its dependencies are available
  /// on the LG master node, then triangulates the DAE file in-place.
  Future<bool> _triangulateRemoteDae(String remoteModelPath) async {
    if (!_sshService.isConnected) return false;

    final client = _sshService.client!;
    final remoteFileName = p.posix.basename(remoteModelPath);

    try {
      // 1. Check script + lxml in a single command, upload/install only if needed
      final checkResult = await client.run(
        'echo "SCRIPT=\$(test -f /tmp/dae_triangulate.py && echo OK || echo MISSING)"; '
        'echo "LXML=\$(python3 -c \'import lxml\' 2>&1 && echo OK || echo MISSING)"',
      );
      final checkOutput = String.fromCharCodes(checkResult).trim();

      await _channelDelay();

      // Upload script if missing
      if (checkOutput.contains('SCRIPT=MISSING') || !checkOutput.contains('SCRIPT=OK')) {
        debugPrint('Triangulate: Uploading dae_triangulate.py to /tmp/...');
        final scriptData = await rootBundle.loadString(
          'assets/scripts/dae_triangulate.py',
        );
        await _sshService.uploadFile(
          localData: scriptData,
          remotePath: '/tmp/dae_triangulate.py',
        );
        await _channelDelay();
      }

      // Install lxml if missing
      if (checkOutput.contains('LXML=MISSING') || !checkOutput.contains('LXML=OK')) {
        debugPrint('Triangulate: Installing lxml...');
        await client.run('pip3 install lxml 2>&1 || pip install lxml 2>&1 || true');
        await _channelDelay();
      }

      // 2. Triangulate + overwrite in a single command
      final triOutputPath = '/tmp/${remoteFileName}_tri.dae';
      debugPrint('Triangulate: Running on $remoteModelPath...');
      await client.run(
        'python3 /tmp/dae_triangulate.py "$remoteModelPath" "$triOutputPath" && '
        'mv "$triOutputPath" "$remoteModelPath"',
      );

      debugPrint('Triangulate: Success — $remoteModelPath triangulated');
      return true;
    } catch (e) {
      debugPrint('Triangulate: Failed: $e');
      return false;
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

    final client = _sshService.client!;
    final ext = project.fileExtension?.toLowerCase() ?? '';

    try {
      // 1. Ensure directories exist (single command)
      await client.run('mkdir -p $_modelDir && mkdir -p $_wrapperDir && mkdir -p /var/www/html/kml');
      await _channelDelay();

      // 2. Upload model file
      if (ext == '.kmz') {
        final entries = await extractKmz(project.filePath!);
        for (final entry in entries) {
          final remotePath = '$_modelDir/${project.id}_${entry.key}';
          await client.run('mkdir -p ${p.posix.dirname(remotePath)}');
          await _channelDelay();
          await _sshService.uploadBytes(bytes: entry.value, remotePath: remotePath);
          await _channelDelay();
        }
      } else {
        final fileBytes = await File(project.filePath!).readAsBytes();
        final remoteModelPath = '$_modelDir/${project.remoteModelFileName}';
        await _sshService.uploadBytes(bytes: fileBytes, remotePath: remoteModelPath);
        await _channelDelay();

        // 3. If DAE, triangulate in-place on the remote
        if (ext == '.dae') {
          await _triangulateRemoteDae(remoteModelPath);
          await _channelDelay();
        }
      }

      // 4. Generate and upload this model's KML to wrapper directory
      final kml = generateKml(project);
      await _sshService.uploadFile(
        localData: kml,
        remotePath: '$_wrapperDir/${project.remoteKmlFileName}',
      );
      await _channelDelay();

      // 5. Build wrapper master.kml with NetworkLinks for ALL deployed models
      final allKmlFiles = <String>[
        ...existingDeployments.map((d) => d.remoteKmlFileName),
        project.remoteKmlFileName,
      ];
      await _writeWrapperMasterKml(allKmlFiles);
      await _channelDelay();

      // 6. Write system master.kml with NetworkLink to wrapper master
      await _writeSystemMasterKml();
      await _channelDelay();

      // 7. Force refresh
      await _forceRefresh();

      // 8. Relaunch if requested
      if (relaunch) {
        await _channelDelay();
        final password = _settingsService.password;
        await client.run(
          '(echo $password; sleep 1) | sudo -S /usr/local/bin/lg-relaunch',
        );
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

    final client = _sshService.client!;

    try {
      // 1 & 2. Remove model file AND KML file in one command
      await client.run(
        'rm -f $_modelDir/${model.remoteModelFileName} && '
        'rm -f $_wrapperDir/${model.remoteKmlFileName}',
      );
      await _channelDelay();

      // 3. Rewrite wrapper master.kml with only the remaining models
      final remainingKmlFiles =
          remainingDeployments.map((d) => d.remoteKmlFileName).toList();

      if (remainingKmlFiles.isEmpty) {
        await _writeEmptyWrapperMasterKml();
      } else {
        await _writeWrapperMasterKml(remainingKmlFiles);
      }
      await _channelDelay();

      // 4. Update system master
      await _writeSystemMasterKml();
      await _channelDelay();

      // 5. Force refresh
      await _forceRefresh();

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

    final client = _sshService.client!;

    try {
      await client.run('rm -f $_modelDir/* && rm -f $_wrapperDir/*');
      await _channelDelay();

      await _writeEmptyWrapperMasterKml();
      await _channelDelay();

      await _writeSystemMasterKml();
      await _channelDelay();

      await _forceRefresh();

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

    final client = _sshService.client!;

    try {
      await client.run('rm -rf $_modelDir/* && rm -rf $_wrapperDir/*');
      await _channelDelay();

      await _writeEmptyWrapperMasterKml();
      await _channelDelay();

      await _writeSystemMasterKml();
      await _channelDelay();

      await _forceRefresh();

      return PushResult(success: true, message: 'Deep clean complete — all model files removed.');
    } catch (e) {
      debugPrint('Deep clean failed: $e');
      return PushResult(success: false, message: 'Deep clean failed: $e');
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────

  Future<void> _writeWrapperMasterKml(List<String> kmlFileNames) async {
    final masterIp = _settingsService.host;

    final networkLinks = kmlFileNames.map((kmlFile) => '''
    <NetworkLink>
      <name>$kmlFile</name>
      <Link>
        <href>http://$masterIp:81/3d_model_wrapper/$kmlFile</href>
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
    final masterIp = _settingsService.host;

    final systemKml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"
     xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>LG Content Studio</name>
    <NetworkLink>
      <name>3D Model Wrapper</name>
      <Link>
        <href>http://$masterIp:81/3d_model_wrapper/master.kml</href>
      </Link>
    </NetworkLink>
  </Document>
</kml>''';

    await _sshService.uploadFile(
      localData: systemKml,
      remotePath: _systemMasterKml,
    );
  }

  /// Forces LG to refresh the master KML by toggling refresh interval.
  /// Both sed commands are batched into a single call with a sleep between.
  Future<void> _forceRefresh() async {
    try {
      final client = _sshService.client!;

      // Batch both sed commands with a sleep between them into ONE channel
      await client.run(
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
      final content = await File(filePath).readAsString();
      final regex = RegExp(r'<float_array[^>]*count="(\d+)"');
      final matches = regex.allMatches(content);

      int totalFloats = 0;
      for (final match in matches) {
        totalFloats += int.tryParse(match.group(1) ?? '0') ?? 0;
      }
      return totalFloats > 0 ? totalFloats ~/ 3 : null;
    } catch (e) {
      debugPrint('DAE parsing failed: $e');
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
