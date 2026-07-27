import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lg_interactive_onboarding/src/common/constants/app_constants.dart';

/// Manages persistent SSH connection and app settings.
class SettingsService {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;
  String _cachedPassword;
  String _cachedOpenRouterApiKey;
  String _cachedOpenRouterModel;

  SettingsService(this._prefs, this._secureStorage, this._cachedPassword, this._cachedOpenRouterApiKey, this._cachedOpenRouterModel);

  // ─── Keys ──────────────────────────────────────────────────────────
  static const _keyHost = 'host';
  static const _keyPort = 'port';
  static const _keyUsername = 'username';
  static const _keyPassword = 'password';
  static const _keyOpenRouterApiKey = 'openRouterApiKey';
  static const _keyOpenRouterModel = 'openRouterModel';
  static const _keyRigs = 'rigs';
  static const _keyThemeMode = 'themeMode';
  static const _keyVoiceNarration = 'voiceNarration';
  static const _keyTtsVoice = 'ttsVoice';

  // ─── Getters ───────────────────────────────────────────────────────
  String get host => _prefs.getString(_keyHost) ?? AppConstants.defaultSshHost;
  int get port => _prefs.getInt(_keyPort) ?? AppConstants.defaultSshPort;
  String get username => _prefs.getString(_keyUsername) ?? AppConstants.defaultSshUsername;
  String get password => _cachedPassword;
  String get openRouterApiKey => _cachedOpenRouterApiKey;
  String get openRouterModel => _cachedOpenRouterModel.isEmpty ? 'inclusionai/ling-3.0-flash:free' : _cachedOpenRouterModel;
  int get rigs => _prefs.getInt(_keyRigs) ?? AppConstants.defaultRigsCount;
  ThemeMode get themeMode => _parseThemeMode(_prefs.getString(_keyThemeMode));
  bool get voiceNarration => _prefs.getBool(_keyVoiceNarration) ?? true;
  String get ttsVoice => _prefs.getString(_keyTtsVoice) ?? '';

  // ─── Setters ───────────────────────────────────────────────────────
  Future<void> setHost(String value) => _prefs.setString(_keyHost, value);
  Future<void> setPort(int value) => _prefs.setInt(_keyPort, value);
  Future<void> setUsername(String value) =>
      _prefs.setString(_keyUsername, value);
  Future<void> setPassword(String value) async {
    _cachedPassword = value;
    await _secureStorage.write(key: _keyPassword, value: value);
  }
  Future<void> setOpenRouterApiKey(String value) async {
    _cachedOpenRouterApiKey = value;
    await _secureStorage.write(key: _keyOpenRouterApiKey, value: value);
  }
  Future<void> setOpenRouterModel(String value) async {
    _cachedOpenRouterModel = value;
    await _prefs.setString(_keyOpenRouterModel, value);
  }
  Future<void> setRigs(int value) => _prefs.setInt(_keyRigs, value);
  Future<void> setThemeMode(ThemeMode value) =>
      _prefs.setString(_keyThemeMode, value.name);
  Future<void> setVoiceNarration(bool value) =>
      _prefs.setBool(_keyVoiceNarration, value);
  Future<void> setTtsVoice(String value) =>
      _prefs.setString(_keyTtsVoice, value);

  ThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }
}

// ─── Providers ─────────────────────────────────────────────────────────

/// Must be overridden in main.dart with the actual instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize sharedPreferencesProvider in main.dart');
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  throw UnimplementedError('Initialize secureStorageProvider in main.dart');
});

final initialPasswordProvider = Provider<String>((ref) {
  throw UnimplementedError('Initialize initialPasswordProvider in main.dart');
});

final initialOpenRouterApiKeyProvider = Provider<String>((ref) {
  throw UnimplementedError('Initialize initialOpenRouterApiKeyProvider in main.dart');
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  final initialPassword = ref.watch(initialPasswordProvider);
  final initialOpenRouterApiKey = ref.watch(initialOpenRouterApiKeyProvider);
  final initialOpenRouterModel = prefs.getString('openRouterModel') ?? 'inclusionai/ling-3.0-flash:free';
  return SettingsService(prefs, secureStorage, initialPassword, initialOpenRouterApiKey, initialOpenRouterModel);
});

/// Theme mode notifier for dynamic theme switching.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final settings = ref.read(settingsServiceProvider);
    return settings.themeMode;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await ref.read(settingsServiceProvider).setThemeMode(mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
