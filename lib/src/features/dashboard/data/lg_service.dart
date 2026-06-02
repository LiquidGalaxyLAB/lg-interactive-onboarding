import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';
import 'package:lg_interactive_onboarding/src/features/settings/data/settings_service.dart';

/// Service for controlling the Liquid Galaxy rig.
///
/// Provides shutdown, reboot, relaunch, and KML management commands.
/// Ported from the lg_controller reference project.
class LGService {
  final SSHService _sshService;
  final SettingsService _settingsService;

  LGService(this._sshService, this._settingsService);

  /// Helper to ensure SSH is connected before running commands.
  bool get _isReady =>
      _sshService.client != null && !_sshService.client!.isClosed;

  // ─── Rig Control Commands ─────────────────────────────────────────

  /// Shuts down all rigs.
  Future<bool> shutdown() async {
    if (!_isReady) return false;

    final rigs = _settingsService.rigs;
    final password = _settingsService.password;

    try {
      final client = _sshService.client!;
      for (int i = 1; i <= rigs; i++) {
        final command =
            'sshpass -p "$password" ssh -o StrictHostKeyChecking=no lg$i '
            '"(echo $password; sleep 1) | sudo -S poweroff"';
        debugPrint('LGService: Shutdown lg$i...');
        await client.run(command);
      }
      return true;
    } catch (e) {
      debugPrint('LGService: Shutdown failed: $e');
      return false;
    }
  }

  /// Reboots all rigs.
  Future<bool> reboot() async {
    if (!_isReady) return false;

    final rigs = _settingsService.rigs;
    final password = _settingsService.password;

    try {
      final client = _sshService.client!;
      for (int i = 1; i <= rigs; i++) {
        final command =
            'sshpass -p "$password" ssh -o StrictHostKeyChecking=no lg$i '
            '"(echo $password; sleep 1) | sudo -S reboot"';
        debugPrint('LGService: Reboot lg$i...');
        await client.run(command);
      }
      return true;
    } catch (e) {
      debugPrint('LGService: Reboot failed: $e');
      return false;
    }
  }

  /// Relaunches the Liquid Galaxy application.
  ///
  /// Exact same implementation as lg_controller reference.
  Future<void> relaunch() async {
    if (!_isReady) return;

    final rigs = _settingsService.rigs;
    final password = _settingsService.password;

    final relaunchScript = """
      if [ -f /etc/init/lxdm.conf ]; then
        export SERVICE=lxdm
      elif [ -f /etc/init/lightdm.conf ]; then
        export SERVICE=lightdm
      else
        exit 1
      fi
      if [[ \\\$(service \\\$SERVICE status) =~ 'stop' ]]; then
        (echo $password; sleep 1) | sudo -S service \\\${SERVICE} start
      else
        (echo $password; sleep 1) | sudo -S service \\\${SERVICE} restart
      fi
    """;

    try {
      final client = _sshService.client!;
      for (var i = rigs; i >= 1; i--) {
        final command = 'sshpass -p "$password" ssh -o StrictHostKeyChecking=no lg$i "$relaunchScript"';
        debugPrint('LGService: Relaunch lg$i...');
        await client.run(command);
      }
    } catch (e) {
      debugPrint('LGService: Relaunch failed: $e');
    }
  }

  // ─── KML Commands ─────────────────────────────────────────────────

  /// Forces Google Earth to refresh the master KML by toggling refresh interval.
  Future<bool> refreshMasterKml() async {
    if (!_isReady) return false;

    try {
      final client = _sshService.client!;

      // Add refresh interval
      await client.run(
        'sed -i "s|<href>[^<]*master.kml<\\/href>|&<refreshMode>onInterval<\\/refreshMode><refreshInterval>1<\\/refreshInterval>|" ~/earth/kml/master/myplaces.kml',
      );

      await Future.delayed(const Duration(seconds: 1));

      // Remove refresh interval (revert)
      await client.run(
        'sed -i "s|<href>[^<]*master.kml<\\/href><refreshMode>onInterval<\\/refreshMode><refreshInterval>[0-9]\\+<\\/refreshInterval>|<href>##LG_PHPIFACE##kml/master.kml<\\/href>|" ~/earth/kml/master/myplaces.kml',
      );

      debugPrint('LGService: Master KML refreshed');
      return true;
    } catch (e) {
      debugPrint('LGService: Refresh master KML failed: $e');
      return false;
    }
  }

  /// Clears all KML from the master screen by writing an empty KML
  /// to /var/www/html/kml/master.kml, removing all NetworkLinks.
  Future<bool> clearKml() async {
    if (!_isReady) return false;

    try {
      final blankKml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>Cleared</name>
    <description>All content cleared</description>
  </Document>
</kml>''';

      await _sshService.uploadFile(
        localData: blankKml,
        remotePath: '/var/www/html/kml/master.kml',
      );

      // Delay before refresh to avoid SSH channel exhaustion
      await Future.delayed(const Duration(milliseconds: 300));
      await refreshMasterKml();

      debugPrint('LGService: KML cleared');
      return true;
    } catch (e) {
      debugPrint('LGService: Clear KML failed: $e');
      return false;
    }
  }
}

// ─── Provider ──────────────────────────────────────────────────────────

final lgServiceProvider = Provider<LGService>((ref) {
  return LGService(
    ref.watch(sshServiceProvider),
    ref.watch(settingsServiceProvider),
  );
});
