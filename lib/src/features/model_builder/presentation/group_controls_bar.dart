import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lg_interactive_onboarding/src/features/model_builder/providers/scene_providers.dart';

/// A bottom action bar for scene-level group operations.
///
/// Shows contextual actions based on the current selection state:
/// - Group (2+ nodes selected)
/// - Ungroup (1 group selected)
/// - Duplicate (1+ nodes selected)
/// - Delete (1+ nodes selected)
class GroupControlsBar extends ConsumerWidget {
  const GroupControlsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sceneState = ref.watch(sceneProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!sceneState.hasScene || !sceneState.hasSelection) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E20) : Colors.white,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.3),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Selection count badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${sceneState.selectedNodeIds.length} selected',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6C5CE7),
                ),
              ),
            ),

            const SizedBox(width: 8),
            const Spacer(),

            // ─── Group button ─────────────────────────────────────────
            _ActionButton(
              icon: Icons.create_new_folder_outlined,
              label: 'Group',
              enabled: sceneState.canGroup,
              color: const Color(0xFF00B894),
              onPressed: () => _promptGroupName(context, ref),
            ),

            const SizedBox(width: 6),

            // ─── Ungroup button ───────────────────────────────────────
            _ActionButton(
              icon: Icons.unfold_more_rounded,
              label: 'Ungroup',
              enabled: sceneState.canUngroup,
              color: const Color(0xFFFDAA5E),
              onPressed: () {
                final selectedId = sceneState.selectedNodeIds.first;
                ref.read(sceneProvider.notifier).ungroupNode(selectedId);
              },
            ),

            const SizedBox(width: 6),

            // ─── Duplicate button ─────────────────────────────────────
            _ActionButton(
              icon: Icons.copy_rounded,
              label: 'Dup',
              enabled: sceneState.hasSelection,
              color: const Color(0xFF0984E3),
              onPressed: () {
                for (final id in sceneState.selectedNodeIds) {
                  ref.read(sceneProvider.notifier).duplicateNode(id);
                }
              },
            ),

            const SizedBox(width: 6),

            // ─── Delete button ────────────────────────────────────────
            _ActionButton(
              icon: Icons.delete_outline_rounded,
              label: 'Del',
              enabled: sceneState.hasSelection,
              color: theme.colorScheme.error,
              onPressed: () => _confirmDelete(context, ref, sceneState),
            ),

            const SizedBox(width: 6),

            // ─── Clear selection ──────────────────────────────────────
            IconButton(
              icon: Icon(Icons.close, size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
              tooltip: 'Clear selection',
              onPressed: () =>
                  ref.read(sceneProvider.notifier).clearSelection(),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  void _promptGroupName(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: 'Group');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Group Name',
            hintText: 'e.g., Buildings, Trees',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(sceneProvider.notifier).groupSelected(name);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Group'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, SceneState sceneState) {
    final count = sceneState.selectedNodeIds.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete'),
        content: Text(
          'Remove $count selected item${count == 1 ? '' : 's'} from the scene?'
          '\n\nDeleting a group also removes all its children.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              for (final id in sceneState.selectedNodeIds.toList()) {
                ref.read(sceneProvider.notifier).removeNode(id);
              }
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─── Action Button ──────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled
        ? color
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2);

    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: enabled ? color.withValues(alpha: 0.08) : Colors.transparent,
          border: Border.all(
            color: enabled ? color.withValues(alpha: 0.2) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: effectiveColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: effectiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
