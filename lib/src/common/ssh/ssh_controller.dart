import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';
import 'package:lg_interactive_onboarding/src/features/home/data/lg_service.dart';

class SSHConnectionState {
  final String host;
  final int port;
  final String username;
  final String password;
  final int rigs;
  final bool isConnected;
  final bool isLoading;
  final String? errorMessage;
  final String? statusMessage;
  final List<String> logs;

  SSHConnectionState({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.rigs,
    this.isConnected = false,
    this.isLoading = false,
    this.errorMessage,
    this.statusMessage,
    this.logs = const [],
  });

  SSHConnectionState copyWith({
    String? host,
    int? port,
    String? username,
    String? password,
    int? rigs,
    bool? isConnected,
    bool? isLoading,
    String? errorMessage,
    String? statusMessage,
    List<String>? logs,
  }) {
    return SSHConnectionState(
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      rigs: rigs ?? this.rigs,
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      statusMessage: statusMessage,
      logs: logs ?? this.logs,
    );
  }
}

class SSHController extends StateNotifier<SSHConnectionState> {
  final SSHService _sshService;
  final LGService _lgService;

  SSHController(this._sshService, this._lgService)
      : super(SSHConnectionState(
          host: '',
          port: 22,
          username: 'lg',
          password: '',
          rigs: 3,
          logs: const [],
        )) {
    _loadSettings();
  }

  static const _keyHost = 'ssh_host';
  static const _keyPort = 'ssh_port';
  static const _keyUsername = 'ssh_username';
  static const _keyPassword = 'ssh_password';
  static const _keyRigs = 'ssh_rigs';

  void _addLog(String message) {
    final timestamp = DateTime.now().toLocal().toString().split(' ')[1].substring(0, 8);
    state = state.copyWith(logs: [...state.logs, '[$timestamp] $message']);
  }

  void clearLogs() {
    state = state.copyWith(logs: []);
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final host = prefs.getString(_keyHost) ?? '192.168.0.1';
      final port = prefs.getInt(_keyPort) ?? 22;
      final username = prefs.getString(_keyUsername) ?? 'lg';
      final password = prefs.getString(_keyPassword) ?? 'lg';
      final rigs = prefs.getInt(_keyRigs) ?? 3;

      state = SSHConnectionState(
        host: host,
        port: port,
        username: username,
        password: password,
        rigs: rigs,
        logs: state.logs,
      );
      _addLog('Loaded saved settings from persistent storage.');
    } catch (e) {
      _addLog('Error loading settings: $e');
    }
  }

  Future<void> saveSettings({
    required String host,
    required int port,
    required String username,
    required String password,
    required int rigs,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyHost, host);
      await prefs.setInt(_keyPort, port);
      await prefs.setString(_keyUsername, username);
      await prefs.setString(_keyPassword, password);
      await prefs.setInt(_keyRigs, rigs);

      state = state.copyWith(
        host: host,
        port: port,
        username: username,
        password: password,
        rigs: rigs,
      );
      _addLog('Saved settings successfully.');
    } catch (e) {
      _addLog('Error saving settings: $e');
    }
  }

  Future<bool> connect() async {
    state = state.copyWith(isLoading: true, errorMessage: null, statusMessage: 'Connecting...');
    _addLog('Connecting to ${state.host}:${state.port} as "${state.username}"...');
    
    final success = await _sshService.connect(
      host: state.host,
      port: state.port,
      username: state.username,
      password: state.password,
    );

    if (success) {
      state = state.copyWith(
        isConnected: true,
        isLoading: false,
        statusMessage: 'Connected successfully',
      );
      _addLog('SSH Connection established.');
      return true;
    } else {
      state = state.copyWith(
        isConnected: false,
        isLoading: false,
        errorMessage: 'Connection failed. Please check host details or network status.',
      );
      _addLog('SSH Connection failed.');
      return false;
    }
  }

  Future<void> disconnect() async {
    state = state.copyWith(isLoading: true, statusMessage: 'Disconnecting...');
    _addLog('Disconnecting from remote host...');
    await _sshService.disconnect();
    state = state.copyWith(
      isConnected: false,
      isLoading: false,
      statusMessage: 'Disconnected',
    );
    _addLog('SSH connection closed.');
  }

  Future<void> shutdown() async {
    if (!state.isConnected) return;
    state = state.copyWith(isLoading: true, statusMessage: 'Shutting down LG rigs...');
    _addLog('Starting shutdown sequence for ${state.rigs} rigs...');
    
    final success = await _lgService.shutdown(rigs: state.rigs, password: state.password);
    state = state.copyWith(
      isLoading: false,
      statusMessage: success ? 'Shutdown commands sent' : 'Shutdown failed',
      errorMessage: success ? null : 'Failed to send shutdown commands',
    );
    if (success) {
      _addLog('Shutdown commands dispatched to lg1 through lg${state.rigs}.');
    } else {
      _addLog('Shutdown sequence encountered errors.');
    }
  }

  Future<void> reboot() async {
    if (!state.isConnected) return;
    state = state.copyWith(isLoading: true, statusMessage: 'Rebooting LG rigs...');
    _addLog('Starting reboot sequence for ${state.rigs} rigs...');

    final success = await _lgService.reboot(rigs: state.rigs, password: state.password);
    state = state.copyWith(
      isLoading: false,
      statusMessage: success ? 'Reboot commands sent' : 'Reboot failed',
      errorMessage: success ? null : 'Failed to send reboot commands',
    );
    if (success) {
      _addLog('Reboot commands dispatched to lg1 through lg${state.rigs}.');
    } else {
      _addLog('Reboot sequence encountered errors.');
    }
  }

  Future<void> relaunch() async {
    if (!state.isConnected) return;
    state = state.copyWith(isLoading: true, statusMessage: 'Relaunching LG applications...');
    _addLog('Starting relaunch sequence from lg${state.rigs} down to lg1...');

    final success = await _lgService.relaunch(rigs: state.rigs, password: state.password);
    state = state.copyWith(
      isLoading: false,
      statusMessage: success ? 'Relaunch commands sent' : 'Relaunch failed',
      errorMessage: success ? null : 'Failed to send relaunch commands',
    );
    if (success) {
      _addLog('Relaunch script successfully run on all rigs.');
    } else {
      _addLog('Relaunch sequence encountered errors.');
    }
  }
}

final sshControllerProvider = StateNotifierProvider<SSHController, SSHConnectionState>((ref) {
  final sshService = ref.watch(sshServiceProvider);
  final lgService = ref.watch(lgServiceProvider);
  return SSHController(sshService, lgService);
});
