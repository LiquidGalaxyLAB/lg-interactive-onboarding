import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lg_interactive_onboarding/src/common/constants/app_constants.dart';

enum LLMProviderType { openRouter, gemini, openAI, claude, ollama, groq }

/// Manages persistent SSH connection and app settings.
class SettingsService {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;
  String _cachedPassword;
  String _cachedOpenRouterApiKey;
  String _cachedGeminiApiKey;
  String _cachedOpenAIApiKey;
  String _cachedClaudeApiKey;
  String _cachedGroqApiKey;

  SettingsService(
    this._prefs,
    this._secureStorage,
    this._cachedPassword,
    this._cachedOpenRouterApiKey,
    this._cachedGeminiApiKey,
    this._cachedOpenAIApiKey,
    this._cachedClaudeApiKey,
    this._cachedGroqApiKey,
  );

  // ─── Keys ──────────────────────────────────────────────────────────
  static const _keyHost = 'host';
  static const _keyPort = 'port';
  static const _keyUsername = 'username';
  static const _keyPassword = 'password';
  
  static const _keyLlmProvider = 'llmProvider';
  
  static const _keyOpenRouterApiKey = 'openRouterApiKey';
  static const _keyOpenRouterModel = 'openRouterModel';
  
  static const _keyGeminiApiKey = 'geminiApiKey';
  static const _keyGeminiModel = 'geminiModel';
  
  static const _keyOpenAIApiKey = 'openAIApiKey';
  static const _keyOpenAIModel = 'openAIModel';
  
  static const _keyClaudeApiKey = 'claudeApiKey';
  static const _keyClaudeModel = 'claudeModel';
  
  static const _keyOllamaBaseUrl = 'ollamaBaseUrl';
  static const _keyOllamaModel = 'ollamaModel';
  
  static const _keyGroqApiKey = 'groqApiKey';
  static const _keyGroqModel = 'groqModel';

  static const _keyRigs = 'rigs';
  static const _keyThemeMode = 'themeMode';
  static const _keyVoiceNarration = 'voiceNarration';
  static const _keyTtsVoice = 'ttsVoice';

  // ─── Getters ───────────────────────────────────────────────────────
  String _getStringWithDefault(String key, String defaultValue) {
    final val = _prefs.getString(key);
    return (val == null || val.isEmpty) ? defaultValue : val;
  }

  String get host => _prefs.getString(_keyHost) ?? AppConstants.defaultSshHost;
  int get port => _prefs.getInt(_keyPort) ?? AppConstants.defaultSshPort;
  String get username => _prefs.getString(_keyUsername) ?? AppConstants.defaultSshUsername;
  String get password => _cachedPassword;
  
  LLMProviderType get llmProvider {
    final str = _prefs.getString(_keyLlmProvider);
    if (str == null) return LLMProviderType.openRouter;
    return LLMProviderType.values.firstWhere(
      (e) => e.name == str,
      orElse: () => LLMProviderType.openRouter,
    );
  }

  String get openRouterApiKey => _cachedOpenRouterApiKey;
  String get openRouterModel => _getStringWithDefault(_keyOpenRouterModel, 'inclusionai/ling-3.0-flash:free');
  
  String get geminiApiKey => _cachedGeminiApiKey;
  String get geminiModel => _getStringWithDefault(_keyGeminiModel, 'gemini-3.6-flash');
  
  String get openAIApiKey => _cachedOpenAIApiKey;
  String get openAIModel => _getStringWithDefault(_keyOpenAIModel, 'gpt-4o-mini');
  
  String get claudeApiKey => _cachedClaudeApiKey;
  String get claudeModel => _getStringWithDefault(_keyClaudeModel, 'claude-3-haiku-20240307');
  
  String get ollamaBaseUrl => _getStringWithDefault(_keyOllamaBaseUrl, 'http://10.0.2.2:11434');
  String get ollamaModel => _getStringWithDefault(_keyOllamaModel, 'llama3');

  String get groqApiKey => _cachedGroqApiKey;
  String get groqModel => _getStringWithDefault(_keyGroqModel, 'llama-3.1-8b-instant');

