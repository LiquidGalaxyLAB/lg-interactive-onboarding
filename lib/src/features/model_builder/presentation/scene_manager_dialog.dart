import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lg_interactive_onboarding/src/features/model_builder/data/scene_models.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/data/scene_repository.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/providers/scene_providers.dart';

/// Dialog for scene lifecycle operations: New, Load, Save, Delete, Rename.
///
/// Launched from the Model Builder screen's app bar.
class SceneManagerDialog extends ConsumerStatefulWidget {
  const SceneManagerDialog({super.key});

  /// Convenience method to show the dialog.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const SceneManagerDialog(),
    );
  }

  @override
  ConsumerState<SceneManagerDialog> createState() =>
      _SceneManagerDialogState();
}

class _SceneManagerDialogState extends ConsumerState<SceneManagerDialog> {
  List<SceneMetadata>? _scenes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadScenes();
  }

  Future<void> _loadScenes() async {
    final repo = ref.read(sceneRepositoryProvider);
    final scenes = await repo.listScenes();
    if (mounted) {
      setState(() {
        _scenes = scenes;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sceneState = ref.watch(sceneProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // ─── Drag handle ──────────────────────────────────────────
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ─── Header ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.folder_open_rounded,
                      color: Color(0xFF6C5CE7)),
                  const SizedBox(width: 12),
                  Text(
                    'Scene Manager',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: () => _showNewSceneDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Active scene info ────────────────────────────────────
            if (sceneState.hasScene)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.play_circle_outline,
                        size: 18, color: Color(0xFF6C5CE7)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sceneState.activeScene!.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${sceneState.activeScene!.modelCount} models'
                            '${sceneState.isDirty ? ' • Unsaved' : ''}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: sceneState.isDirty
                                  ? const Color(0xFFFDAA5E)
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (sceneState.isDirty)
                      TextButton.icon(
                        onPressed: () {
                          ref.read(sceneProvider.notifier).saveScene();
                        },
                        icon: const Icon(Icons.save, size: 14),
                        label: const Text('Save'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFDAA5E),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                      ),
                    TextButton(
                      onPressed: () {
                        if (sceneState.isDirty) {
                          _confirmClose(context);
                        } else {
                          ref.read(sceneProvider.notifier).closeScene();
                          Navigator.pop(context);
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),
            Divider(color: theme.dividerColor.withValues(alpha: 0.3)),

            // ─── Saved scenes list ────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_scenes == null || _scenes!.isEmpty)
                      ? Center(
                          child: Text(
                            'No saved scenes yet.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _scenes!.length,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          itemBuilder: (context, index) {
                            final meta = _scenes![index];
                            final isActive =
                                sceneState.activeScene?.id == meta.id;

                            return _SceneListTile(
                              meta: meta,
                              isActive: isActive,
                              onLoad: () => _loadScene(meta.id),
                              onDelete: () =>
                                  _confirmDeleteScene(context, meta),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  void _showNewSceneDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Scene'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Scene Name',
            hintText: 'e.g., My Park, City Centre',
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
                ref.read(sceneProvider.notifier).newScene(name);
                Navigator.pop(ctx);
                Navigator.pop(context); // Close the dialog sheet
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadScene(String sceneId) async {
    await ref.read(sceneProvider.notifier).loadScene(sceneId);
    if (mounted) Navigator.pop(context);
  }

  void _confirmClose(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
            'You have unsaved changes. Close without saving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(sceneProvider.notifier).closeScene();
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(sceneProvider.notifier).saveScene();
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save & Close'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteScene(BuildContext context, SceneMetadata meta) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Scene'),
        content: Text('Permanently delete "${meta.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final repo = ref.read(sceneRepositoryProvider);
              await repo.deleteScene(meta.id);

              // If this was the active scene, close it
              if (ref.read(sceneProvider).activeScene?.id == meta.id) {
                ref.read(sceneProvider.notifier).closeScene();
              }

              if (!context.mounted) return;
              Navigator.pop(ctx);
              _loadScenes(); // Refresh the list
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

// ─── Scene List Tile ────────────────────────────────────────────────────────

class _SceneListTile extends StatelessWidget {
  final SceneMetadata meta;
  final bool isActive;
  final VoidCallback onLoad;
  final VoidCallback onDelete;

  const _SceneListTile({
    required this.meta,
    required this.isActive,
    required this.onLoad,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isActive
            ? const Color(0xFF6C5CE7).withValues(alpha: 0.05)
            : theme.colorScheme.surface,
        border: Border.all(
          color: isActive
              ? const Color(0xFF6C5CE7).withValues(alpha: 0.2)
              : theme.dividerColor.withValues(alpha: 0.15),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Icon(
          isActive ? Icons.folder_open : Icons.folder_outlined,
          color: isActive
              ? const Color(0xFF6C5CE7)
              : theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        title: Text(
          meta.name,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${meta.modelCount} models • ${_formatDate(meta.lastModified)}',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isActive)
              TextButton(
                onPressed: onLoad,
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 11),
                ),
                child: const Text('Load'),
              ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 18,
                  color: theme.colorScheme.error.withValues(alpha: 0.6)),
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
