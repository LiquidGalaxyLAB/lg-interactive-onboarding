import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/common/constants/app_constants.dart';

// ─── Technique 1: Make Invalid States Unrepresentable ──────────────────
//
// The connection lifecycle is a sealed class with exactly four cases.
// No combination of flags can drift out of sync because no flags exist.

/// Represents the mutually exclusive states of the SSH connection lifecycle.
sealed class SSHConnectionState {
  const SSHConnectionState();
}

/// No connection attempt has been made, or the previous connection was
/// cleanly disconnected.
final class SSHDisconnected extends SSHConnectionState {
  const SSHDisconnected();
}

/// A connection attempt is in progress (socket + handshake).
final class SSHConnecting extends SSHConnectionState {
  const SSHConnecting();
}

/// The SSH session is authenticated and ready to accept commands.
final class SSHConnected extends SSHConnectionState {
  const SSHConnected();
}

/// The most recent connection attempt failed, with a human-readable reason.
final class SSHConnectionError extends SSHConnectionState {
  final String message;
  const SSHConnectionError(this.message);
}

// ─── Technique 2: Define Errors Out of Existence ───────────────────────
//
// Every operation returns a sealed result. Callers never have to remember
// to catch exceptions or check for null; they pattern-match on the value.

/// The outcome of a single SSH command execution.
sealed class SSHExecResult {
  const SSHExecResult();
}

/// The command completed and produced output.
final class SSHExecSuccess extends SSHExecResult {
  final String stdout;
  final String stderr;
  const SSHExecSuccess({required this.stdout, required this.stderr});
}

/// The command could not be executed (not connected, channel error, etc.).
final class SSHExecFailure extends SSHExecResult {
  final String message;
  const SSHExecFailure(this.message);
}

/// The outcome of an SFTP upload operation.
sealed class SSHUploadResult {
  const SSHUploadResult();
}

/// The file was written to the remote path successfully.
final class SSHUploadSuccess extends SSHUploadResult {
  const SSHUploadSuccess();
}

/// The upload failed, with a human-readable reason.
final class SSHUploadFailure extends SSHUploadResult {
  final String message;
  const SSHUploadFailure(this.message);
}

