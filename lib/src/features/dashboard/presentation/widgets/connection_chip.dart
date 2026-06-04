import 'package:flutter/material.dart';
import 'dashboard_palette.dart';

class ConnectionChip extends StatelessWidget {
  final bool isConnected;
  final String host;
  final bool isDark;

  const ConnectionChip({
    super.key,
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
            ? DashboardPalette.sage.withValues(alpha: isDark ? 0.2 : 0.12)
            : DashboardPalette.terracotta.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnected
              ? DashboardPalette.sage.withValues(alpha: 0.3)
              : DashboardPalette.terracotta.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulseDot(isActive: isConnected),
          const SizedBox(width: 6),
          Text(
            isConnected ? host : 'Offline',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isConnected ? DashboardPalette.sage : DashboardPalette.terracotta,
            ),
          ),
        ],
      ),
    );
  }
}

class PulseDot extends StatefulWidget {
  final bool isActive;
  const PulseDot({super.key, required this.isActive});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
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
  void didUpdateWidget(PulseDot oldWidget) {
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
                ? DashboardPalette.sage.withValues(alpha: _animation.value)
                : DashboardPalette.terracotta.withValues(alpha: 0.7),
          ),
        );
      },
    );
  }
}
