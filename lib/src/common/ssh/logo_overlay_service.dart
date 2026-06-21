import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/common/constants/app_constants.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';
import 'package:lg_interactive_onboarding/src/features/settings/data/settings_service.dart';

/// Service for managing the logo banner ScreenOverlay on the LG rig's
/// leftmost screen.
///
/// The logo is displayed as a KML `<ScreenOverlay>` on the slave screen
/// corresponding to the leftmost physical display. It is activated when
/// a 3D model is pushed and deactivated on clear/remove/deep-clean.
///
/// Screen numbering follows the LG clockwise convention:
///   - 3 rigs: lg3 (left), lg1 (master/center), lg2 (right)
///   - 5 rigs: lg4, lg5, lg1, lg2, lg3  → leftmost = lg4
///   - Formula: leftScreen = (rigsCount ~/ 2) + 2
class LogoOverlayService {
  final SSHService _sshService;
  final SettingsService _settingsService;

  LogoOverlayService(this._sshService, this._settingsService);

  /// Session-level flag: avoids re-uploading the logo PNG on every push.
  bool _logoUploaded = false;

  /// Small delay between SSH channel operations to avoid channel exhaustion.
  Future<void> _channelDelay() => Future.delayed(AppConstants.sshChannelDelay);

  // ─── Left Screen Calculation ──────────────────────────────────────

  /// Returns the slave screen number for the leftmost physical display.
  ///
  /// LG screens are arranged clockwise around the master (lg1):
  ///   rigsCount=3 → [lg3, lg1, lg2] → leftmost = 3
  ///   rigsCount=5 → [lg4, lg5, lg1, lg2, lg3] → leftmost = 4
  ///   rigsCount=7 → [lg5, lg6, lg7, lg1, lg2, lg3, lg4] → leftmost = 5
  ///
  /// Formula: (rigsCount ~/ 2) + 2
  int _getLeftSlaveScreen() {
    final rigs = _settingsService.rigs;
    return (rigs ~/ 2) + 2;
  }

  // ─── Send Logo ────────────────────────────────────────────────────

  /// Uploads the logo PNG (if not already uploaded this session) and writes
  /// a KML ScreenOverlay to the leftmost slave screen file.
  ///
  /// The overlay is positioned at the top-left corner with dimensions
  /// [AppConstants.logoOverlayWidth] × [AppConstants.logoOverlayHeight].
  Future<void> sendLogo() async {
    if (!_sshService.isConnected) {
      debugPrint('LogoOverlay: SSH not connected, skipping sendLogo');
      return;
    }

    try {
      // 1. Upload the logo PNG to the LG master (once per session)
      if (!_logoUploaded) {
        await _uploadLogoPng();
      }

      // 2. Write the ScreenOverlay KML to the leftmost slave screen
      final leftScreen = _getLeftSlaveScreen();
      final masterIp = _settingsService.host;
      final kmlPath = '${AppConstants.lgSlaveKmlDir}/slave_$leftScreen.kml';

      final kml = _buildLogoKml(masterIp);

      await _sshService.uploadFile(localData: kml, remotePath: kmlPath);
      await _channelDelay();

      // 3. Force refresh the slave KML
      await _forceRefreshSlave('slave_$leftScreen.kml');

      debugPrint('LogoOverlay: Logo sent to slave_$leftScreen');
    } catch (e) {
      debugPrint('LogoOverlay: sendLogo failed: $e');
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
    if (result == null) throw Exception('Execution failed: $command');
    
    return result.stdout.trim();
  }

  // ─── Clear Logo ───────────────────────────────────────────────────

  /// Clears the logo overlay by writing an empty KML to the leftmost
  /// slave screen file and removes the logo PNG from the master.
  Future<void> clearLogo() async {
    if (!_sshService.isConnected) {
      debugPrint('LogoOverlay: SSH not connected, skipping clearLogo');
      return;
    }

    try {
      final leftScreen = _getLeftSlaveScreen();
      final kmlPath = '${AppConstants.lgSlaveKmlDir}/slave_$leftScreen.kml';

      const emptyKml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document><name>Empty</name></Document>
</kml>''';

      await _sshService.uploadFile(localData: emptyKml, remotePath: kmlPath);
      await _channelDelay();

      await _forceRefreshSlave('slave_$leftScreen.kml');

      // Remove the logo image from the master to keep the file system clean. Use sudo to ensure it removes properly.
      await _execute('rm -f ${AppConstants.lgLogoRemotePath}', sudo: true);
      _logoUploaded = false;

      debugPrint('LogoOverlay: Logo cleared from slave_$leftScreen and file removed from master');
    } catch (e) {
      debugPrint('LogoOverlay: clearLogo failed: $e');
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  /// Uploads the bundled logo PNG to the LG master node via SFTP.
  Future<void> _uploadLogoPng() async {
    try {
      final byteData = await rootBundle.load(AppConstants.lgLogoAssetPath);
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );

      await _sshService.uploadBytes(
        bytes: bytes,
        remotePath: AppConstants.lgLogoRemotePath,
      );
      _logoUploaded = true;
      debugPrint('LogoOverlay: Logo PNG uploaded to ${AppConstants.lgLogoRemotePath} (${bytes.length} bytes)');
    } catch (e) {
      debugPrint('LogoOverlay: Failed to upload logo PNG: $e');
      rethrow;
    }
  }

  /// Builds the KML document containing a ScreenOverlay for the logo.
  String _buildLogoKml(String masterIp) {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"
     xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>Logo</name>
    <Folder>
      <name>Logo</name>
      <ScreenOverlay>
        <name>Logo</name>
        <Icon>
          <href>http://$masterIp:${AppConstants.lgHttpPort}/kml/logo_banner.png</href>
        </Icon>
        <overlayXY x="0" y="1" xunits="fraction" yunits="fraction"/>
        <screenXY x="0" y="1" xunits="fraction" yunits="fraction"/>
        <rotationXY x="0" y="0" xunits="fraction" yunits="fraction"/>
        <size x="${AppConstants.logoOverlayWidth}" y="${AppConstants.logoOverlayHeight}" xunits="pixels" yunits="pixels"/>
      </ScreenOverlay>
    </Folder>
  </Document>
</kml>''';
  }

  /// Forces LG to refresh a slave KML file by toggling refresh interval
  /// in the slave myplaces.kml.
  Future<void> _forceRefreshSlave(String kmlFileName) async {
    try {
      // Batch both sed commands with a sleep between them into ONE channel
      // Target: ~/earth/kml/slave/myplaces.kml (slave screens)
      await _sshService.execute(
        'sed -i "s|<href>[^<]*$kmlFileName<\\/href>|&<refreshMode>onInterval<\\/refreshMode><refreshInterval>1<\\/refreshInterval>|" ~/earth/kml/slave/myplaces.kml && '
        'sleep 1 && '
        'sed -i "s|<href>[^<]*$kmlFileName<\\/href><refreshMode>onInterval<\\/refreshMode><refreshInterval>[0-9]\\+<\\/refreshInterval>|<href>##LG_PHPIFACE##kml/$kmlFileName<\\/href>|" ~/earth/kml/slave/myplaces.kml',
      );
    } catch (e) {
      debugPrint('LogoOverlay: Force refresh failed: $e');
    }
  }
}

// ─── Provider ──────────────────────────────────────────────────────────

final logoOverlayServiceProvider = Provider<LogoOverlayService>((ref) {
  return LogoOverlayService(
    ref.watch(sshServiceProvider),
    ref.watch(settingsServiceProvider),
  );
});
