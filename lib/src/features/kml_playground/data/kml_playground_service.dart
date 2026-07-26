import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/common/constants/app_constants.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/system_kml_service.dart';

class KmlPlaygroundService {
  final SSHService _sshService;
  final SystemKmlService _systemKmlService;

  KmlPlaygroundService(this._sshService, this._systemKmlService);

  bool get _isReady => _sshService.isConnected;

  /// Sends a KML string to the master screen by uploading it to
  /// /var/www/html/kml/playground.kml and triggering a refresh.
  Future<bool> sendKml(String kmlString) async {
    if (!_isReady) return false;

    try {
      final result = await _sshService.uploadFile(
        localData: kmlString,
        remotePath: '/var/www/html/kml/playground.kml',
      );

      if (result is SSHUploadFailure) {
        debugPrint('KmlPlaygroundService: Send KML upload failed: ${result.message}');
        return false;
      }

      await Future.delayed(AppConstants.kmlRefreshDelay);
      final refreshOk = await _systemKmlService.forceRefreshAll();
      
      if (!refreshOk) {
        debugPrint('KmlPlaygroundService: Refresh failed after sending KML');
        return false;
      }

      debugPrint('KmlPlaygroundService: KML sent to master');
      return true;
    } catch (e) {
      debugPrint('KmlPlaygroundService: Send KML failed: $e');
      return false;
    }
  }

  /// Clears all KML from the playground by writing an empty KML
  /// to /var/www/html/kml/playground.kml.
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
        remotePath: '/var/www/html/kml/playground.kml',
      );

      // Delay before refresh to avoid SSH channel exhaustion
      await Future.delayed(AppConstants.kmlClearDelay);
      final refreshOk = await _systemKmlService.forceRefreshAll();
      
      if (!refreshOk) {
        debugPrint('KmlPlaygroundService: Refresh failed after clearing KML');
        return false;
      }

      debugPrint('KmlPlaygroundService: KML cleared');
      return true;
    } catch (e) {
      debugPrint('KmlPlaygroundService: Clear KML failed: $e');
      return false;
    }
  }
}

final kmlPlaygroundServiceProvider = Provider<KmlPlaygroundService>((ref) {
  return KmlPlaygroundService(
    ref.watch(sshServiceProvider),
    ref.watch(systemKmlServiceProvider),
  );
});
