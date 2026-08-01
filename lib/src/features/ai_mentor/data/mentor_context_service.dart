import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';
import 'package:lg_interactive_onboarding/src/features/settings/data/settings_service.dart';
import 'package:lg_interactive_onboarding/src/common/curriculum/guided_mode_controller.dart';
import 'package:lg_interactive_onboarding/src/app_shell.dart';

/// Builds a JSON-serializable snapshot of the app's current state.
///
/// This context is injected into every API call so the AI mentor can give
/// hyper-relevant, contextual advice without the user having to explain
/// what screen they are on or what they are doing.
class MentorContextService {
  final Ref _ref;

  MentorContextService(this._ref);

  /// Returns a map describing the app's current state for the AI mentor.
  Map<String, dynamic> buildContext() {
    final ssh = _ref.read(sshServiceProvider);
    final settings = _ref.read(settingsServiceProvider);
    final guided = _ref.read(guidedModeControllerProvider);
    final tabIndex = _ref.read(shellTabIndexProvider);

    return {
      'currentScreen': _screenName(tabIndex),
      'sshStatus': _sshStatusString(ssh.connectionState),
      'sshHost': settings.host,
      'sshPort': settings.port,
      'rigsCount': settings.rigs,
      'activeModule': guided.activeModule?.title,
      'guidedModePhase': guided.phase.name,
      'currentStepInstruction': guided.currentStep?.instruction,
    };
  }

  /// Maps the shell tab index to a human-readable screen name.
  String _screenName(int index) {
    switch (index) {
      case 0:
        return 'Home (Dashboard)';
      case 1:
        return 'Learn (Curriculum)';
      case 2:
        return 'AI Mentor';
      default:
        return 'Unknown';
    }
  }

  /// Converts the sealed [SSHConnectionState] to a readable string.
  String _sshStatusString(SSHConnectionState state) {
    return switch (state) {
      SSHDisconnected() => 'disconnected',
      SSHConnecting() => 'connecting',
      SSHConnected() => 'connected',
      SSHConnectionError(message: final msg) => 'error: $msg',
    };
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final mentorContextServiceProvider = Provider<MentorContextService>((ref) {
  return MentorContextService(ref);
});
