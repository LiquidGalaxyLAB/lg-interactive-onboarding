import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:lg_interactive_onboarding/src/common/curriculum/analytics_service.dart';
import 'package:lg_interactive_onboarding/src/features/architecture_explorer/data/diagram_model.dart';
import 'package:lg_interactive_onboarding/src/features/architecture_explorer/providers/architecture_providers.dart';
import 'package:lg_interactive_onboarding/src/features/architecture_explorer/presentation/diagram_viewer.dart';

/// Full-screen interactive Architecture Explorer.
///
/// Accessible from:
/// - The "Learn" tab (dedicated entry card).
/// - The ⓘ icon in any screen's AppBar.
/// - Curriculum module steps that reference [AppRoutes.architectureExplorer].
///
/// ### Adding new diagrams
/// Register a new [DiagramDefinition] in [DiagramRepository.all] and add the
/// corresponding painter in `diagram_viewer.dart`. This screen auto-discovers
/// it via [diagramListProvider].
class ArchitectureExplorerScreen extends ConsumerWidget {
  /// Optional: pre-select a diagram by ID (used by curriculum modules).
  final String? initialDiagramId;

  const ArchitectureExplorerScreen({
    super.key,
    this.initialDiagramId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pre-select diagram if provided
    if (initialDiagramId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedDiagramIdProvider.notifier).set(initialDiagramId);
      });
    }

    final diagrams = ref.watch(diagramListProvider);
    final selectedId = ref.watch(selectedDiagramIdProvider);
    final selectedDiagram = ref.watch(selectedDiagramProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Architecture Explorer',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: isDark ? const Color(0xFF141929) : Colors.white,
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          // ── Diagram selector tab row ───────────────────────────────────
          _DiagramTabRow(
            diagrams: diagrams,
            selectedId: selectedId,
            isDark: isDark,
            onSelect: (id) =>
                ref.read(selectedDiagramIdProvider.notifier).set(id),
          ),

          // ── Diagram viewer ─────────────────────────────────────────────
          Expanded(
            child: selectedDiagram == null
                ? const Center(child: CircularProgressIndicator())
                : _DiagramBody(
                    diagram: selectedDiagram,
                    isDark: isDark,
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Diagram Tab Row ──────────────────────────────────────────────────────────

class _DiagramTabRow extends StatelessWidget {
  final List<DiagramDefinition> diagrams;
  final String? selectedId;
  final bool isDark;
  final void Function(String id) onSelect;

  const _DiagramTabRow({
    required this.diagrams,
    required this.selectedId,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      color: isDark ? const Color(0xFF141929) : Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: diagrams.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = diagrams[i];
          final isSelected = d.id == selectedId;
          return GestureDetector(
            onTap: () => onSelect(d.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? d.accentColor.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? d.accentColor.withValues(alpha: 0.5)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.1)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(d.emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    d.title,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? d.accentColor
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Diagram Body ─────────────────────────────────────────────────────────────

class _DiagramBody extends ConsumerWidget {
  final DiagramDefinition diagram;
  final bool isDark;

  const _DiagramBody({required this.diagram, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Diagram title
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(diagram.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      diagram.title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                    ),
                    Text(
                      diagram.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Hint bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Icon(Icons.touch_app_outlined,
                  size: 13,
                  color: diagram.accentColor.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                'Tap highlighted areas to learn more',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),

        // Diagram
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0E1321)
                      : const Color(0xFFF0F2F8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: diagram.accentColor.withValues(alpha: 0.15),
                  ),
                ),
                child: InteractiveViewer(
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.8,
                  maxScale: 3.0,
                  child: DiagramViewer(
                    diagram: diagram,
                    onHotspotTap: (hotspot) {
                      // Track analytics
                      ref.read(analyticsServiceProvider).recordDiagramView(
                            diagram.id,
                          );
                      // Show detail bottom sheet
                      _showHotspotDetail(context, hotspot, diagram, isDark,
                          ref);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),
      ],
    );
  }

  void _showHotspotDetail(
    BuildContext context,
    HotspotDefinition hotspot,
    DiagramDefinition diagram,
    bool isDark,
    WidgetRef ref,
  ) {
    // Also record per-hotspot view for finer-grained analytics
    ref.read(analyticsServiceProvider).recordDiagramView('${diagram.id}_${hotspot.id}');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HotspotDetailSheet(
        hotspot: hotspot,
        diagram: diagram,
        isDark: isDark,
      ),
    );
  }
}

// ─── Hotspot Detail Bottom Sheet ─────────────────────────────────────────────

class _HotspotDetailSheet extends StatelessWidget {
  final HotspotDefinition hotspot;
  final DiagramDefinition diagram;
  final bool isDark;

  const _HotspotDetailSheet({
    required this.hotspot,
    required this.diagram,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1A1F33) : Colors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: diagram.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          hotspot.icon,
                          color: diagram.accentColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hotspot.detailTitle,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A2E),
                              ),
                            ),
                            Text(
                              diagram.title,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: diagram.accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Divider
                  Divider(
                    color: isDark ? Colors.white12 : Colors.black12,
                    height: 1,
                  ),

                  const SizedBox(height: 16),

                  // Body
                  Text(
                    hotspot.detailBody,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.7,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),

                  // Related module CTA
                  if (hotspot.relatedModuleId != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: diagram.accentColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: diagram.accentColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.school_outlined,
                              color: diagram.accentColor, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Learn this in the Curriculum Engine',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: diagram.accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: diagram.accentColor),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
