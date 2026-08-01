import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';
import 'package:lg_interactive_onboarding/src/app_shell.dart';
import 'package:lg_interactive_onboarding/src/features/ai_mentor/data/mentor_service.dart';

/// Monitors app state for situations where the AI Mentor should proactively
/// offer help — e.g. repeated SSH failures, long dwell times, or first launch.
///
/// When a trigger fires, it sends a hidden system prompt to [MentorService],
/// which makes the AI generate a helpful, contextual message as if it
/// noticed the user is struggling.
class ProactiveTriggerService {
  final Ref _ref;

  /// Counts consecutive SSH connection errors.
  int _sshFailCount = 0;

  /// Tracks when the user entered the current tab.
  DateTime? _tabEnteredAt;
  int _lastTabIndex = -1;
  Timer? _dwellTimer;

  /// Prevents the same trigger from firing more than once per session.
  final Set<String> _firedTriggers = {};

  ProactiveTriggerService(this._ref) {
    _watchSshState();
    _watchTabChanges();
  }

  // ─── SSH Failure Trigger ──────────────────────────────────────────────────

  void _watchSshState() {
    _ref.listen<SSHService>(sshServiceProvider, (previous, next) {
      final state = next.connectionState;

      if (state is SSHConnectionError) {
        _sshFailCount++;
        debugPrint(
          'ProactiveTrigger: SSH failure #$_sshFailCount — ${state.message}',
        );

        if (_sshFailCount >= 3 && !_firedTriggers.contains('ssh_fail_3')) {
          _firedTriggers.add('ssh_fail_3');
          _fireTrigger(
            'The user has failed to connect via SSH $_sshFailCount times in a row. '
            'The last error was: "${state.message}". '
            'Proactively offer troubleshooting help. Ask them to double-check '
            'the IP address, ensure the LG rig is powered on and reachable, '
            'and verify the password. Be empathetic and encouraging.',
          );
        }
      } else if (state is SSHConnected) {
        // Reset on successful connection.
        _sshFailCount = 0;
      }
    });
  }

  // ─── Screen Dwell Time Trigger ────────────────────────────────────────────

  void _watchTabChanges() {
    _ref.listen<int>(shellTabIndexProvider, (previous, next) {
      _dwellTimer?.cancel();
      _lastTabIndex = next;
      _tabEnteredAt = DateTime.now();

      // Only set dwell timer for the Home tab (index 0) where Settings
      // access is likely — the user might be struggling with setup.
      if (next == 0) {
        _dwellTimer = Timer(const Duration(minutes: 3), () {
          _checkDwell();
        });
      }
    });
  }

  void _checkDwell() {
    if (_lastTabIndex != 0) return;
    if (_firedTriggers.contains('dwell_home')) return;

    final ssh = _ref.read(sshServiceProvider);
    if (ssh.isConnected) return; // No need to nudge if already connected.

    final entered = _tabEnteredAt;
    if (entered == null) return;
    final elapsed = DateTime.now().difference(entered);
    if (elapsed.inMinutes < 3) return;

    _firedTriggers.add('dwell_home');
    _fireTrigger(
      'The user has been on the Home screen for over 3 minutes without '
      'establishing an SSH connection. Gently ask if they need help '
      'getting started. Suggest they go to Settings to configure the '
      'connection, or explore the Learn tab for guided tutorials.',
    );
  }

  // ─── Fire Trigger ─────────────────────────────────────────────────────────

  void _fireTrigger(String prompt) {
    debugPrint('ProactiveTrigger: Firing trigger');
    final mentor = _ref.read(mentorServiceProvider);
    mentor.sendSystemTrigger(prompt);
  }

  /// Resets all trigger counters and fired flags.
  /// Useful if the user explicitly reconnects or restarts their session.
  void resetTriggers() {
    _sshFailCount = 0;
    _firedTriggers.clear();
    _dwellTimer?.cancel();
  }

  /// Disposes timers. Call when the service is no longer needed.
  void dispose() {
    _dwellTimer?.cancel();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

/// Activating this provider (e.g., via `ref.read(proactiveTriggerProvider)`)
/// starts the background observation. It should be activated once in main.dart
/// or app_shell.dart, similar to `logoConnectionWatcherProvider`.
final proactiveTriggerProvider = Provider<ProactiveTriggerService>((ref) {
  final service = ProactiveTriggerService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
