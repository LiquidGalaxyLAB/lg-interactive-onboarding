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
  String _cachedGeminiApiKey;
  String _cachedGeminiModel;

  SettingsService(this._prefs, this._secureStorage, this._cachedPassword, this._cachedGeminiApiKey, this._cachedGeminiModel);

  // ─── Keys ──────────────────────────────────────────────────────────
  static const _keyHost = 'host';
  static const _keyPort = 'port';
  static const _keyUsername = 'username';
  static const _keyPassword = 'password';
  static const _keyGeminiApiKey = 'geminiApiKey';
  static const _keyGeminiModel = 'geminiModel';
  static const _keyRigs = 'rigs';
  static const _keyThemeMode = 'themeMode';
  static const _keyVoiceNarration = 'voiceNarration';

  // ─── Getters ───────────────────────────────────────────────────────
  String get host => _prefs.getString(_keyHost) ?? AppConstants.defaultSshHost;
  int get port => _prefs.getInt(_keyPort) ?? AppConstants.defaultSshPort;
  String get username => _prefs.getString(_keyUsername) ?? AppConstants.defaultSshUsername;
  String get password => _cachedPassword;
  String get geminiApiKey => _cachedGeminiApiKey;
  String get geminiModel => _cachedGeminiModel.isEmpty ? 'google/gemini-2.5-flash:free' : _cachedGeminiModel;
  int get rigs => _prefs.getInt(_keyRigs) ?? AppConstants.defaultRigsCount;
  ThemeMode get themeMode => _parseThemeMode(_prefs.getString(_keyThemeMode));
  bool get voiceNarration => _prefs.getBool(_keyVoiceNarration) ?? true;

  // ─── Setters ───────────────────────────────────────────────────────
  Future<void> setHost(String value) => _prefs.setString(_keyHost, value);
  Future<void> setPort(int value) => _prefs.setInt(_keyPort, value);
  Future<void> setUsername(String value) =>
      _prefs.setString(_keyUsername, value);
  Future<void> setPassword(String value) async {
    _cachedPassword = value;
    await _secureStorage.write(key: _keyPassword, value: value);
  }
  Future<void> setGeminiApiKey(String value) async {
    _cachedGeminiApiKey = value;
    await _secureStorage.write(key: _keyGeminiApiKey, value: value);
  }
  Future<void> setGeminiModel(String value) async {
    _cachedGeminiModel = value;
    await _prefs.setString(_keyGeminiModel, value);
  }
  Future<void> setRigs(int value) => _prefs.setInt(_keyRigs, value);
  Future<void> setThemeMode(ThemeMode value) =>
      _prefs.setString(_keyThemeMode, value.name);
  Future<void> setVoiceNarration(bool value) =>
      _prefs.setBool(_keyVoiceNarration, value);

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

final initialGeminiApiKeyProvider = Provider<String>((ref) {
  throw UnimplementedError('Initialize initialGeminiApiKeyProvider in main.dart');
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  final initialPassword = ref.watch(initialPasswordProvider);
  final initialGeminiApiKey = ref.watch(initialGeminiApiKeyProvider);
  final initialGeminiModel = prefs.getString('geminiModel') ?? 'google/gemini-2.5-flash:free';
  return SettingsService(prefs, secureStorage, initialPassword, initialGeminiApiKey, initialGeminiModel);
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
