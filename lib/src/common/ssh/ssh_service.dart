import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:lg_interactive_onboarding/src/common/constants/app_constants.dart';

/// Core SSH service for connecting to the Liquid Galaxy master node.
///
/// Follows the GOLDEN RULE: Always use client!.run() directly for
/// simple commands. For complex flows, access the client directly.
class SSHService extends ChangeNotifier {
  SSHClient? _client;
  SftpClient? _sftp;

  SSHClient? get client => _client;

  bool get isConnected => _client != null && !(_client!.isClosed);

  /// Gets or creates a reusable SFTP client for the current session.
  /// Reusing the client prevents SSH channel exhaustion when pushing multiple files.
  Future<SftpClient?> get sftp async {
    if (!isConnected) return null;
    if (_sftp == null) {
      _sftp = await _client!.sftp();
    }
    return _sftp;
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
    _sftp?.close();
    _sftp = null;
    _client?.close();
    _client = null;
    debugPrint('SSH: Disconnected');
    notifyListeners();
  }

  /// Executes a command on the remote server and returns stdout.
  Future<SSHResult?> execute(String command) async {
    if (!isConnected) {
      debugPrint('SSH: Not connected, cannot execute: $command');
      return null;
    }

    try {
      final result = await _client!.run(command);
      return SSHResult(
        stdout: String.fromCharCodes(result),
        stderr: '',
      );
    } catch (e) {
      debugPrint('SSH: Execution failed: $e');
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
        mode: SftpFileOpenMode.create |
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
        mode: SftpFileOpenMode.create |
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