  int get rigs => _prefs.getInt(_keyRigs) ?? AppConstants.defaultRigsCount;
  ThemeMode get themeMode => _parseThemeMode(_prefs.getString(_keyThemeMode));
  bool get voiceNarration => _prefs.getBool(_keyVoiceNarration) ?? true;
  String get ttsVoice => _prefs.getString(_keyTtsVoice) ?? '';

  // ─── Setters ───────────────────────────────────────────────────────
  Future<void> setHost(String value) => _prefs.setString(_keyHost, value);
  Future<void> setPort(int value) => _prefs.setInt(_keyPort, value);
  Future<void> setUsername(String value) => _prefs.setString(_keyUsername, value);
  Future<void> setPassword(String value) async {
    _cachedPassword = value;
    await _secureStorage.write(key: _keyPassword, value: value);
  }
  
  Future<void> setLlmProvider(LLMProviderType value) => _prefs.setString(_keyLlmProvider, value.name);
  
  Future<void> setOpenRouterApiKey(String value) async {
    _cachedOpenRouterApiKey = value;
    await _secureStorage.write(key: _keyOpenRouterApiKey, value: value);
  }
  Future<void> setOpenRouterModel(String value) => _prefs.setString(_keyOpenRouterModel, value);
  
  Future<void> setGeminiApiKey(String value) async {
    _cachedGeminiApiKey = value;
    await _secureStorage.write(key: _keyGeminiApiKey, value: value);
  }
  Future<void> setGeminiModel(String value) => _prefs.setString(_keyGeminiModel, value);
  
  Future<void> setOpenAIApiKey(String value) async {
    _cachedOpenAIApiKey = value;
    await _secureStorage.write(key: _keyOpenAIApiKey, value: value);
  }
  Future<void> setOpenAIModel(String value) => _prefs.setString(_keyOpenAIModel, value);
  
  Future<void> setClaudeApiKey(String value) async {
    _cachedClaudeApiKey = value;
    await _secureStorage.write(key: _keyClaudeApiKey, value: value);
  }
  Future<void> setClaudeModel(String value) => _prefs.setString(_keyClaudeModel, value);
  
  Future<void> setOllamaBaseUrl(String value) => _prefs.setString(_keyOllamaBaseUrl, value);
  Future<void> setOllamaModel(String value) => _prefs.setString(_keyOllamaModel, value);

  Future<void> setGroqApiKey(String value) async {
    _cachedGroqApiKey = value;
    await _secureStorage.write(key: _keyGroqApiKey, value: value);
  }
  Future<void> setGroqModel(String value) => _prefs.setString(_keyGroqModel, value);

  Future<void> setRigs(int value) => _prefs.setInt(_keyRigs, value);
  Future<void> setThemeMode(ThemeMode value) => _prefs.setString(_keyThemeMode, value.name);
  Future<void> setVoiceNarration(bool value) => _prefs.setBool(_keyVoiceNarration, value);
  Future<void> setTtsVoice(String value) => _prefs.setString(_keyTtsVoice, value);

  ThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      case 'system': return ThemeMode.system;
      default: return ThemeMode.dark;
    }
  }
}

// ─── Providers ─────────────────────────────────────────────────────────

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => throw UnimplementedError());
final initialPasswordProvider = Provider<String>((ref) => throw UnimplementedError());
final initialOpenRouterApiKeyProvider = Provider<String>((ref) => throw UnimplementedError());
final initialGeminiApiKeyProvider = Provider<String>((ref) => throw UnimplementedError());
final initialOpenAIApiKeyProvider = Provider<String>((ref) => throw UnimplementedError());
final initialClaudeApiKeyProvider = Provider<String>((ref) => throw UnimplementedError());
final initialGroqApiKeyProvider = Provider<String>((ref) => throw UnimplementedError());

final settingsServiceProvider = Provider<SettingsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  return SettingsService(
    prefs,
    secureStorage,
    ref.watch(initialPasswordProvider),
    ref.watch(initialOpenRouterApiKeyProvider),
    ref.watch(initialGeminiApiKeyProvider),
    ref.watch(initialOpenAIApiKeyProvider),
    ref.watch(initialClaudeApiKeyProvider),
    ref.watch(initialGroqApiKeyProvider),
  );
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return ref.read(settingsServiceProvider).themeMode;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await ref.read(settingsServiceProvider).setThemeMode(mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
