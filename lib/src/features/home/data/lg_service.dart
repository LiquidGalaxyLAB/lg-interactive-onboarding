import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';

class LGService {
  final SSHService _sshService;

  LGService(this._sshService);

  /// Helper to get the SSH client or return false if not connected.
  Future<bool> _ensureConnection() async {
    if (_sshService.client == null || _sshService.client!.isClosed) {
      debugPrint('LGService: SSH not connected');
      return false;
    }
    return true;
  }

  /// Shuts down all rigs.
  Future<bool> shutdown({required int rigs, required String password}) async {
    if (!await _ensureConnection()) return false;

    try {
      final client = _sshService.client!;
      for (var i = rigs; i >= 1; i--) {
        final command = 'sshpass -p "$password" ssh -o StrictHostKeyChecking=no lg$i "(echo $password; sleep 1) | sudo -S poweroff"';
        debugPrint('Executing shutdown on lg$i...');
        await client.run(command);
      }
      return true;
    } catch (e) {
      debugPrint('Shutdown failed: $e');
      return false;
    }
  }

  /// Reboots all rigs.
  Future<bool> reboot({required int rigs, required String password}) async {
    if (!await _ensureConnection()) return false;

    try {
      final client = _sshService.client!;
      for (var i = rigs; i >= 1; i--) {
        final command = 'sshpass -p "$password" ssh -o StrictHostKeyChecking=no lg$i "(echo $password; sleep 1) | sudo -S reboot"';
        debugPrint('Executing reboot on lg$i...');
        await client.run(command);
      }
      return true;
    } catch (e) {
      debugPrint('Reboot failed: $e');
      return false;
    }
  }

  /// Relaunches the Liquid Galaxy application.
  Future<bool> relaunch({required int rigs, required String password}) async {
    if (!await _ensureConnection()) return false;

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
        debugPrint('Executing relaunch on lg$i...');
        await client.run(command);
      }
      return true;
    } catch (e) {
      debugPrint('Relaunch failed: $e');
      return false;
    }
  }
}

final lgServiceProvider = Provider<LGService>((ref) {
  final sshService = ref.watch(sshServiceProvider);
  return LGService(sshService);
});
