import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/common/constants/app_constants.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';
import 'package:lg_interactive_onboarding/src/features/settings/data/settings_service.dart';

/// Manages the static top-level KML files (master.kml and slave_X.kml) on the LG rig.
/// This service acts as the single source of truth for the base KML structure,
/// allocating NetworkLinks for individual features (like 3D models and logos)
/// so they don't overwrite each other.
class SystemKmlService {
  final SSHService _sshService;
  final SettingsService _settingsService;

  SystemKmlService(this._sshService, this._settingsService);

  bool _wasConnected = false;

  /// Called by the connection watcher on every SSH state change.
  void onConnectionChange() {
    final nowConnected = _sshService.isConnected;
    if (nowConnected == _wasConnected) return; // no edge
    _wasConnected = nowConnected;
    if (nowConnected) {
      debugPrint('SystemKmlService: SSH connected → initializing static KMLs');
      _initializeSystemKmls();
    }
  }

  /// Calculates the leftmost slave screen number.
  int _getLeftSlaveScreen() {
    final rigs = _settingsService.rigs;
    return (rigs ~/ 2) + 2;
  }

  /// Small delay between SSH channel operations to avoid channel exhaustion.
  Future<void> _channelDelay() => Future.delayed(AppConstants.sshChannelDelay);

  /// Initializes the base `master.kml` and `slave_X.kml` files.
  Future<void> _initializeSystemKmls() async {
    if (!_sshService.isConnected) return;

    try {
      // 1. Write the system master KML (for lg1)
      const systemMasterKml = '''<?xml version="1.0" encoding="UTF-8"?>
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
    <NetworkLink>
      <name>Playground KML</name>
      <Link>
        <href>http://lg1:${AppConstants.lgHttpPort}/kml/playground.kml</href>
      </Link>
    </NetworkLink>
  </Document>
</kml>''';

      await _sshService.uploadFile(
        localData: systemMasterKml,
        remotePath: AppConstants.lgSystemMasterKml,
      );
      await _channelDelay();

      // 2. Write the slave_X.kml for all slave screens
      final rigsCount = _settingsService.rigs;
      final leftmostScreen = _getLeftSlaveScreen();
      // The rightmost screen is typically calculated as (rigsCount / 2).floor() + 1
      final rightmostScreen = (rigsCount / 2).floor() + 1;

      for (int i = 2; i <= rigsCount; i++) {
        // Build the KML string based on whether this is the leftmost screen
        final isLeftmost = (i == leftmostScreen);
        final isRightmost = (i == rightmostScreen);
        
        final logoLink = isLeftmost ? '''
    <NetworkLink>
      <name>Logo Overlay</name>
      <Link>
        <href>http://lg1:${AppConstants.lgHttpPort}/kml/logo.kml</href>
      </Link>
    </NetworkLink>''' : '';

        final balloonLink = isRightmost ? '''
    <NetworkLink>
      <name>Educational Balloon</name>
      <Link>
        <href>http://lg1:${AppConstants.lgHttpPort}/kml/balloon.kml</href>
        <refreshMode>onInterval</refreshMode>
        <refreshInterval>2</refreshInterval>
      </Link>
    </NetworkLink>''' : '';

        final slaveKml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"
     xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>Slave Screen $i</name>
    <NetworkLink>
      <name>3D Model Wrapper</name>
      <Link>
        <href>http://lg1:${AppConstants.lgHttpPort}/3d_model_wrapper/master.kml</href>
      </Link>
    </NetworkLink>
    <NetworkLink>
      <name>Playground KML</name>
      <Link>
        <href>http://lg1:${AppConstants.lgHttpPort}/kml/playground.kml</href>
      </Link>
    </NetworkLink>$logoLink$balloonLink
  </Document>
</kml>''';

        await _sshService.uploadFile(
          localData: slaveKml,
          remotePath: '${AppConstants.lgSlaveKmlDir}/slave_$i.kml',
        );
        await _channelDelay();
      }

      debugPrint('SystemKmlService: Static KMLs initialized successfully.');
      
      // Upload the local KML icons to the rig
      await _uploadKmlIcons();
    } catch (e) {
      debugPrint('SystemKmlService: Failed to initialize static KMLs: $e');
    }
  }

  /// Uploads local KML balloon icons from assets to the LG rig's web server.
  Future<void> _uploadKmlIcons() async {
    const icons = [
      'tree.png', 'car.png', 'pyramid.png', 'football.png',
      'placemark.png', 'polygon.png', 'linestring.png',
      'ground_overlay.png', 'screen_overlay.png', 'tour.png'
    ];
    
    try {
      await _execute('mkdir -p /var/www/html/kml_icons');
      await _channelDelay();
      
      for (final icon in icons) {
        final byteData = await rootBundle.load('assets/kml_icons/$icon');
        final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
        await _sshService.uploadBinaryFile(
          localData: bytes,
          remotePath: '/var/www/html/kml_icons/$icon',
        );
        await _channelDelay();
      }
      debugPrint('SystemKmlService: KML icons uploaded successfully.');
    } catch (e) {
      debugPrint('SystemKmlService: Failed to upload KML icons: $e');
    }
  }

  /// Cleans up any static assets uploaded by this service (e.g. kml_icons directory, model wrapper, and models).
  Future<void> cleanUp() async {
    if (!_sshService.isConnected) return;
    try {
      await _execute('rm -rf /var/www/html/kml_icons');
      await _execute('rm -rf ${AppConstants.lgModelDir}');
      await _execute('rm -rf ${AppConstants.lgWrapperDir}');
      await _execute('rm -f /var/www/html/kml/balloon.kml /var/www/html/kml/logo.kml /var/www/html/kml/playground.kml');
      debugPrint('SystemKmlService: Cleaned up KML icons, models, wrappers, and dynamic KMLs.');
    } catch (e) {
      debugPrint('SystemKmlService: Failed to clean up: $e');
    }
  }

  /// Executes an SSH command, optionally with sudo, and applies the channel delay.
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

  /// Forces LG to refresh the master KML and all slave KMLs by toggling the refresh interval.
  Future<bool> forceRefreshAll() async {
    try {
      // 1. Refresh master KML
      await _execute(
        'sed -i "s|<href>[^<]*master.kml<\\/href>|&<refreshMode>onInterval<\\/refreshMode><refreshInterval>1<\\/refreshInterval>|" ~/earth/kml/master/myplaces.kml && '
        'sleep 1 && '
        'sed -i "s|<href>[^<]*master.kml<\\/href><refreshMode>onInterval<\\/refreshMode><refreshInterval>[0-9]\\+<\\/refreshInterval>|<href>##LG_PHPIFACE##kml/master.kml<\\/href>|" ~/earth/kml/master/myplaces.kml',
      );
      await _channelDelay();

      // 2. Refresh slave KMLs
      final rigs = _settingsService.rigs;
      for (int i = 2; i <= rigs; i++) {
        await _execute(
          'sed -i "s|<href>[^<]*slave_$i.kml<\\/href>|&<refreshMode>onInterval<\\/refreshMode><refreshInterval>1<\\/refreshInterval>|" ~/earth/kml/slave/myplaces.kml && '
          'sleep 1 && '
          'sed -i "s|<href>[^<]*slave_$i.kml<\\/href><refreshMode>onInterval<\\/refreshMode><refreshInterval>[0-9]\\+<\\/refreshInterval>|<href>##LG_PHPIFACE##kml/slave_$i.kml<\\/href>|" ~/earth/kml/slave/myplaces.kml',
        );
        await _channelDelay();
      }
      return true;
    } catch (e) {
      debugPrint('SystemKmlService: Force refresh all failed: $e');
      return false;
    }
  }
}

// ─── Providers ─────────────────────────────────────────────────────────

final systemKmlServiceProvider = Provider<SystemKmlService>((ref) {
  return SystemKmlService(
    ref.watch(sshServiceProvider),
    ref.watch(settingsServiceProvider),
  );
});

/// Watches the SSH connection and initializes static KMLs upon connection.
final systemConnectionWatcherProvider = Provider<void>((ref) {
  final ssh = ref.read(sshServiceProvider);
  final kmlService = ref.read(systemKmlServiceProvider);

  void listener() => kmlService.onConnectionChange();
  ssh.addListener(listener);

  ref.onDispose(() {
    ssh.removeListener(listener);
  });
});
