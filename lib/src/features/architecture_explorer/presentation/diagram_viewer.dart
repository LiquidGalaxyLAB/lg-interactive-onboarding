import 'dart:math';

import 'package:flutter/material.dart';

import 'package:lg_interactive_onboarding/src/features/architecture_explorer/data/diagram_model.dart';

/// Renders an interactive animated diagram.
///
/// The diagram painting is delegated to a [DiagramPainter] subclass selected
/// by [diagram.id]. Hotspot tap detection is handled by [_HotspotOverlay]
/// positioned over the painter using relative coordinates.
class DiagramViewer extends StatefulWidget {
  final DiagramDefinition diagram;
  final void Function(HotspotDefinition hotspot) onHotspotTap;

  const DiagramViewer({
    super.key,
    required this.diagram,
    required this.onHotspotTap,
  });

  @override
  State<DiagramViewer> createState() => _DiagramViewerState();
}

class _DiagramViewerState extends State<DiagramViewer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void didUpdateWidget(DiagramViewer old) {
    super.didUpdateWidget(old);
    if (old.diagram.id != widget.diagram.id) {
      _animCtrl.reset();
      _animCtrl.repeat();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          children: [
            // ── Animated diagram painter ──────────────────────────────────
            AnimatedBuilder(
              animation: _animCtrl,
              builder: (_, __) => CustomPaint(
                size: size,
                painter: _painterFor(
                  widget.diagram,
                  _animCtrl.value,
                  Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            ),

            // ── Hotspot tap targets ────────────────────────────────────────
            ..._buildHotspots(size, widget.diagram.hotspots),
          ],
        );
      },
    );
  }

  List<Widget> _buildHotspots(Size size, List<HotspotDefinition> hotspots) {
    return hotspots.map((h) {
      final left = h.tapArea.left * size.width;
      final top = h.tapArea.top * size.height;
      final width = h.tapArea.width * size.width;
      final height = h.tapArea.height * size.height;

      return Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: GestureDetector(
          onTap: () => widget.onHotspotTap(h),
          child: Container(
            decoration: BoxDecoration(
              color: widget.diagram.accentColor.withValues(alpha: 0.08),
              border: Border.all(
                color: widget.diagram.accentColor.withValues(alpha: 0.35),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.diagram.accentColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  h.label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  DiagramPainter _painterFor(
      DiagramDefinition d, double t, bool isDark) {
    switch (d.id) {
      case 'master_slave':
        return MasterSlavePainter(t: t, isDark: isDark, accent: d.accentColor);
      case 'view_sync':
        return ViewSyncPainter(t: t, isDark: isDark, accent: d.accentColor);
      case 'ssh_flow':
        return SshFlowPainter(t: t, isDark: isDark, accent: d.accentColor);
      case 'kml_propagation':
        return KmlPropagationPainter(
            t: t, isDark: isDark, accent: d.accentColor);
      default:
        return MasterSlavePainter(t: t, isDark: isDark, accent: d.accentColor);
    }
  }
}

// ─── Base Painter ─────────────────────────────────────────────────────────────

abstract class DiagramPainter extends CustomPainter {
  final double t;
  final bool isDark;
  final Color accent;

  const DiagramPainter(
      {required this.t, required this.isDark, required this.accent});

  Color get bg =>
      isDark ? const Color(0xFF141929) : const Color(0xFFEEF0F7);
  Color get nodeColor =>
      isDark ? const Color(0xFF1C2236) : Colors.white;
  Color get textColor =>
      isDark ? Colors.white : const Color(0xFF1A1A2E);
  Color get subtextColor =>
      isDark ? Colors.white54 : Colors.black54;

  Paint get _linePaint => Paint()
    ..color = accent.withValues(alpha: 0.8)
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;

  Paint get _nodePaint => Paint()
    ..color = nodeColor
    ..style = PaintingStyle.fill;

  Paint get _nodeBorderPaint => Paint()
    ..color = accent.withValues(alpha: 0.8)
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;

  void drawNode(
    Canvas canvas,
    Rect rect, {
    String? label,
    String? sublabel,
    IconData? icon,
    double radius = 2,
  }) {
    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      _nodePaint,
    );
    // Border
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      _nodeBorderPaint,
    );

    // UML style divider line
    final lineY = rect.top + 24.0;
    if (rect.height > 30) {
      canvas.drawLine(
        Offset(rect.left, lineY),
        Offset(rect.right, lineY),
        _nodeBorderPaint..strokeWidth = 1.0,
      );
    }

    // Label
    if (label != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(rect.center.dx - tp.width / 2, rect.top + 6),
      );

      // Sublabel
      if (sublabel != null && rect.height > 30) {
        final sub = TextPainter(
          text: TextSpan(
            text: sublabel,
            style: TextStyle(fontSize: 9, color: subtextColor, fontFamily: 'monospace'),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 2,
        )..layout(maxWidth: rect.width - 8);
        sub.paint(
          canvas,
          Offset(rect.left + 6, lineY + 6),
        );
      }
    }
  }

  void drawArrow(Canvas canvas, Offset from, Offset to, {Paint? paint, bool isDashed = false}) {
    final p = paint ?? _linePaint;
    
    if (isDashed) {
      final double distance = (to - from).distance;
      final double dashWidth = 5.0;
      final double dashSpace = 4.0;
      double startX = from.dx;
      double startY = from.dy;
      final double dirX = (to.dx - from.dx) / distance;
      final double dirY = (to.dy - from.dy) / distance;
      double currentDistance = 0;
      while (currentDistance < distance) {
        final endX = startX + dirX * dashWidth;
        final endY = startY + dirY * dashWidth;
        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), p);
        startX = endX + dirX * dashSpace;
        startY = endY + dirY * dashSpace;
        currentDistance += dashWidth + dashSpace;
      }
    } else {
      canvas.drawLine(from, to, p);
    }

    // Arrowhead (sharp, open UML style)
    final angle = (to - from).direction;
    const arrowSize = 6.0;
    final path = Path()
      ..moveTo(to.dx - arrowSize * cos(angle - 0.5), to.dy - arrowSize * sin(angle - 0.5))
      ..lineTo(to.dx, to.dy)
      ..lineTo(to.dx - arrowSize * cos(angle + 0.5), to.dy - arrowSize * sin(angle + 0.5));
      
    canvas.drawPath(
      path,
      Paint()
        ..color = p.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void drawLabel(Canvas canvas, Offset center, String text,
      {double fontSize = 10}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, color: subtextColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }
}

// ─── Painter 1: Master-Slave Topology ────────────────────────────────────────

class MasterSlavePainter extends DiagramPainter {
  const MasterSlavePainter(
      {required super.t, required super.isDark, required super.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Pulsing connection lines
    final pulse = (sin(t * pi * 2) * 0.5 + 0.5);
    final linePulse = Paint()
      ..color = accent.withValues(alpha: 0.2 + pulse * 0.35)
      ..strokeWidth = 1.5 + pulse
      ..style = PaintingStyle.stroke;

    // ── Master node ──────────────────────────────────────────────────────
    final masterRect = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.15),
      width: w * 0.3,
      height: h * 0.15,
    );
    drawNode(canvas, masterRect, label: 'Master', sublabel: 'SSH + Web Server');

    // ── Switch ───────────────────────────────────────────────────────────
    final switchRect = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.46),
      width: w * 0.22,
      height: h * 0.10,
    );
    drawNode(canvas, switchRect, label: 'Switch', sublabel: 'Gigabit LAN');

    // Connect master → switch
    drawArrow(canvas, Offset(w * 0.5, masterRect.bottom),
        Offset(w * 0.5, switchRect.top),
        paint: linePulse);

    // ── Slave nodes ───────────────────────────────────────────────────────
    final slaveCount = 3;
    final slaveWidth = w * 0.22;
    final slaveHeight = h * 0.13;
    final slaveY = h * 0.73;
    final slaveSpacing = (w - slaveWidth * slaveCount) / (slaveCount + 1);

    for (int i = 0; i < slaveCount; i++) {
      final slaveX =
          slaveSpacing * (i + 1) + slaveWidth * i + slaveWidth / 2;
      final slaveRect = Rect.fromCenter(
        center: Offset(slaveX, slaveY),
        width: slaveWidth,
        height: slaveHeight,
      );
      drawNode(canvas, slaveRect,
          label: 'Slave ${i + 1}', sublabel: 'Google Earth');

      // Connect switch → slave
      drawArrow(
        canvas,
        Offset(w * 0.5, switchRect.bottom),
        Offset(slaveX, slaveRect.top),
        paint: linePulse,
      );
    }
  }

  @override
  bool shouldRepaint(MasterSlavePainter old) =>
      old.t != t || old.isDark != isDark;
}

// ─── Painter 2: ViewSync Protocol ────────────────────────────────────────────

class ViewSyncPainter extends DiagramPainter {
  const ViewSyncPainter(
      {required super.t, required super.isDark, required super.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Master camera ─────────────────────────────────────────────────────
    final masterRect = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.15),
      width: w * 0.32,
      height: h * 0.14,
    );
    drawNode(canvas, masterRect, label: 'Master', sublabel: 'Camera (Source)');

    // ── Travelling UDP packets ─────────────────────────────────────────────
    final packetPositions = [0.2, 0.5, 0.8];
    for (final basePhase in packetPositions) {
      final phase = (t + basePhase) % 1.0;
      final px = w * 0.1 + w * 0.8 * phase;
      final py = h * 0.44;

      final packetPaint = Paint()
        ..color = accent.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(px, py), 5, packetPaint);
    }

    // UDP broadcast line
    canvas.drawLine(
      Offset(w * 0.1, h * 0.44),
      Offset(w * 0.9, h * 0.44),
      Paint()
        ..color = accent.withValues(alpha: 0.2)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    drawLabel(canvas, Offset(w * 0.5, h * 0.38), 'UDP Broadcast (port 21567)',
        fontSize: 9);

    // ── Slave cameras ─────────────────────────────────────────────────────
    final slaveCount = 3;
    final slaveWidth = w * 0.22;
    final slaveHeight = h * 0.12;
    final slaveY = h * 0.74;
    final spacing = (w - slaveWidth * slaveCount) / (slaveCount + 1);
    final offsets = [-35, 0, 35];

    for (int i = 0; i < slaveCount; i++) {
      final sx = spacing * (i + 1) + slaveWidth * i + slaveWidth / 2;
      final sr = Rect.fromCenter(
        center: Offset(sx, slaveY),
        width: slaveWidth,
        height: slaveHeight,
      );
      drawNode(canvas, sr,
          label: 'Slave ${i + 1}',
          sublabel: '${offsets[i] > 0 ? '+' : ''}${offsets[i]}°');

      // Drop arrow from broadcast line to slave
      drawArrow(
        canvas,
        Offset(sx, h * 0.44),
        Offset(sx, sr.top),
        isDashed: true,
        paint: Paint()
          ..color = accent.withValues(alpha: 0.35)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(ViewSyncPainter old) =>
      old.t != t || old.isDark != isDark;
}

// ─── Painter 3: SSH Flow ─────────────────────────────────────────────────────

class SshFlowPainter extends DiagramPainter {
  const SshFlowPainter(
      {required super.t, required super.isDark, required super.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Tablet (left) ─────────────────────────────────────────────────────
    final tabletRect = Rect.fromCenter(
      center: Offset(w * 0.18, h * 0.38),
      width: w * 0.26,
      height: h * 0.28,
    );
    drawNode(canvas, tabletRect, label: 'Tablet App', sublabel: 'dartssh2');

    // ── Master node (right) ───────────────────────────────────────────────
    final masterRect = Rect.fromCenter(
      center: Offset(w * 0.82, h * 0.38),
      width: w * 0.26,
      height: h * 0.28,
    );
    drawNode(canvas, masterRect, label: 'Master Node', sublabel: 'bash + sftp');

    // ── SSH arrow (with animated dot) ─────────────────────────────────────
    final startX = tabletRect.right;
    final endX = masterRect.left;
    final arrowY = h * 0.33;
    final returnY = h * 0.45;

    // Forward arrow (command)
    drawArrow(canvas, Offset(startX, arrowY), Offset(endX, arrowY));
    drawLabel(canvas, Offset(w * 0.5, arrowY - 10), 'SSH command (client.run)',
        fontSize: 9);

    // Animated dot on forward arrow
    final dotX = startX + (endX - startX) * t;
    canvas.drawCircle(
      Offset(dotX, arrowY),
      5,
      Paint()..color = accent,
    );

    // Return arrow (stdout)
    final returnPaint = Paint()
      ..color = const Color(0xFF55EFC4).withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    drawArrow(canvas, Offset(endX, returnY), Offset(startX, returnY),
        paint: returnPaint, isDashed: true);
    drawLabel(canvas, Offset(w * 0.5, returnY + 10), 'stdout / stderr',
        fontSize: 9);

    // Return dot
    final retDotX = endX - (endX - startX) * t;
    canvas.drawCircle(
      Offset(retDotX, returnY),
      5,
      Paint()..color = const Color(0xFF55EFC4),
    );

    // ── SFTP label (bottom) ───────────────────────────────────────────────
    drawLabel(canvas, Offset(w * 0.5, h * 0.72),
        'SFTP upload: model files & scripts',
        fontSize: 9);
    canvas.drawLine(
      Offset(w * 0.18, h * 0.68),
      Offset(w * 0.82, h * 0.68),
      Paint()
        ..color = accent.withValues(alpha: 0.25)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(SshFlowPainter old) =>
      old.t != t || old.isDark != isDark;
}

// ─── Painter 4: KML Propagation ──────────────────────────────────────────────

class KmlPropagationPainter extends DiagramPainter {
  const KmlPropagationPainter(
      {required super.t, required super.isDark, required super.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Web server (top) ──────────────────────────────────────────────────
    final serverRect = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.12),
      width: w * 0.36,
      height: h * 0.13,
    );
    drawNode(canvas, serverRect, label: 'Apache :81', sublabel: '/var/www/html');

    // ── master.kml (middle) ───────────────────────────────────────────────
    final kmlRect = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.39),
      width: w * 0.30,
      height: h * 0.13,
    );
    drawNode(canvas, kmlRect, label: 'master.kml', sublabel: 'NetworkLink hub');

    // Arrow: server → master.kml
    drawArrow(
      canvas,
      Offset(w * 0.5, serverRect.bottom),
      Offset(w * 0.5, kmlRect.top),
    );

    // ── Animated file packet (server → kml) ───────────────────────────────
    final pY = serverRect.bottom +
        (kmlRect.top - serverRect.bottom) * ((t * 2) % 1.0);
    canvas.drawCircle(
      Offset(w * 0.5, pY),
      5,
      Paint()..color = accent,
    );

    // ── Slave GE instances (bottom) ───────────────────────────────────────
    final slaveCount = 3;
    final slaveWidth = w * 0.22;
    final slaveHeight = h * 0.12;
    final slaveY = h * 0.76;
    final spacing = (w - slaveWidth * slaveCount) / (slaveCount + 1);

    for (int i = 0; i < slaveCount; i++) {
      final sx = spacing * (i + 1) + slaveWidth * i + slaveWidth / 2;
      final sr = Rect.fromCenter(
        center: Offset(sx, slaveY),
        width: slaveWidth,
        height: slaveHeight,
      );
      drawNode(canvas, sr, label: 'Slave ${i + 1}', sublabel: 'Google Earth');

      // NetworkLink pull arrow
      drawArrow(
        canvas,
        Offset(w * 0.5, kmlRect.bottom),
        Offset(sx, sr.top),
        isDashed: true,
        paint: Paint()
          ..color = accent.withValues(alpha: 0.4)
          ..strokeWidth = 1.3
          ..style = PaintingStyle.stroke,
      );

      // Animated pull dot
      final phase = (t + i * 0.33) % 1.0;
      final dotStart = Offset(w * 0.5, kmlRect.bottom);
      final dotEnd = Offset(sx, sr.top);
      final dotPos = Offset.lerp(dotStart, dotEnd, phase)!;
      canvas.drawCircle(
        dotPos,
        4,
        Paint()
          ..color = const Color(0xFF55EFC4).withValues(alpha: 0.8),
      );
    }

    drawLabel(canvas, Offset(w * 0.5, h * 0.60),
        '← NetworkLink poll →', fontSize: 9);
  }

  @override
  bool shouldRepaint(KmlPropagationPainter old) =>
      old.t != t || old.isDark != isDark;
}
