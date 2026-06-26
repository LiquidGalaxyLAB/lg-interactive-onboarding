import 'package:flutter/material.dart';

// ─── Hotspot Definition ────────────────────────────────────────────────────────

/// A tappable region on a diagram with explanatory content.
class HotspotDefinition {
  /// Stable ID for analytics tracking.
  final String id;

  /// Short label shown as a floating tag on the diagram.
  final String label;

  /// Tap area in **relative coordinates** (0.0 to 1.0 for both axes).
  ///
  /// At render time this is multiplied by the actual diagram size.
  final Rect tapArea;

  /// Title shown in the detail bottom sheet.
  final String detailTitle;

  /// Full explanation shown in the detail bottom sheet.
  final String detailBody;

  /// Optional curriculum module ID that links to this concept.
  final String? relatedModuleId;

  /// Icon shown in the bottom sheet header.
  final IconData icon;

  const HotspotDefinition({
    required this.id,
    required this.label,
    required this.tapArea,
    required this.detailTitle,
    required this.detailBody,
    required this.icon,
    this.relatedModuleId,
  });
}

// ─── Diagram Definition ───────────────────────────────────────────────────────

/// Describes a single interactive diagram in the Architecture Explorer.
///
/// ### Adding new diagrams (modularity)
/// Create a new [DiagramDefinition] in [DiagramRepository.all] and add a
/// matching painter case in `diagram_viewer.dart`. No other changes are needed.
class DiagramDefinition {
  /// Stable ID used for analytics and navigation.
  final String id;

  final String title;
  final String subtitle;
  final IconData icon;

  /// Accent color used for diagram chrome.
  final Color accentColor;

  final List<HotspotDefinition> hotspots;

  const DiagramDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.hotspots,
  });


}
