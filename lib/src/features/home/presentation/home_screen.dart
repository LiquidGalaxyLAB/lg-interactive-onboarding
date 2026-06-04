import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/ssh_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _userController;
  late final TextEditingController _passwordController;
  late final TextEditingController _rigsController;
  late final ScrollController _logScrollController;

  bool _obscurePassword = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController();
    _portController = TextEditingController();
    _userController = TextEditingController();
    _passwordController = TextEditingController();
    _rigsController = TextEditingController();
    _logScrollController = ScrollController();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    _rigsController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  void _initializeControllers(SSHConnectionState state) {
    _hostController.text = state.host;
    _portController.text = state.port.toString();
    _userController.text = state.username;
    _passwordController.text = state.password;
    _rigsController.text = state.rigs.toString();
    _initialized = true;
  }

  void _scrollToBottom() {
    if (_logScrollController.hasClients) {
      _logScrollController.animateTo(
        _logScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _showConfirmationDialog({
    required String title,
    required String content,
    required VoidCallback onConfirm,
    required Color confirmColor,
  }) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(content, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sshControllerProvider);

    // Initialize values from provider state (loaded from SharedPreferences)
    if (!_initialized && state.host.isNotEmpty) {
      _initializeControllers(state);
    }

    // Auto-scroll logs to bottom on next frame after build when logs change
    ref.listen<SSHConnectionState>(sshControllerProvider, (previous, next) {
      if (!_initialized && next.host.isNotEmpty) {
        _initializeControllers(next);
      }
      if (previous?.logs.length != next.logs.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 800;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 2,
        title: Row(
          children: [
            const Icon(Icons.rocket_launch, color: Colors.cyanAccent, size: 24),
            const SizedBox(width: 12),
            const Text(
              'LG Interactive Onboarding',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            // Connection status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: state.isConnected
                    ? Colors.green.withAlpha(38)
                    : Colors.red.withAlpha(38),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: state.isConnected ? Colors.greenAccent : Colors.redAccent,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: state.isConnected ? Colors.greenAccent : Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    state.isConnected ? 'CONNECTED' : 'DISCONNECTED',
                    style: TextStyle(
                      color: state.isConnected ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: isTablet
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20.0),
                      child: _buildConfigCard(state),
                    ),
                  ),
                  VerticalDivider(color: Colors.blueGrey[800], width: 1),
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: _buildActionsAndConsole(state),
                    ),
                  ),
                ],
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildConfigCard(state),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 500,
                      child: _buildActionsAndConsole(state),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildConfigCard(SSHConnectionState state) {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.settings, color: Colors.cyanAccent),
                  const SizedBox(width: 8),
                  Text(
                    'Connection Settings',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 24),
              
              // IP Address input
              TextFormField(
                controller: _hostController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration(
                  label: 'Master IP Address',
                  icon: Icons.computer,
                  hint: 'e.g., 192.168.0.1',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'IP Address is required';
                  // Simple IP pattern match
                  final reg = RegExp(r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$');
                  if (!reg.hasMatch(val.trim()) && val.trim() != 'localhost') {
                    return 'Please enter a valid IP address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Port and Rigs row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _portController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration(
                        label: 'SSH Port',
                        icon: Icons.numbers,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        final port = int.tryParse(val);
                        if (port == null || port <= 0 || port > 65535) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _rigsController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration(
                        label: 'Total Rigs',
                        icon: Icons.grid_view,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        final rigs = int.tryParse(val);
                        if (rigs == null || rigs <= 0 || rigs > 20) return 'Max 20';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Username input
              TextFormField(
                controller: _userController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration(
                  label: 'SSH Username',
                  icon: Icons.person,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Username required' : null,
              ),
              const SizedBox(height: 16),

              // Password input
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration(
                  label: 'SSH Password',
                  icon: Icons.lock,
                ).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white54,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Password required' : null,
              ),
              const SizedBox(height: 24),

              // Connect / Disconnect button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: state.isConnected ? Colors.redAccent : Colors.cyanAccent[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: state.isLoading
                    ? null
                    : () async {
                        if (!state.isConnected) {
                          if (_formKey.currentState!.validate()) {
                            // Save config first
                            await ref.read(sshControllerProvider.notifier).saveSettings(
                                  host: _hostController.text.trim(),
                                  port: int.parse(_portController.text.trim()),
                                  username: _userController.text.trim(),
                                  password: _passwordController.text.trim(),
                                  rigs: int.parse(_rigsController.text.trim()),
                                );
                            // Then connect
                            await ref.read(sshControllerProvider.notifier).connect();
                          }
                        } else {
                          await ref.read(sshControllerProvider.notifier).disconnect();
                        }
                      },
                child: state.isLoading && state.statusMessage?.contains('onnect') == true
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(state.isConnected ? Icons.link_off : Icons.link),
                          const SizedBox(width: 8),
                          Text(
                            state.isConnected ? 'DISCONNECT SSH' : 'CONNECT SSH',
                            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ],
                      ),
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionsAndConsole(SSHConnectionState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Operations Card
        Card(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, color: Colors.amberAccent),
                    const SizedBox(width: 8),
                    Text(
                      'LG Power Management',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white10, height: 24),
                const Text(
                  'Quick control actions that target all Liquid Galaxy rigs in the cluster.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 20),
                
                // Actions Buttons row
                Row(
                  children: [
                    // Shutdown button
                    Expanded(
                      child: _buildActionButton(
                        label: 'Shutdown',
                        icon: Icons.power_settings_new,
                        color: Colors.redAccent,
                        isEnabled: state.isConnected && !state.isLoading,
                        onPressed: () {
                          _showConfirmationDialog(
                            title: 'Shutdown Cluster',
                            content: 'Are you sure you want to SHUT DOWN all ${state.rigs} rigs? This will physically power off the machines.',
                            confirmColor: Colors.redAccent,
                            onConfirm: () => ref.read(sshControllerProvider.notifier).shutdown(),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Reboot button
                    Expanded(
                      child: _buildActionButton(
                        label: 'Reboot',
                        icon: Icons.replay,
                        color: Colors.orangeAccent,
                        isEnabled: state.isConnected && !state.isLoading,
                        onPressed: () {
                          _showConfirmationDialog(
                            title: 'Reboot Cluster',
                            content: 'Are you sure you want to REBOOT all ${state.rigs} rigs? This restarts all cluster machines.',
                            confirmColor: Colors.orangeAccent,
                            onConfirm: () => ref.read(sshControllerProvider.notifier).reboot(),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Relaunch button
                    Expanded(
                      child: _buildActionButton(
                        label: 'Relaunch',
                        icon: Icons.rocket_launch,
                        color: Colors.cyanAccent,
                        isEnabled: state.isConnected && !state.isLoading,
                        onPressed: () {
                          _showConfirmationDialog(
                            title: 'Relaunch Applications',
                            content: 'Are you sure you want to RELAUNCH Google Earth/display services on all ${state.rigs} rigs?',
                            confirmColor: Colors.cyanAccent[700]!,
                            onConfirm: () => ref.read(sshControllerProvider.notifier).relaunch(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Terminal Console
        Expanded(
          child: Card(
            color: const Color(0xFF0B0F19),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF1E293B), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Console Logs',
                            style: TextStyle(
                              color: Colors.white70,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white38),
                        tooltip: 'Clear Console',
                        onPressed: () => ref.read(sshControllerProvider.notifier).clearLogs(),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 16),
                  
                  // Log entries
                  Expanded(
                    child: state.logs.isEmpty
                        ? const Center(
                            child: Text(
                              'Console is empty. Connect to view connection and execution activity.',
                              style: TextStyle(
                                color: Colors.white24,
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            controller: _logScrollController,
                            itemCount: state.logs.length,
                            itemBuilder: (context, index) {
                              final log = state.logs[index];
                              final isError = log.contains('failed') || log.contains('Error') || log.contains('failed');
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Text(
                                  log,
                                  style: TextStyle(
                                    color: isError ? Colors.redAccent[100] : Colors.greenAccent[400],
                                    fontFamily: 'monospace',
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isEnabled,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isEnabled ? color.withAlpha(26) : Colors.white.withAlpha(5),
        foregroundColor: color,
        disabledForegroundColor: Colors.white10,
        side: BorderSide(
          color: isEnabled ? color.withAlpha(128) : Colors.white10,
          width: 1.5,
        ),
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      onPressed: isEnabled ? onPressed : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 14),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.cyanAccent.withAlpha(178), size: 20),
      filled: true,
      fillColor: const Color(0xFF0F172A),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.cyanAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent),
    );
  }
}
