import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lg_interactive_onboarding/src/features/architecture_explorer/data/diagram_model.dart';
import 'package:lg_interactive_onboarding/src/features/architecture_explorer/data/diagram_repository.dart';

// ─── Diagram list ──────────────────────────────────────────────────────────────

final diagramListProvider = Provider<List<DiagramDefinition>>((ref) {
  return DiagramRepository.all;
});

// ─── Selected diagram ─────────────────────────────────────────────────────────

class SelectedDiagramIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    final diagrams = ref.watch(diagramListProvider);
    return diagrams.isNotEmpty ? diagrams.first.id : null;
  }
  void set(String? value) => state = value;
}

/// Currently selected diagram ID.
///
/// Can be pre-set by the Curriculum Engine (e.g., Module 6 opens a specific
/// diagram) by overriding this provider before navigating.
final selectedDiagramIdProvider = NotifierProvider<SelectedDiagramIdNotifier, String?>(
  SelectedDiagramIdNotifier.new,
);

/// Derived: the currently selected [DiagramDefinition].
final selectedDiagramProvider = Provider<DiagramDefinition?>((ref) {
  final id = ref.watch(selectedDiagramIdProvider);
  if (id == null) return null;
  return DiagramRepository.byId(id);
});
