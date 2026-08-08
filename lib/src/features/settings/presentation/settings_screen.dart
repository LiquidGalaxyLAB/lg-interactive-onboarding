import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/logo_overlay_service.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/system_kml_service.dart';
import 'package:lg_interactive_onboarding/src/common/tts/tts_service.dart';
import 'package:lg_interactive_onboarding/src/features/settings/data/settings_service.dart';
import 'widgets/rig_controls_grid.dart';

/// Settings screen for managing SSH connection and app preferences.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _rigsCtrl;
  
  late LLMProviderType _selectedProvider;
  late final TextEditingController _openRouterApiKeyCtrl;
  late final TextEditingController _openRouterModelCtrl;
  late final TextEditingController _geminiApiKeyCtrl;
  late final TextEditingController _geminiModelCtrl;
  late final TextEditingController _openAIApiKeyCtrl;
  late final TextEditingController _openAIModelCtrl;
  late final TextEditingController _claudeApiKeyCtrl;
  late final TextEditingController _claudeModelCtrl;
  late final TextEditingController _ollamaBaseUrlCtrl;
  late final TextEditingController _ollamaModelCtrl;
  late final TextEditingController _groqApiKeyCtrl;
  late final TextEditingController _groqModelCtrl;

  bool _isConnecting = false;
  bool _isDisconnecting = false;
  bool _obscurePassword = true;
  bool _obscureApiKey = true;
  bool _isSavingAi = false;
  late bool _voiceNarration;
  
  List<Map<String, String>> _availableVoices = [];
  String? _selectedVoice;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsServiceProvider);
    _hostCtrl = TextEditingController(text: settings.host);
    _portCtrl = TextEditingController(text: settings.port.toString());
    _usernameCtrl = TextEditingController(text: settings.username);
    _passwordCtrl = TextEditingController(text: settings.password);
    _rigsCtrl = TextEditingController(text: settings.rigs.toString());
    
    _selectedProvider = settings.llmProvider;
    _openRouterApiKeyCtrl = TextEditingController(text: settings.openRouterApiKey);
    _openRouterModelCtrl = TextEditingController(text: settings.openRouterModel);
    _geminiApiKeyCtrl = TextEditingController(text: settings.geminiApiKey);
    _geminiModelCtrl = TextEditingController(text: settings.geminiModel);
    _openAIApiKeyCtrl = TextEditingController(text: settings.openAIApiKey);
    _openAIModelCtrl = TextEditingController(text: settings.openAIModel);
    _claudeApiKeyCtrl = TextEditingController(text: settings.claudeApiKey);
    _claudeModelCtrl = TextEditingController(text: settings.claudeModel);
    _ollamaBaseUrlCtrl = TextEditingController(text: settings.ollamaBaseUrl);
    _ollamaModelCtrl = TextEditingController(text: settings.ollamaModel);
    _groqApiKeyCtrl = TextEditingController(text: settings.groqApiKey);
    _groqModelCtrl = TextEditingController(text: settings.groqModel);
    
    _voiceNarration = settings.voiceNarration;
    ref.read(ttsServiceProvider).setEnabled(_voiceNarration);
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    final tts = ref.read(ttsServiceProvider);
    final voices = await tts.getAvailableVoices();
    final settings = ref.read(settingsServiceProvider);
    
    if (mounted) {
      setState(() {
        _availableVoices = voices;
        if (voices.any((v) => v['name'] == settings.ttsVoice)) {
          _selectedVoice = settings.ttsVoice;
        } else if (voices.isNotEmpty) {
          _selectedVoice = voices.first['name'];
        }
      });
    }
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _rigsCtrl.dispose();
    
    _openRouterApiKeyCtrl.dispose();
    _openRouterModelCtrl.dispose();
    _geminiApiKeyCtrl.dispose();
    _geminiModelCtrl.dispose();
    _openAIApiKeyCtrl.dispose();
    _openAIModelCtrl.dispose();
    _claudeApiKeyCtrl.dispose();
    _claudeModelCtrl.dispose();
    _ollamaBaseUrlCtrl.dispose();
    _ollamaModelCtrl.dispose();
    _groqApiKeyCtrl.dispose();
    _groqModelCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAiSettings({bool showSnackbar = true}) async {
    setState(() => _isSavingAi = true);

    try {
      final settings = ref.read(settingsServiceProvider);
      await settings.setLlmProvider(_selectedProvider);
      await settings.setOpenRouterApiKey(_openRouterApiKeyCtrl.text.trim());
      await settings.setOpenRouterModel(_openRouterModelCtrl.text.trim());
      await settings.setGeminiApiKey(_geminiApiKeyCtrl.text.trim());
      await settings.setGeminiModel(_geminiModelCtrl.text.trim());
      await settings.setOpenAIApiKey(_openAIApiKeyCtrl.text.trim());
      await settings.setOpenAIModel(_openAIModelCtrl.text.trim());
      await settings.setClaudeApiKey(_claudeApiKeyCtrl.text.trim());
      await settings.setClaudeModel(_claudeModelCtrl.text.trim());
      await settings.setOllamaBaseUrl(_ollamaBaseUrlCtrl.text.trim());
      await settings.setOllamaModel(_ollamaModelCtrl.text.trim());
      await settings.setGroqApiKey(_groqApiKeyCtrl.text.trim());
      await settings.setGroqModel(_groqModelCtrl.text.trim());
      
      if (!mounted) return;
      if (showSnackbar) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI Mentor settings saved!'),
            backgroundColor: Color(0xFF1E8E3E),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingAi = false);
      }
    }
  }

  Future<void> _saveAndConnect() async {
    final settings = ref.read(settingsServiceProvider);
    final ssh = ref.read(sshServiceProvider);
    
    await settings.setHost(_hostCtrl.text.trim());
    await settings.setPort(int.tryParse(_portCtrl.text) ?? 22);
    await settings.setUsername(_usernameCtrl.text.trim());
    await settings.setPassword(_passwordCtrl.text);
    await settings.setRigs(int.tryParse(_rigsCtrl.text) ?? 3);
    
    await _saveAiSettings(showSnackbar: false);

    if (!mounted) return;
    setState(() => _isConnecting = true);

    if (ssh.isConnected) {
      await ref.read(logoOverlayServiceProvider).clearLogo();
      await ref.read(systemKmlServiceProvider).cleanUp();
    }
    await ssh.disconnect();
    final result = await ssh.connect(
      host: _hostCtrl.text.trim(),
      port: int.tryParse(_portCtrl.text) ?? 22,
      username: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _isConnecting = false);

    switch (result) {
      case SSHConnected():
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected to Liquid Galaxy successfully!'),
            backgroundColor: Color(0xFF1E8E3E),
          ),
        );
      case SSHConnectionError(:final message):
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $message'),
            backgroundColor: const Color(0xFFB3261E),
          ),
        );
      case SSHConnecting() || SSHDisconnected():
        break;
    }
  }

  Widget _buildProviderSettings() {
    switch (_selectedProvider) {
      case LLMProviderType.openRouter:
        return Column(
          children: [
            TextField(
              controller: _openRouterApiKeyCtrl,
              obscureText: _obscureApiKey,
              decoration: InputDecoration(
                labelText: 'OpenRouter API Key',
                prefixIcon: const Icon(Icons.vpn_key),
                hintText: 'sk-or-v1-...',
                suffixIcon: IconButton(
                  icon: Icon(_obscureApiKey ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _openRouterModelCtrl,
              decoration: const InputDecoration(
                labelText: 'OpenRouter Model Name',
                prefixIcon: Icon(Icons.psychology_alt),
                hintText: 'e.g. inclusionai/ling-3.0-flash:free',
              ),
            ),
          ],
        );
      case LLMProviderType.gemini:
        return Column(
          children: [
            TextField(
              controller: _geminiApiKeyCtrl,
              obscureText: _obscureApiKey,
              decoration: InputDecoration(
                labelText: 'Gemini API Key',
                prefixIcon: const Icon(Icons.vpn_key),
                suffixIcon: IconButton(
                  icon: Icon(_obscureApiKey ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _geminiModelCtrl,
              decoration: const InputDecoration(
                labelText: 'Gemini Model Name',
                prefixIcon: Icon(Icons.psychology_alt),
                hintText: 'e.g. gemini-1.5-flash',
              ),
            ),
          ],
        );
      case LLMProviderType.openAI:
        return Column(
          children: [
            TextField(
              controller: _openAIApiKeyCtrl,
              obscureText: _obscureApiKey,
              decoration: InputDecoration(
                labelText: 'OpenAI API Key',
                prefixIcon: const Icon(Icons.vpn_key),
                suffixIcon: IconButton(
                  icon: Icon(_obscureApiKey ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _openAIModelCtrl,
              decoration: const InputDecoration(
                labelText: 'OpenAI Model Name',
                prefixIcon: Icon(Icons.psychology_alt),
                hintText: 'e.g. gpt-4o-mini',
              ),
            ),
          ],
        );
      case LLMProviderType.claude:
        return Column(
          children: [
            TextField(
              controller: _claudeApiKeyCtrl,
              obscureText: _obscureApiKey,
              decoration: InputDecoration(
                labelText: 'Claude API Key',
                prefixIcon: const Icon(Icons.vpn_key),
                suffixIcon: IconButton(
                  icon: Icon(_obscureApiKey ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _claudeModelCtrl,
              decoration: const InputDecoration(
                labelText: 'Claude Model Name',
                prefixIcon: Icon(Icons.psychology_alt),
                hintText: 'e.g. claude-3-haiku-20240307',
              ),
            ),
          ],
        );
      case LLMProviderType.ollama:
        return Column(
          children: [
            TextField(
              controller: _ollamaBaseUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'Ollama Base URL',
                prefixIcon: Icon(Icons.link),
                hintText: 'e.g. http://10.0.2.2:11434',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ollamaModelCtrl,
              decoration: const InputDecoration(
                labelText: 'Ollama Model Name',
                prefixIcon: Icon(Icons.psychology_alt),
                hintText: 'e.g. llama3',
              ),
            ),
          ],
        );
      case LLMProviderType.groq:
        return Column(
          children: [
            TextField(
              controller: _groqApiKeyCtrl,
              obscureText: _obscureApiKey,
              decoration: InputDecoration(
                labelText: 'Groq API Key',
                prefixIcon: const Icon(Icons.vpn_key),
                suffixIcon: IconButton(
                  icon: Icon(_obscureApiKey ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _groqModelCtrl,
              decoration: const InputDecoration(
                labelText: 'Groq Model Name',
                prefixIcon: Icon(Icons.psychology_alt),
                hintText: 'e.g. llama-3.1-8b-instant',
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ssh = ref.watch(sshServiceProvider);
    final isDark = theme.brightness == Brightness.dark;

    const success     = Color(0xFF1E8E3E);
    const error       = Color(0xFFB3261E);
    const outline     = Color(0xFF747775);
    const onSurface   = Color(0xFF1F1F1F);
    
    final successEff  = isDark ? const Color(0xFF72DD87) : success;
    final errorEff    = isDark ? const Color(0xFFF2B8B5) : error;
    final outlineEff  = isDark ? const Color(0xFF9AA0A6) : outline;
    final onSurfaceEff = isDark ? const Color(0xFFE3E3E3) : onSurface;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            const SizedBox(height: 20),
            Text(
              'Connect to\nLiquid Galaxy',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: -0.5,
                color: onSurfaceEff,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your rig\'s SSH details to get started',
              style: TextStyle(
                fontSize: 14,
                color: outlineEff,
              ),
            ),

            const SizedBox(height: 24),

            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: ssh.isConnected
                    ? successEff.withValues(alpha: isDark ? 0.15 : 0.08)
                    : errorEff.withValues(alpha: isDark ? 0.10 : 0.05),
                border: Border.all(
                  color: ssh.isConnected
                      ? successEff.withValues(alpha: 0.30)
                      : errorEff.withValues(alpha: 0.20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ssh.isConnected ? successEff : errorEff.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    ssh.isConnected ? 'Connected' : 'Not connected',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: ssh.isConnected ? successEff : outlineEff,
                    ),
                  ),
                  const Spacer(),
                  if (ssh.isConnected)
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: const Text(
                        'Go to Dashboard →',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            _SectionLabel(label: 'SSH CONFIGURATION', isDark: isDark),
            const SizedBox(height: 14),

            TextField(
              controller: _hostCtrl,
              decoration: const InputDecoration(
                labelText: 'Host IP',
                prefixIcon: Icon(Icons.dns_outlined),
                hintText: '192.168.0.10',
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                     controller: _portCtrl,
                     decoration: const InputDecoration(
                       labelText: 'Port',
                       prefixIcon: Icon(Icons.tag),
                       hintText: '22',
                     ),
                     keyboardType: TextInputType.number,
                   ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                     controller: _rigsCtrl,
                     decoration: const InputDecoration(
                       labelText: 'Rigs',
                       prefixIcon: Icon(Icons.devices),
                       hintText: '3',
                     ),
                     keyboardType: TextInputType.number,
                   ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person_outline),
                hintText: 'lg',
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                hintText: '••••••',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              height: 52,
              child: ssh.isConnected
                  ? OutlinedButton.icon(
                      onPressed: _isDisconnecting
                          ? null
                          : () async {
                              setState(() => _isDisconnecting = true);
                              try {
                                await ref.read(logoOverlayServiceProvider).clearLogo();
                                await ref.read(systemKmlServiceProvider).cleanUp();
                                await ssh.disconnect();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Disconnected successfully'),
                                      backgroundColor: Color(0xFF1E8E3E),
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _isDisconnecting = false);
                                }
                              }
                            },
                      icon: _isDisconnecting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            )
                          : const Icon(Icons.link_off),
                      label: Text(_isDisconnecting ? 'Disconnecting...' : 'Disconnect'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: errorEff,
                        side: BorderSide(color: errorEff.withValues(alpha: 0.5)),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _isConnecting ? null : _saveAndConnect,
                      icon: _isConnecting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.power_settings_new),
                      label: Text(_isConnecting ? 'Connecting...' : 'Save & Connect'),
                    ),
            ),

            const SizedBox(height: 32),

            _SectionLabel(label: 'RIG CONTROLS', isDark: isDark),
            const SizedBox(height: 14),
            RigControlsGrid(isDark: isDark),

            const SizedBox(height: 32),

            _SectionLabel(label: 'AI MENTOR', isDark: isDark),
            const SizedBox(height: 14),

            DropdownButtonFormField<LLMProviderType>(
              isExpanded: true,
              initialValue: _selectedProvider,
              decoration: const InputDecoration(
                labelText: 'LLM Provider',
                prefixIcon: Icon(Icons.smart_toy),
              ),
              items: const [
                DropdownMenuItem(value: LLMProviderType.openRouter, child: Text('OpenRouter')),
                DropdownMenuItem(value: LLMProviderType.gemini, child: Text('Google Gemini')),
                DropdownMenuItem(value: LLMProviderType.openAI, child: Text('OpenAI')),
                DropdownMenuItem(value: LLMProviderType.claude, child: Text('Anthropic Claude')),
                DropdownMenuItem(value: LLMProviderType.ollama, child: Text('Ollama (Local)')),
                DropdownMenuItem(value: LLMProviderType.groq, child: Text('Groq')),
              ],
              onTap: () => FocusScope.of(context).unfocus(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedProvider = val);
                }
              },
            ),
            const SizedBox(height: 12),
            
            _buildProviderSettings(),

            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSavingAi ? null : _saveAiSettings,
                icon: _isSavingAi
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_isSavingAi ? 'Saving...' : 'Save AI Settings'),
              ),
            ),

            const SizedBox(height: 32),

            _SectionLabel(label: 'APPEARANCE', isDark: isDark),
            const SizedBox(height: 14),

            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.settings_suggest),
                ),
              ],
              selected: {ref.watch(themeModeProvider)},
              onSelectionChanged: (modes) {
                ref.read(themeModeProvider.notifier).setThemeMode(modes.first);
              },
            ),

            const SizedBox(height: 32),

            _SectionLabel(label: 'ACCESSIBILITY', isDark: isDark),
            const SizedBox(height: 14),

            SwitchListTile(
              title: const Text('Voice Narration'),
              subtitle: const Text('Read aloud guided-mode steps and diagram descriptions'),
              secondary: Icon(
                _voiceNarration ? Icons.record_voice_over : Icons.voice_over_off,
                color: _voiceNarration ? const Color(0xFF1A73E8) : outlineEff,
              ),
              value: _voiceNarration,
              onChanged: (value) async {
                setState(() => _voiceNarration = value);
                final settings = ref.read(settingsServiceProvider);
                await settings.setVoiceNarration(value);
                ref.read(ttsServiceProvider).setEnabled(value);
              },
              activeThumbColor: const Color(0xFF1A73E8),
              contentPadding: EdgeInsets.zero,
            ),
            
            if (_availableVoices.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedVoice,
                decoration: const InputDecoration(
                  labelText: 'Narration Voice',
                  prefixIcon: Icon(Icons.record_voice_over),
                ),
                items: _availableVoices.map((v) {
                  return DropdownMenuItem<String>(
                    value: v['name'],
                    child: Text(v['displayName'] ?? v['name'] ?? ''),
                  );
                }).toList(),
                onTap: () => FocusScope.of(context).unfocus(),
                onChanged: _voiceNarration ? (val) async {
                  if (val != null) {
                    setState(() => _selectedVoice = val);
                    final settings = ref.read(settingsServiceProvider);
                    await settings.setTtsVoice(val);
                    final selectedVoiceMap = _availableVoices.firstWhere((v) => v['name'] == val);
                    ref.read(ttsServiceProvider).setVoice(val, selectedVoiceMap['locale'] ?? 'en-US');
                  }
                } : null,
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;

  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
        color: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF747775),
      ),
    );
  }
}