// ─── SSH Service ───────────────────────────────────────────────────────

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

  // ─── Technique 1: Connection state ──────────────────────────────────

  SSHConnectionState _connectionState = const SSHDisconnected();

  /// The current connection state as a sealed algebraic type.
  /// Use pattern matching (`switch`) to handle each case exhaustively.
  SSHConnectionState get connectionState => _connectionState;

  /// Convenience getter retained for backward-compatibility with the ~50
  /// existing call-sites that read `ssh.isConnected` for UI gating.
  bool get isConnected =>
      _connectionState is SSHConnected &&
      _client != null &&
      !(_client!.isClosed);

  // ─── Technique 3: Async Staleness Guard ─────────────────────────────
  //
  // Every connect() call increments a generation counter. After the async
  // handshake completes, the result is applied only if the generation
  // still matches — preventing a slow first attempt from overwriting a
  // fast second attempt (the exact race from the spec).

  int _connectionGeneration = 0;

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
  ///
  /// Returns the resulting [SSHConnectionState]. If another `connect()` call
  /// is made before this one completes, this call's result is discarded (the
  /// generation guard ensures the latest call always wins).
  Future<SSHConnectionState> connect({
    required String host,
    required int port,
    required String username,
    required String password,
  }) async {
    // Capture a new generation — any earlier in-flight connect is now stale.
    final generation = ++_connectionGeneration;

    _connectionState = const SSHConnecting();
    notifyListeners();

    try {
      final socket = await SSHSocket.connect(
        host,
        port,
        timeout: AppConstants.sshConnectionTimeout,
      );
      final client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
      );

      // Wait for the SSH handshake and authentication to complete.
      // Without this, connection drops or bad passwords throw unhandled async exceptions.
      await client.authenticated;

      // ── Generation check: discard if superseded ──────────────────
      if (generation != _connectionGeneration) {
        debugPrint('SSH: Discarding stale connection to $host '
            '(generation $generation, current $_connectionGeneration)');
        client.close();
        // Return the *current* state (which was set by the newer call).
        return _connectionState;
      }

      _client = client;

      // Listen for unexpected connection drops (e.g., when rig reboots).
      // We must catch errors on the done future, otherwise socket aborts will crash the app.
      _client!.done.catchError((e) {
        debugPrint('SSH: Socket error: $e');
      }).whenComplete(() {
        if (_client != null) {
          debugPrint('SSH: Connection closed unexpectedly');
          _client = null;
          _sftpFuture = null;
          _connectionState = const SSHDisconnected();
          notifyListeners();
        }
      });

      // Reset execution queue for the new connection.
      _execQueue = Future.value();
      _connectionState = const SSHConnected();
      debugPrint('SSH: Connected to $host');
      notifyListeners();
      return _connectionState;
    } catch (e) {
      // ── Generation check: discard if superseded ──────────────────
      if (generation != _connectionGeneration) {
        debugPrint('SSH: Discarding stale connection error for $host');
        return _connectionState;
      }

      final errorState = SSHConnectionError('$e');
      _connectionState = errorState;
      debugPrint('SSH: Connection failed: $e');
      notifyListeners();
      return errorState;
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
    _connectionState = const SSHDisconnected();
    debugPrint('SSH: Disconnected');
    notifyListeners();
  }

  /// Executes a command on the remote server and returns an [SSHExecResult].
  ///
  /// All calls are serialized: the next command waits until the previous
  /// one finishes AND a short cooldown elapses. This prevents the server
  /// from running out of session channel slots (OpenSSH MaxSessions=10).
  Future<SSHExecResult> execute(String command) async {
    if (!isConnected) {
      debugPrint('SSH: Not connected, cannot execute: $command');
      return SSHExecFailure('Not connected');
    }

    final completer = Completer<SSHExecResult>();

    // Chain onto the queue — this call waits until all previous calls finish.
    final previous = _execQueue;
    _execQueue = completer.future.then((_) async {
      // Post-command cooldown: give the server time to release the channel.
      await Future.delayed(const Duration(milliseconds: 200));
    });

    // Wait for the previous command to finish (including its cooldown).
    await previous;

    if (!isConnected) {
      const failure = SSHExecFailure('Connection lost during queue wait');
      completer.complete(failure);
      return failure;
    }

    try {
      final result = await _client!.run(command);
      final success = SSHExecSuccess(
        stdout: String.fromCharCodes(result),
        stderr: '',
      );
      completer.complete(success);
      return success;
    } catch (e) {
      debugPrint('SSH: Execution failed: $e');
      final failure = SSHExecFailure('$e');
      completer.complete(failure);
      return failure;
    }
  }

  /// Uploads a file to the remote server via SFTP.
  Future<SSHUploadResult> uploadFile({
    required String localData,
    required String remotePath,
  }) async {
    if (!isConnected) {
      debugPrint('SSH: Not connected, cannot upload to $remotePath');
      return SSHUploadFailure('Not connected');
    }

    try {
      final sftpClient = await sftp;
      if (sftpClient == null) {
        return const SSHUploadFailure('Failed to open SFTP channel');
      }

      final file = await sftpClient.open(
        remotePath,
        mode:
            SftpFileOpenMode.create |
            SftpFileOpenMode.truncate |
            SftpFileOpenMode.write,
      );
      final bytes = Uint8List.fromList(localData.codeUnits);
      await file.write(_chunkedStream(bytes));
      await file.close();
      debugPrint('SSH: File uploaded to $remotePath');
      return const SSHUploadSuccess();
    } catch (e) {
      debugPrint('SSH: SFTP upload failed: $e');
      return SSHUploadFailure('$e');
    }
  }

  /// Uploads raw bytes to the remote server via SFTP.
  Future<SSHUploadResult> uploadBytes({
    required Uint8List bytes,
    required String remotePath,
  }) async {
    if (!isConnected) {
      debugPrint('SSH: Not connected, cannot upload to $remotePath');
      return SSHUploadFailure('Not connected');
    }

    try {
      final sftpClient = await sftp;
      if (sftpClient == null) {
        return const SSHUploadFailure('Failed to open SFTP channel');
      }

      final file = await sftpClient.open(
        remotePath,
        mode:
            SftpFileOpenMode.create |
            SftpFileOpenMode.truncate |
            SftpFileOpenMode.write,
      );
      await file.write(_chunkedStream(bytes));
      await file.close();
      debugPrint('SSH: Bytes uploaded to $remotePath (${bytes.length} bytes)');
      return const SSHUploadSuccess();
    } catch (e) {
      debugPrint('SSH: SFTP bytes upload failed: $e');
      return SSHUploadFailure('$e');
    }
  }

  /// Helper to split large files into safe SFTP chunks (32KB is standard max)
  /// to prevent the SSH server from forcibly dropping the connection.
  Stream<Uint8List> _chunkedStream(Uint8List bytes, [int chunkSize = 32768]) async* {
    int offset = 0;
    while (offset < bytes.length) {
      final int length = (bytes.length - offset < chunkSize) ? bytes.length - offset : chunkSize;
      yield bytes.sublist(offset, offset + length);
      offset += length;
    }
  }
}

/// Global SSH service provider.
final sshServiceProvider = Provider<SSHService>((ref) {
  return SSHService();
});
