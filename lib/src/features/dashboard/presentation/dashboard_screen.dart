import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';
import 'package:lg_interactive_onboarding/src/features/dashboard/data/lg_service.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/presentation/model_builder_screen.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/providers/model_builder_providers.dart';
import 'package:lg_interactive_onboarding/src/features/settings/data/settings_service.dart';
import 'package:lg_interactive_onboarding/src/features/settings/presentation/settings_screen.dart';

// ─── Warm, Muted Color Palette ────────────────────────────────────────
class _Palette {
  _Palette._();
  static const terracotta = Color(0xFFC0392B);
  static const warmAmber = Color(0xFFD4A574);
  static const sage = Color(0xFF7FB069);
  static const dustyBlue = Color(0xFF5B8BA0);
  static const warmGrey = Color(0xFF8E8D8A);
  static const parchment = Color(0xFFF5F0EB);
  static const inkDark = Color(0xFF2C2C2C);
  static const deepCleanRed = Color(0xFFB03A2E);
  static const modelBuilderIndigo = Color(0xFF6C5CE7);
}

/// Main dashboard — the hub after connecting to the LG rig.
///
/// Features a warm, humanistic design with organic layouts,
/// soft shadows, and tactile micro-animations.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ssh = ref.watch(sshServiceProvider);
    final settings = ref.watch(settingsServiceProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pushState = ref.watch(pushProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── Organic App Bar ──────────────────────────────────
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: isDark
                ? const Color(0xFF141929)
                : _Palette.parchment,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'LG Content Studio',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : _Palette.inkDark,
                ),
              ),
            ),
            actions: [
              // Connection indicator
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _ConnectionChip(
                  isConnected: ssh.isConnected,
                  host: settings.host,
                  isDark: isDark,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  color: isDark ? Colors.white70 : _Palette.warmGrey,
                ),
                tooltip: 'Settings',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // ─── Content ─────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Status banner with push state feedback
                if (pushState.message != null) ...[
                  _StatusBanner(pushState: pushState, isDark: isDark),
                  const SizedBox(height: 16),
                ],

                // ─── Section: Rig Controls ─────────────────────
                _SectionHeader(
                  label: 'RIG CONTROLS',
                  icon: Icons.gamepad_outlined,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                // Asymmetric grid of rig controls
                _RigControlsGrid(isDark: isDark),

                const SizedBox(height: 28),

                // ─── Section: Tools ────────────────────────────
                _SectionHeader(
                  label: 'TOOLS',
                  icon: Icons.construction_outlined,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                // 3D Model Builder — large feature card
                _FeatureCard(
                  title: '3D Model Builder',
                  subtitle: 'Import, place, and push 3D models to Liquid Galaxy',
                  icon: Icons.view_in_ar_outlined,
                  accentColor: _Palette.modelBuilderIndigo,
                  isDark: isDark,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ModelBuilderScreen(),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ─── Section: Maintenance ──────────────────────
                _SectionHeader(
                  label: 'MAINTENANCE',
                  icon: Icons.build_outlined,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                // Deep Clean card
                _DeepCleanCard(isDark: isDark),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CONNECTION CHIP — small organic pill showing status
// ═══════════════════════════════════════════════════════════════════

class _ConnectionChip extends StatelessWidget {
  final bool isConnected;
  final String host;
  final bool isDark;

  const _ConnectionChip({
    required this.isConnected,
    required this.host,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isConnected
            ? _Palette.sage.withValues(alpha: isDark ? 0.2 : 0.12)
            : _Palette.terracotta.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnected
              ? _Palette.sage.withValues(alpha: 0.3)
              : _Palette.terracotta.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(isActive: isConnected),
          const SizedBox(width: 6),
          Text(
            isConnected ? host : 'Offline',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isConnected ? _Palette.sage : _Palette.terracotta,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated pulsing dot for connection status.
class _PulseDot extends StatefulWidget {
  final bool isActive;
  const _PulseDot({required this.isActive});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_PulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isActive
                ? _Palette.sage.withValues(alpha: _animation.value)
                : _Palette.terracotta.withValues(alpha: 0.7),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// STATUS BANNER — push/operation feedback
// ═══════════════════════════════════════════════════════════════════

class _StatusBanner extends StatelessWidget {
  final PushState pushState;
  final bool isDark;

  const _StatusBanner({required this.pushState, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isSuccess = pushState.status == PushStatus.success;
    final isError = pushState.status == PushStatus.error;
    final isPushing = pushState.status == PushStatus.pushing;

    final color = isSuccess
        ? _Palette.sage
        : isError
            ? _Palette.terracotta
            : _Palette.dustyBlue;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          if (isPushing)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          else
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
              size: 18,
              color: color,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pushState.message ?? '',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION HEADER
// ═══════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isDark;

  const _SectionHeader({
    required this.label,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: isDark
              ? Colors.white.withValues(alpha: 0.35)
              : _Palette.warmGrey.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            color: isDark
                ? Colors.white.withValues(alpha: 0.35)
                : _Palette.warmGrey.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// RIG CONTROLS GRID — warm, asymmetric control cards
// ═══════════════════════════════════════════════════════════════════

class _RigControlsGrid extends ConsumerWidget {
  final bool isDark;
  const _RigControlsGrid({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ssh = ref.watch(sshServiceProvider);
    final isConnected = ssh.isConnected;

    return Column(
      children: [
        // Row 1: Shutdown + Reboot (wider shutdown)
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _RigControlCard(
                title: 'Shutdown',
                icon: Icons.power_settings_new_rounded,
                accentColor: _Palette.terracotta,
                isDark: isDark,
                enabled: isConnected,
                onTap: () => _confirmDangerous(
                  context,
                  ref,
                  title: 'Shutdown All Rigs',
                  message: 'This will power off all Liquid Galaxy rigs. Continue?',
                  action: () => ref.read(lgServiceProvider).shutdown(),
                  actionLabel: 'Shutdown',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _RigControlCard(
                title: 'Reboot',
                icon: Icons.restart_alt_rounded,
                accentColor: _Palette.warmAmber,
                isDark: isDark,
                enabled: isConnected,
                onTap: () => _confirmDangerous(
                  context,
                  ref,
                  title: 'Reboot All Rigs',
                  message: 'This will reboot all Liquid Galaxy rigs. Continue?',
                  action: () => ref.read(lgServiceProvider).reboot(),
                  actionLabel: 'Reboot',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 2: Relaunch + Refresh Master KML + Clear KML
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _RigControlCard(
                title: 'Relaunch',
                icon: Icons.refresh_rounded,
                accentColor: _Palette.sage,
                isDark: isDark,
                enabled: isConnected,
                onTap: () async {
                  await ref.read(lgServiceProvider).relaunch();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Relaunching LG...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: _RigControlCard(
                title: 'Refresh KML',
                icon: Icons.sync_rounded,
                accentColor: _Palette.dustyBlue,
                isDark: isDark,
                enabled: isConnected,
                onTap: () async {
                  final ok = await ref.read(lgServiceProvider).refreshMasterKml();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok
                            ? 'Master KML refreshed'
                            : 'Refresh failed'),
                        backgroundColor: ok ? _Palette.sage : _Palette.terracotta,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _RigControlCard(
                title: 'Clear KML',
                icon: Icons.layers_clear_rounded,
                accentColor: _Palette.warmGrey,
                isDark: isDark,
                enabled: isConnected,
                onTap: () async {
                  final ok = await ref.read(lgServiceProvider).clearKml();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'KML cleared' : 'Clear failed'),
                        backgroundColor: ok ? _Palette.sage : _Palette.terracotta,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _confirmDangerous(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String message,
    required Future<bool> Function() action,
    required String actionLabel,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: _Palette.terracotta, size: 22),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await action();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? '$actionLabel command sent'
                        : '$actionLabel failed'),
                    backgroundColor: ok ? _Palette.sage : _Palette.terracotta,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: _Palette.terracotta,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// INDIVIDUAL RIG CONTROL CARD — tactile, warm feel
// ═══════════════════════════════════════════════════════════════════

class _RigControlCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final bool isDark;
  final bool enabled;
  final VoidCallback onTap;

  const _RigControlCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.isDark,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_RigControlCard> createState() => _RigControlCardState();
}

class _RigControlCardState extends State<_RigControlCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = widget.isDark
        ? const Color(0xFF1C2236)
        : Colors.white;

    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: widget.enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: Matrix4.diagonal3Values(
          _pressed ? 0.96 : 1.0,
          _pressed ? 0.96 : 1.0,
          1.0,
        ),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          color: widget.enabled
              ? surfaceColor
              : surfaceColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.enabled
                ? widget.accentColor.withValues(alpha: widget.isDark ? 0.2 : 0.15)
                : Colors.transparent,
          ),
          boxShadow: [
            if (widget.enabled && !_pressed)
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(
                  alpha: widget.enabled
                      ? (widget.isDark ? 0.15 : 0.08)
                      : 0.04,
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                widget.icon,
                size: 22,
                color: widget.enabled
                    ? widget.accentColor
                    : widget.accentColor.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: widget.enabled
                    ? (widget.isDark ? Colors.white : _Palette.inkDark)
                    : (widget.isDark
                        ? Colors.white38
                        : _Palette.warmGrey.withValues(alpha: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// FEATURE CARD — large, warm card for navigating to features
// ═══════════════════════════════════════════════════════════════════

class _FeatureCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isDark;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = widget.isDark
        ? const Color(0xFF1C2236)
        : Colors.white;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: Matrix4.diagonal3Values(
          _pressed ? 0.98 : 1.0,
          _pressed ? 0.98 : 1.0,
          1.0,
        ),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: widget.accentColor.withValues(
              alpha: widget.isDark ? 0.15 : 0.1,
            ),
          ),
          boxShadow: [
            if (!_pressed)
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(
                  alpha: widget.isDark ? 0.15 : 0.08,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                widget.icon,
                size: 28,
                color: widget.accentColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark ? Colors.white : _Palette.inkDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isDark
                          ? Colors.white54
                          : _Palette.warmGrey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: widget.isDark
                  ? Colors.white30
                  : _Palette.warmGrey.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// DEEP CLEAN CARD — destructive action with double confirmation
// ═══════════════════════════════════════════════════════════════════

class _DeepCleanCard extends ConsumerWidget {
  final bool isDark;
  const _DeepCleanCard({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ssh = ref.watch(sshServiceProvider);
    final pushState = ref.watch(pushProvider);
    final isPushing = pushState.status == PushStatus.pushing;
    final isConnected = ssh.isConnected;
    final enabled = isConnected && !isPushing;

    final surfaceColor = isDark ? const Color(0xFF1C2236) : Colors.white;

    return GestureDetector(
      onTap: enabled ? () => _confirmDeepClean(context, ref) : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled
                ? _Palette.deepCleanRed.withValues(alpha: isDark ? 0.2 : 0.12)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _Palette.deepCleanRed.withValues(
                  alpha: enabled ? (isDark ? 0.15 : 0.08) : 0.04,
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                Icons.delete_forever_rounded,
                size: 22,
                color: enabled
                    ? _Palette.deepCleanRed
                    : _Palette.deepCleanRed.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deep Clean',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: enabled
                          ? (isDark ? Colors.white : _Palette.inkDark)
                          : (isDark ? Colors.white38 : _Palette.warmGrey),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Remove all files from /model & /3d_model_wrapper, reset master KML',
                    style: TextStyle(
                      fontSize: 11,
                      color: enabled
                          ? (isDark ? Colors.white54 : _Palette.warmGrey)
                          : (isDark
                              ? Colors.white24
                              : _Palette.warmGrey.withValues(alpha: 0.4)),
                    ),
                  ),
                ],
              ),
            ),
            if (!isConnected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _Palette.warmGrey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Offline',
                  style: TextStyle(fontSize: 10, color: _Palette.warmGrey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDeepClean(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: _Palette.deepCleanRed, size: 22),
            SizedBox(width: 10),
            Text('Deep Clean'),
          ],
        ),
        content: const Text(
          'This will permanently delete ALL files from:\n\n'
          '• /var/www/html/model/\n'
          '• /var/www/html/3d_model_wrapper/\n\n'
          'And reset the master KML. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(pushProvider.notifier).deepClean();
            },
            style: FilledButton.styleFrom(
              backgroundColor: _Palette.deepCleanRed,
            ),
            child: const Text('Deep Clean'),
          ),
        ],
      ),
    );
  }
}
