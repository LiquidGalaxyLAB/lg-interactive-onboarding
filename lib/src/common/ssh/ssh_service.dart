
import 'dart:async';


import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SSHService {
  SSHClient? _client;

  SSHClient? get client => _client;

  bool get isConnected => _client != null && !(_client!.isClosed);

  Future<bool> connect({
    required String host,
    required int port,
    required String username,
    required String password,
  }) async {
    try {
      final socket = await SSHSocket.connect(host, port, timeout: const Duration(seconds: 10));
      _client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
      );
      debugPrint('SSH: Connected to $host');
      return true;
    } catch (e) {
      debugPrint('SSH: Connection failed: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    _client?.close();
    _client = null;
    debugPrint('SSH: Disconnected');
  }

  /// Executes a command on the remote server.
  /// 
  /// Adheres to the GOLDEN RULE: Always use client!.run() directly.
  /// This wrapper is mainly for convenience when no complex chaining is needed,
  /// but for complex flows, access client directly.
  Future<SSHResult?> execute(String command) async {
    if (!isConnected) {
      debugPrint('SSH: Not connected, cannot execute: $command');
      return null;
    }

    try {
      final result = await _client!.run(command);
      return SSHResult(
        stdout: String.fromCharCodes(result),
        stderr: '', // dartssh2 run returns bytes of stdout. Stderr is separate if using execute(). 
                    // run() is a convenience for simple execution.
      );
    } catch (e) {
      debugPrint('SSH: Execution failed: $e');
      return null;
    }
  }
}

class SSHResult {
  final String stdout;
  final String stderr;

  SSHResult({required this.stdout, required this.stderr});
}

final sshServiceProvider = Provider<SSHService>((ref) {
  return SSHService();
});
