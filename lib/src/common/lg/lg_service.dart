import 'dart:async';
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

  bool _orbitPlaying = false;
  Timer? _orbitTimer;
  bool get isOrbitPlaying => _orbitPlaying;

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

  /// Calculates the ID of the rightmost screen.
  int get _rightMostScreen {
    final screens = _settingsService.rigs;
    return (screens / 2).floor() + 1;
  }

  /// Sends a KML balloon string to the Liquid Galaxy rig.
  Future<bool> sendBalloonKml(String kmlContent) async {
    if (!_isReady) return false;
    try {
      final command = "echo '$kmlContent' > /var/www/html/kml/balloon.kml";
      await _sshService.execute(command);
      debugPrint('LGService: Sent balloon KML');
      return true;
    } catch (e) {
      debugPrint('LGService: sendBalloonKml failed: $e');
      return false;
    }
  }

  /// Cleans the balloon from the Liquid Galaxy rig.
  Future<bool> cleanBalloonKML() async {
    if (!_isReady) return false;
    try {
      final emptyKml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>Empty</name>
  </Document>
</kml>''';
      final command = "echo '$emptyKml' > /var/www/html/kml/balloon.kml";
      await _sshService.execute(command);
      debugPrint('LGService: Cleaned balloon KML');
      return true;
    } catch (e) {
      debugPrint('LGService: cleanBalloonKML failed: $e');
      return false;
    }
  }

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
    
    // Stop any active orbit stream before manually flying
    await orbitStop();

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

  /// Commands Liquid Galaxy to fly to a coordinate, wait for arrival, and then start an orbit.
  Future<bool> flyToAndOrbit({
    required double latitude,
    required double longitude,
    required double altitude,
    required double heading,
    required double tilt,
    double range = 1000,
    int delaySeconds = 6, // Approx time for Google Earth to complete the trailing tour
  }) async {
    final success = await flyTo(
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      heading: heading,
      tilt: tilt,
      range: range,
    );
    if (success) {
      Future.delayed(Duration(seconds: delaySeconds), () {
        orbitPlay(
          latitude: latitude,
          longitude: longitude,
          range: range,
          tilt: tilt,
        );
      });
    }
    return success;
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
      final command = 'echo "exittour=true" > /tmp/query.txt';
      await _sshService.execute(command);
      debugPrint('LGService: Stopped tour');
      return true;
    } catch (e) {
      debugPrint('LGService: stopTour failed: $e');
      return false;
    }
  }

  // ─── Live Stream Orbit ──────────────────────────────────────────────

  /// Flies to a specific LookAt configuration for the orbit frame.
  Future<void> _flyToOrbit(
    double latitude,
    double longitude,
    double range,
    double tilt,
    double heading,
  ) async {
    try {
      final String lookAt = '<LookAt>'
          '<longitude>$longitude</longitude>'
          '<latitude>$latitude</latitude>'
          '<heading>$heading</heading>'
          '<tilt>$tilt</tilt>'
          '<range>$range</range>'
          '<gx:altitudeMode>relativeToGround</gx:altitudeMode>'
          '</LookAt>';
      await _sshService.execute('echo "flytoview=$lookAt" > /tmp/query.txt');
    } catch (error) {
      debugPrint('LGService: Error in _flyToOrbit: $error');
    }
  }

  /// Starts a live streaming orbit around a destination point.
  Future<bool> orbitPlay({
    required double latitude,
    required double longitude,
    required double range,
    required double tilt,
  }) async {
    if (_orbitPlaying) return false;
    if (!_isReady) {
      debugPrint('LGService: Cannot start orbit: LG not connected');
      return false;
    }

    // Ensure any existing tour is stopped to prevent conflicts
    await stopTour();
    await Future.delayed(const Duration(milliseconds: 100));

    _orbitPlaying = true;

    try {
      const int steps = 60;
      const int stepDuration = 400; // milliseconds
      int currentStep = 0;
      bool isMoving = false;

      _orbitTimer = Timer.periodic(const Duration(milliseconds: stepDuration), (timer) async {
        if (!_orbitPlaying || currentStep >= steps) {
          timer.cancel();
          _orbitPlaying = false;
          try {
            await stopTour(); // Sends exittour=true to stabilize
          } catch (e) {
            debugPrint('LGService: Error stopping tour after orbit: $e');
          }
          return;
        }

        if (isMoving) return;

        try {
          isMoving = true;
          // Calculate heading
          double heading = (currentStep * (360.0 / steps)) % 360.0;
          await _flyToOrbit(latitude, longitude, range, tilt, heading);
          currentStep++;
          isMoving = false;
        } catch (e) {
          debugPrint('LGService: Error during orbit step $currentStep: $e');
          currentStep++;
          isMoving = false;
        }
      });
      return true;
    } catch (e) {
      _orbitPlaying = false;
      debugPrint('LGService: Error initializing orbit: $e');
      return false;
    }
  }

  /// Stops the currently streaming orbit.
  Future<void> orbitStop() async {
    _orbitTimer?.cancel();
    _orbitTimer = null;
    _orbitPlaying = false;
    await stopTour(); // stabilize
}
}

// ─── Provider ──────────────────────────────────────────────────────────

final lgServiceProvider = Provider<LGService>((ref) {
  return LGService(
    ref.watch(sshServiceProvider),
    ref.watch(settingsServiceProvider),
  );
});
