import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/logo_overlay_service.dart';
import 'package:lg_interactive_onboarding/src/common/tts/tts_service.dart';
import 'package:lg_interactive_onboarding/src/features/settings/data/settings_service.dart';
import 'widgets/rig_controls_grid.dart';

/// Settings screen for managing SSH connection and app preferences.
///
/// On successful connection, navigates to the Dashboard.
/// Uses a warm, humanistic design with organic layouts.
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
  late final TextEditingController _geminiApiKeyCtrl;
  late final TextEditingController _geminiModelCtrl;

  bool _isConnecting = false;
  bool _obscurePassword = true;
  bool _obscureApiKey = true;
  bool _isVerifyingAi = false;
  late bool _voiceNarration;
  
  String _selectedModelDropdown = 'inclusionai/ling-3.0-flash:free';
  bool _showCustomModelInput = false;

  static const _curatedModels = {
    'inclusionai/ling-3.0-flash:free': 'Ling-3.0-flash (free)',
    'nvidia/nemotron-3-ultra-550b-a55b:free': 'NVIDIA: Nemotron 3 Ultra (free)',
    'poolside/laguna-s-2.1:free': 'Poolside: Laguna S 2.1 (free)',
    'poolside/laguna-xs-2.1:free': 'Poolside: Laguna XS 2.1 (free)',
    'cohere/north-mini-code:free': 'Cohere: North Mini Code (free)',
    'nvidia/nemotron-3-super-120b-a12b:free': 'NVIDIA: Nemotron 3 Super (free)',
    'nvidia/nemotron-3-nano-30b-a3b:free': 'NVIDIA: Nemotron 3 Nano 30B A3B (free)',
    'openai/gpt-oss-20b:free': 'OpenAI: gpt-oss-20b (free)',
  };
  
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
    _geminiApiKeyCtrl = TextEditingController(text: settings.geminiApiKey);
    
    final savedModel = settings.geminiModel;
    if (_curatedModels.containsKey(savedModel)) {
      _selectedModelDropdown = savedModel;
      _showCustomModelInput = false;
      _geminiModelCtrl = TextEditingController();
    } else {
      _selectedModelDropdown = 'other';
      _showCustomModelInput = true;
      _geminiModelCtrl = TextEditingController(text: savedModel);
    }
    
    _rigsCtrl = TextEditingController(text: settings.rigs.toString());
    _voiceNarration = settings.voiceNarration;
    // Sync TTS service with persisted preference on screen load.
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
    _geminiApiKeyCtrl.dispose();
    _geminiModelCtrl.dispose();
    _rigsCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyAndApplyAiSettings() async {
    final apiKey = _geminiApiKeyCtrl.text.trim();
    final model = _showCustomModelInput ? _geminiModelCtrl.text.trim() : _selectedModelDropdown;
    
    if (apiKey.isEmpty || model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API Key and Model cannot be empty'),
          backgroundColor: Color(0xFFB3261E),
        ),
      );
      return;
    }

    setState(() => _isVerifyingAi = true);

    try {
      final res = await http.get(
        Uri.parse('https://openrouter.ai/api/v1/auth/key'),
        headers: {'Authorization': 'Bearer $apiKey'},
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final settings = ref.read(settingsServiceProvider);
        await settings.setGeminiApiKey(apiKey);
        await settings.setGeminiModel(model);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI Mentor settings verified and saved!'),
            backgroundColor: Color(0xFF1E8E3E),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid API Key (OpenRouter rejected it)'),
            backgroundColor: Color(0xFFB3261E),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Validation failed: $e'),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isVerifyingAi = false);
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
    await settings.setGeminiApiKey(_geminiApiKeyCtrl.text.trim());
    await settings.setGeminiModel(_geminiModelCtrl.text.trim());
    await settings.setRigs(int.tryParse(_rigsCtrl.text) ?? 3);

    if (!mounted) return;
    setState(() => _isConnecting = true);

    // Clear logo while SSH is still connected, then disconnect.
    if (ssh.isConnected) {
      await ref.read(logoOverlayServiceProvider).clearLogo();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected to Liquid Galaxy successfully!'),
            backgroundColor: Color(0xFF1E8E3E),
          ),
        );
      case SSHConnectionError(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $message'),
            backgroundColor: const Color(0xFFB3261E),
          ),
        );
      case SSHConnecting() || SSHDisconnected():
        // Stale result from a superseded connection attempt; ignore.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ssh = ref.watch(sshServiceProvider);
    final isDark = theme.brightness == Brightness.dark;

    // M3 semantic palette
    const success     = Color(0xFF1E8E3E);  // M3 success green
    const error       = Color(0xFFB3261E);  // M3 error red
    const outline     = Color(0xFF747775);  // M3 outline
    const onSurface   = Color(0xFF1F1F1F);  // M3 on-surface
    // Dark-mode overrides
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

            // ─── Header ─────────────────────────────────────────
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

            // ─── Status Indicator ────────────────────────────────
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
                      color: ssh.isConnected
                          ? successEff
                          : outlineEff,
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

            // ─── SSH Configuration ──────────────────────────────
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
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ─── Connect Button ─────────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
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

            if (ssh.isConnected) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    // Clear logo while SSH is still connected, then disconnect.
                    await ref.read(logoOverlayServiceProvider).clearLogo();
                    await ssh.disconnect();
                    setState(() {});
                  },
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: errorEff,
                    side: BorderSide(color: errorEff.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // ─── Rig Controls ─────────────────────────────────────
            _SectionLabel(label: 'RIG CONTROLS', isDark: isDark),
            const SizedBox(height: 14),
            RigControlsGrid(isDark: isDark),

            const SizedBox(height: 32),

            // ─── AI Mentor Configuration ──────────────────────────
            _SectionLabel(label: 'AI MENTOR', isDark: isDark),
            const SizedBox(height: 14),

            TextField(
              controller: _geminiApiKeyCtrl,
              obscureText: _obscureApiKey,
              decoration: InputDecoration(
                labelText: 'OpenRouter API Key',
                prefixIcon: const Icon(Icons.vpn_key),
                hintText: 'sk-or-v1-...',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() => _obscureApiKey = !_obscureApiKey);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedModelDropdown,
              decoration: const InputDecoration(
                labelText: 'OpenRouter Model',
                prefixIcon: Icon(Icons.psychology_alt),
              ),
              items: [
                ..._curatedModels.entries.map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    )),
                const DropdownMenuItem(
                  value: 'other',
                  child: Text('Other (Custom Model)'),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedModelDropdown = val;
                    _showCustomModelInput = val == 'other';
                  });
                }
              },
            ),
            if (_showCustomModelInput) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _geminiModelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Custom Model Name',
                  prefixIcon: Icon(Icons.edit),
                  hintText: 'e.g. anthropic/claude-3-haiku',
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isVerifyingAi ? null : _verifyAndApplyAiSettings,
                icon: _isVerifyingAi
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_isVerifyingAi ? 'Verifying...' : 'Verify & Save AI Settings'),
              ),
            ),

            const SizedBox(height: 32),

            // ─── Appearance ─────────────────────────────────────
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

            // ─── Accessibility ───────────────────────────────────
            _SectionLabel(label: 'ACCESSIBILITY', isDark: isDark),
            const SizedBox(height: 14),

            SwitchListTile(
              title: const Text('Voice Narration'),
              subtitle: const Text('Read aloud guided-mode steps and diagram descriptions'),
              secondary: Icon(
                _voiceNarration ? Icons.record_voice_over : Icons.voice_over_off,
                color: _voiceNarration
                    ? const Color(0xFF1A73E8)
                    : outlineEff,
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
        color: isDark
            ? const Color(0xFF9AA0A6)
            : const Color(0xFF747775),
      ),
    );
  }
}
