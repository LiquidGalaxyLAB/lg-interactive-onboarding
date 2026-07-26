import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';
import 'package:lg_interactive_onboarding/src/common/constants/app_constants.dart';
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
  bool get _isReady => _sshService.isConnected;

  // ─── Rig Control Commands ─────────────────────────────────────────

  /// Shuts down all rigs.
  Future<bool> shutdown() async {
    if (!_isReady) return false;

    final rigs = _settingsService.rigs;
    final password = _settingsService.password;

    try {
      for (int i = rigs; i >= 1; i--) {
        final command =
            'sshpass -p "$password" ssh -o StrictHostKeyChecking=no lg$i '
            '"(echo $password; sleep 1) | sudo -S poweroff"';
        debugPrint('LGService: Shutdown lg$i...');
        await _sshService.execute(command);
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
      for (int i = rigs; i >= 1; i--) {
        final command =
            'sshpass -p "$password" ssh -o StrictHostKeyChecking=no lg$i '
            '"(echo $password; sleep 1) | sudo -S reboot"';
        debugPrint('LGService: Reboot lg$i...');
        await _sshService.execute(command);
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
      for (int i = rigs; i >= 1; i--) {
        final command = 'sshpass -p "$password" ssh -o StrictHostKeyChecking=no lg$i "$relaunchScript"';
        debugPrint('LGService: Relaunch lg$i...');
        await _sshService.execute(command);
      }
    } catch (e) {
      debugPrint('LGService: Relaunch failed: $e');
    }
  }

  // ─── KML Commands ─────────────────────────────────────────────────

  /// Commands Liquid Galaxy to fly to a specific coordinate and orientation.
  Future<bool> flyTo({
    required double latitude,
    required double longitude,
    required double altitude,
    required double heading,
    required double tilt,
    double range = 1000,
  }) async {
    if (!_isReady) return false;

    try {
      final lookAt = '<LookAt>'
          '<longitude>$longitude</longitude>'
          '<latitude>$latitude</latitude>'
          '<altitude>$altitude</altitude>'
          '<heading>$heading</heading>'
          '<tilt>$tilt</tilt>'
          '<range>$range</range>'
          '<gx:altitudeMode>relativeToGround</gx:altitudeMode>'
          '</LookAt>';
          
      final command = 'echo "flytoview=$lookAt" > /tmp/query.txt';
      await _sshService.execute(command);
      
      debugPrint('LGService: Flew to $latitude, $longitude');
      return true;
    } catch (e) {
      debugPrint('LGService: FlyTo failed: $e');
      return false;
    }
  }

  /// Commands Liquid Galaxy to play a named gx:Tour in the loaded KML.
  Future<bool> playTour(String tourName) async {
    if (!_isReady) return false;
    try {
      final command = 'echo "playtour=$tourName" > /tmp/query.txt';
      await _sshService.execute(command);
      debugPrint('LGService: Playing tour "$tourName"');
      return true;
    } catch (e) {
      debugPrint('LGService: playTour failed: $e');
      return false;
    }
  }

  /// Stops any currently playing tour on the Liquid Galaxy.
  Future<bool> stopTour() async {
    if (!_isReady) return false;
    try {
      await _sshService.execute('echo "exittour=true" > /tmp/query.txt');
      debugPrint('LGService: Tour stopped');
      return true;
    } catch (e) {
      debugPrint('LGService: stopTour failed: $e');
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
