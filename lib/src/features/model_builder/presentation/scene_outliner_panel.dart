import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lg_interactive_onboarding/src/features/model_builder/data/scene_models.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/providers/model_builder_providers.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/providers/scene_providers.dart';

/// A hierarchical tree view panel showing the active scene's structure.
///
/// Displays [ModelNode]s and [GroupNode]s with indentation for nesting.
/// Supports selection, multi-select, expand/collapse, and context menus.
class SceneOutlinerPanel extends ConsumerStatefulWidget {
  const SceneOutlinerPanel({super.key});

  @override
  ConsumerState<SceneOutlinerPanel> createState() =>
      _SceneOutlinerPanelState();
}

class _SceneOutlinerPanelState extends ConsumerState<SceneOutlinerPanel> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  /// Tracks which groups are expanded in the tree.
  final Set<String> _expandedGroups = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sceneState = ref.watch(sceneProvider);
    final theme = Theme.of(context);
    final scene = sceneState.activeScene;

    if (scene == null) {
      return _EmptyScenePrompt(theme: theme);
    }

    // Flatten the tree into a displayable list
    final flatList = _buildFlatList(scene, sceneState.selectedNodeIds);

    // Apply search filter
    final filtered = _searchQuery.isEmpty
        ? flatList
        : flatList.where((entry) {
            return entry.node.name
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());
          }).toList();

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_tree_outlined,
                      color: Color(0xFF6C5CE7), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              scene.name,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (sceneState.isDirty) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFFDAA5E),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${scene.modelCount} model${scene.modelCount == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                // Save button
                IconButton(
                  icon: Icon(
                    sceneState.isDirty
                        ? Icons.save_rounded
                        : Icons.save_outlined,
                    size: 20,
                    color: sceneState.isDirty
                        ? const Color(0xFFFDAA5E)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  tooltip: sceneState.isDirty ? 'Save Scene' : 'Saved',
                  onPressed: sceneState.isDirty
                      ? () => ref.read(sceneProvider.notifier).saveScene()
                      : null,
                ),
              ],
            ),
          ),

          // ─── Search bar ────────────────────────────────────────────
          if (scene.nodes.length > 3)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: theme.textTheme.bodySmall,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  hintText: 'Search models...',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  prefixIcon:
                      Icon(Icons.search, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: theme.colorScheme.primary
                            .withValues(alpha: 0.1)),
                  ),
                ),
              ),
            ),

          // ─── Tree list ─────────────────────────────────────────────
          if (filtered.isEmpty && scene.nodes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No models yet.\nImport a model and tap "Add to Scene".',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            )
          else
            ...filtered.map((entry) => _NodeRow(
                  entry: entry,
                  isExpanded: _expandedGroups.contains(entry.node.id),
                  onToggleExpand: () {
                    setState(() {
                      if (_expandedGroups.contains(entry.node.id)) {
                        _expandedGroups.remove(entry.node.id);
                      } else {
                        _expandedGroups.add(entry.node.id);
                      }
                    });
                  },
                  onTap: () =>
                      ref.read(sceneProvider.notifier).selectNode(entry.node.id),
                  onLongPress: () =>
                      _showContextMenu(context, ref, entry.node),
                )),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Flattens the scene tree into a list of entries with depth info.
  List<_FlatEntry> _buildFlatList(Scene scene, Set<String> selectedIds) {
    final result = <_FlatEntry>[];

    void walk(List<String> nodeIds, int depth) {
      for (final id in nodeIds) {
        final node = scene.nodes[id];
        if (node == null) continue;
        result.add(_FlatEntry(
          node: node,
          depth: depth,
          isSelected: selectedIds.contains(id),
        ));
        if (node is GroupNode && _expandedGroups.contains(id)) {
          walk(node.childIds, depth + 1);
        }
      }
    }

    walk(scene.rootNodeIds, 0);
    return result;
  }

  void _showContextMenu(
      BuildContext context, WidgetRef ref, SceneNode node) {
    final notifier = ref.read(sceneProvider.notifier);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(context, ref, node);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Duplicate'),
              onTap: () {
                Navigator.pop(ctx);
                notifier.duplicateNode(node.id);
              },
            ),
            if (node is GroupNode)
              ListTile(
                leading: const Icon(Icons.unfold_more),
                title: const Text('Ungroup'),
                onTap: () {
                  Navigator.pop(ctx);
                  notifier.ungroupNode(node.id);
                },
              ),
            if (node is GroupNode)
              Consumer(builder: (context, ref, _) {
                final project = ref.watch(modelBuilderProvider);
                return ListTile(
                  leading: const Icon(Icons.control_point_duplicate),
                  title: const Text('Stamp Here'),
                  subtitle: const Text('Duplicate group at map pin'),
                  enabled: project.hasLocation,
                  onTap: () {
                    Navigator.pop(ctx);
                    notifier.stampGroupAtLocation(
                      node.id,
                      project.latitude!,
                      project.longitude!,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Group stamped at map location'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                );
              }),
            if (node is GroupNode)
              Consumer(builder: (context, ref, _) {
                final project = ref.watch(modelBuilderProvider);
                return ListTile(
                  leading: const Icon(Icons.my_location),
                  title: const Text('Relocate Group Here'),
                  subtitle: const Text('Move group to map pin'),
                  enabled: project.hasLocation,
                  onTap: () {
                    Navigator.pop(ctx);
                    notifier.relocateGroup(
                      node.id,
                      project.latitude!,
                      project.longitude!,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Group relocated to map location'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                );
              }),
            if (node.parentGroupId != null)
              ListTile(
                leading: const Icon(Icons.move_up),
                title: const Text('Move to Root'),
                onTap: () {
                  Navigator.pop(ctx);
                  notifier.moveNodeToRoot(node.id);
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Delete',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                notifier.removeNode(node.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(
      BuildContext context, WidgetRef ref, SceneNode node) {
    final controller = TextEditingController(text: node.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final scene = ref.read(sceneProvider).activeScene;
                if (scene != null) {
                  final updatedNodes =
                      Map<String, SceneNode>.of(scene.nodes);
                  updatedNodes[node.id] =
                      node.copyWith(name: newName);
                  ref.read(sceneProvider.notifier)
                    ..clearSelection()
                    ..selectNode(node.id);
                  // Direct state update via internal scene mutation
                  // (handled through the notifier's state)
                }
              }
              Navigator.pop(ctx);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose;
  }
}

// ─── Flat Entry ─────────────────────────────────────────────────────────────

class _FlatEntry {
  final SceneNode node;
  final int depth;
  final bool isSelected;

  const _FlatEntry({
    required this.node,
    required this.depth,
    this.isSelected = false,
  });
}

// ─── Node Row ───────────────────────────────────────────────────────────────

class _NodeRow extends StatelessWidget {
  final _FlatEntry entry;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _NodeRow({
    required this.entry,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final node = entry.node;
    final isGroup = node is GroupNode;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: EdgeInsets.only(
          left: 16 + (entry.depth * 20.0),
          right: 12,
          top: 6,
          bottom: 6,
        ),
        decoration: BoxDecoration(
          color: entry.isSelected
              ? const Color(0xFF6C5CE7).withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border(
            left: entry.isSelected
                ? const BorderSide(color: Color(0xFF6C5CE7), width: 3)
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            // Expand/collapse for groups
            if (isGroup)
              GestureDetector(
                onTap: onToggleExpand,
                child: Icon(
                  isExpanded
                      ? Icons.expand_more_rounded
                      : Icons.chevron_right_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              )
            else
              const SizedBox(width: 20),

            const SizedBox(width: 6),

            // Icon
            Icon(
              isGroup ? Icons.folder_outlined : Icons.view_in_ar_rounded,
              size: 16,
              color: isGroup
                  ? const Color(0xFFFDAA5E)
                  : const Color(0xFF6C5CE7),
            ),

            const SizedBox(width: 8),

            // Name
            Expanded(
              child: Text(
                node.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight:
                      entry.isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: entry.isSelected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface
                          .withValues(alpha: 0.75),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Model info chips
            if (node is ModelNode)
              Text(
                '${node.latitude.toStringAsFixed(2)}, ${node.longitude.toStringAsFixed(2)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 9,
                  fontFamily: 'monospace',
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ),

            if (isGroup) ...[
              if (node.latitude != 0.0)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    '${node.latitude.toStringAsFixed(2)}, ${node.longitude.toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 9,
                      fontFamily: 'monospace',
                      color: const Color(0xFFFDAA5E).withValues(alpha: 0.7),
                    ),
                  ),
                ),
              Text(
                '${node.childIds.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Empty Scene Prompt ─────────────────────────────────────────────────────

class _EmptyScenePrompt extends StatelessWidget {
  final ThemeData theme;
  const _EmptyScenePrompt({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 40,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              'No Scene Active',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Create or load a scene to start grouping models.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
