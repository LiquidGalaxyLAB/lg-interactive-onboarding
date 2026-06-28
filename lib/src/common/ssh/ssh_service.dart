import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/common/constants/app_constants.dart';

/// Core SSH service for connecting to the Liquid Galaxy master node.
///
/// All command execution is serialized through [execute] to prevent
/// SSH channel exhaustion. All file transfers go through the cached
/// SFTP channel via [sftp]. Never call `client!.run()` directly from
/// outside this class.
class SSHService extends ChangeNotifier {
  SSHClient? _client;
  Future<SftpClient>? _sftpFuture;

  /// Serialization lock for exec channels — ensures only ONE exec session
  /// channel is open at a time. Each `client.run()` opens a new SSH session
  /// channel; without serialization, rapid repeated operations exhaust the
  /// server's MaxSessions limit (default 10).
  Future<void> _execQueue = Future.value();

  SSHClient? get client => _client;

  bool get isConnected => _client != null && !(_client!.isClosed);

  /// Gets or creates a reusable SFTP client for the current session.
  /// Reusing the client prevents SSH channel exhaustion when pushing multiple files.
  Future<SftpClient?> get sftp async {
    if (!isConnected) return null;
    _sftpFuture ??= _client!.sftp();
    try {
      return await _sftpFuture;
    } catch (e) {
      _sftpFuture = null;
      debugPrint('SSH: Failed to open SFTP channel: $e');
      return null;
    }
  }

  /// Connects to the SSH server.
  Future<bool> connect({
    required String host,
    required int port,
    required String username,
    required String password,
  }) async {
    try {
      final socket = await SSHSocket.connect(
        host,
        port,
        timeout: AppConstants.sshConnectionTimeout,
      );
      _client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
      );

      // Wait for the SSH handshake and authentication to complete.
      // Without this, connection drops or bad passwords throw unhandled async exceptions.
      await _client!.authenticated;

      // Listen for unexpected connection drops (e.g., when rig reboots).
      _client!.done.whenComplete(() {
        if (_client != null) {
          debugPrint('SSH: Connection closed unexpectedly');
          _client = null;
          _sftpFuture = null;
          notifyListeners();
        }
      });

      // Reset execution queue for the new connection.
      _execQueue = Future.value();
      debugPrint('SSH: Connected to $host');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('SSH: Connection failed: $e');
      notifyListeners();
      return false;
    }
  }

  /// Disconnects from the SSH server.
  Future<void> disconnect() async {
    try {
      final sftpClient = await _sftpFuture;
      sftpClient?.close();
    } catch (_) {}
    _sftpFuture = null;
    _client?.close();
    _client = null;
    _execQueue = Future.value();
    debugPrint('SSH: Disconnected');
    notifyListeners();
  }

  /// Executes a command on the remote server and returns stdout.
  ///
  /// All calls are serialized: the next command waits until the previous
  /// one finishes AND a short cooldown elapses. This prevents the server
  /// from running out of session channel slots (OpenSSH MaxSessions=10).
  Future<SSHResult?> execute(String command) async {
    if (!isConnected) {
      debugPrint('SSH: Not connected, cannot execute: $command');
      return null;
    }

    final completer = Completer<SSHResult?>();

    // Chain onto the queue — this call waits until all previous calls finish.
    final previous = _execQueue;
    _execQueue = completer.future.then((_) async {
      // Post-command cooldown: give the server time to release the channel.
      await Future.delayed(const Duration(milliseconds: 200));
    });

    // Wait for the previous command to finish (including its cooldown).
    await previous;

    if (!isConnected) {
      completer.complete(null);
      return null;
    }

    try {
      final result = await _client!.run(command);
      final sshResult = SSHResult(
        stdout: String.fromCharCodes(result),
        stderr: '',
      );
      completer.complete(sshResult);
      return sshResult;
    } catch (e) {
      debugPrint('SSH: Execution failed: $e');
      completer.complete(null);
      return null;
    }
  }

  /// Uploads a file to the remote server via SFTP.
  Future<bool> uploadFile({
    required String localData,
    required String remotePath,
  }) async {
    if (!isConnected) {
      debugPrint('SSH: Not connected, cannot upload to $remotePath');
      return false;
    }

    try {
      final sftpClient = await sftp;
      if (sftpClient == null) return false;

      final file = await sftpClient.open(
        remotePath,
        mode:
            SftpFileOpenMode.create |
            SftpFileOpenMode.truncate |
            SftpFileOpenMode.write,
      );
      final bytes = Uint8List.fromList(localData.codeUnits);
      await file.write(Stream.value(bytes));
      await file.close();
      debugPrint('SSH: File uploaded to $remotePath');
      return true;
    } catch (e) {
      debugPrint('SSH: SFTP upload failed: $e');
      return false;
    }
  }

  /// Uploads raw bytes to the remote server via SFTP.
  Future<bool> uploadBytes({
    required Uint8List bytes,
    required String remotePath,
  }) async {
    if (!isConnected) {
      debugPrint('SSH: Not connected, cannot upload to $remotePath');
      return false;
    }

    try {
      final sftpClient = await sftp;
      if (sftpClient == null) return false;

      final file = await sftpClient.open(
        remotePath,
        mode:
            SftpFileOpenMode.create |
            SftpFileOpenMode.truncate |
            SftpFileOpenMode.write,
      );
      await file.write(Stream.value(bytes));
      await file.close();
      debugPrint('SSH: Bytes uploaded to $remotePath (${bytes.length} bytes)');
      return true;
    } catch (e) {
      debugPrint('SSH: SFTP bytes upload failed: $e');
      return false;
    }
  }
}

/// Encapsulates the result of an SSH command execution.
class SSHResult {
  final String stdout;
  final String stderr;

  SSHResult({required this.stdout, required this.stderr});
}

/// Global SSH service provider.
final sshServiceProvider = Provider<SSHService>((ref) {
  return SSHService();
});
