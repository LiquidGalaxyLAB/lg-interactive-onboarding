import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/data/model_project.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/providers/model_builder_providers.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/presentation/map_placement_widget.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/presentation/orientation_sliders.dart';

/// Main 3D Model Builder screen.
class ModelBuilderScreen extends ConsumerWidget {
  const ModelBuilderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(modelBuilderProvider);
    final pushState = ref.watch(pushProvider);
    final ssh = ref.watch(sshServiceProvider);
    final deployed = ref.watch(deployedModelsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('3D Model Builder'),
        actions: [
          // Connection status indicator (read-only)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (ssh.isConnected
                        ? const Color(0xFF7FB069)
                        : const Color(0xFFC0392B))
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ssh.isConnected
                          ? const Color(0xFF7FB069)
                          : const Color(0xFFC0392B),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    ssh.isConnected ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: ssh.isConnected
                          ? const Color(0xFF7FB069)
                          : const Color(0xFFC0392B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Project',
            onPressed: () => _confirmReset(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Deployed models panel (if any)
          if (deployed.isNotEmpty) ...[
            _DeployedModelsCard(theme: theme),
            const SizedBox(height: 16),
          ],
          _ImportModelCard(theme: theme),
          const SizedBox(height: 16),

          const MapPlacementWidget(),
          const SizedBox(height: 16),
          const OrientationSlidersWidget(),
          const SizedBox(height: 16),
          _PushToLGCard(
            theme: theme, pushState: pushState,
            isReady: project.isReady, isConnected: ssh.isConnected,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Project'),
        content: const Text('Clear the imported model, placement, and all adjustments?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              ref.read(modelBuilderProvider.notifier).reset();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project reset')));
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

}

// ═══════════════════════════════════════════════════════════════════
// DEPLOYED MODELS CARD — shows pushed models with per-model remove
// ═══════════════════════════════════════════════════════════════════

class _DeployedModelsCard extends ConsumerWidget {
  final ThemeData theme;
  const _DeployedModelsCard({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deployed = ref.watch(deployedModelsProvider);
    final pushState = ref.watch(pushProvider);
    final isPushing = pushState.status == PushStatus.pushing;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.cloud_done, color: Colors.greenAccent[400], size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Deployed Models (${deployed.length})',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                ),
                TextButton.icon(
                  onPressed: isPushing ? null : () => _confirmRemoveAll(context, ref),
                  icon: const Icon(Icons.delete_sweep, size: 16),
                  label: const Text('Remove All'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...deployed.map((model) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.view_in_ar, size: 18, color: Color(0xFF6C5CE7)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(model.displayName,
                            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                          Text(
                            '${model.latitude.toStringAsFixed(4)}, ${model.longitude.toStringAsFixed(4)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: theme.colorScheme.error),
                      tooltip: 'Remove from LG',
                      onPressed: isPushing ? null : () {
                        ref.read(pushProvider.notifier).removeModel(model);
                      },
                    ),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveAll(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove All Models'),
        content: const Text('Remove all deployed 3D models from the LG rig?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(pushProvider.notifier).removeAll();
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Remove All'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// IMPORT MODEL CARD — file picker + bundled assets
// ═══════════════════════════════════════════════════════════════════

class _ImportModelCard extends ConsumerWidget {
  final ThemeData theme;
  const _ImportModelCard({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(modelBuilderProvider);
    final vertexCount = ref.watch(vertexCountProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.upload_file, color: Color(0xFF6C5CE7), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Import 3D Model', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    Text('Supports .dae, .obj, .fbx, .blend, .gltf, .glb, .stl & more',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: project.hasModel
                        ? Colors.greenAccent.withValues(alpha: 0.15)
                        : theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(project.hasModel ? '✓ Loaded' : 'Step 1',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: project.hasModel ? Colors.greenAccent[400] : theme.colorScheme.primary)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (project.hasModel) ...[
              _FileInfoTile(project: project, theme: theme, vertexCount: vertexCount),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
            ],
            _ImportButton(theme: theme),
            const SizedBox(height: 12),
            // Bundled assets section
            Text('Or use a bundled model:', style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: bundledModels.map((b) =>
              ActionChip(
                avatar: const Icon(Icons.architecture, size: 16),
                label: Text(b.displayName, style: const TextStyle(fontSize: 12)),
                onPressed: () async {
                  try {
                    final result = await ref.read(modelBuilderProvider.notifier).loadBundledModel(b);
                    if (result is ImportFailure && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to load: ${result.message}'), backgroundColor: Colors.redAccent),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                      );
                    }
                  }
                },
              ),
            ).toList()),
          ],
        ),
      ),
    );
  }
}

class _FileInfoTile extends StatelessWidget {
  final ModelProject project;
  final ThemeData theme;
  final AsyncValue<int?> vertexCount;

  const _FileInfoTile({required this.project, required this.theme, required this.vertexCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Column(children: [
        Row(children: [
          Icon(_iconForExt(project.fileExtension), color: theme.colorScheme.primary, size: 32),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(project.fileName ?? 'Unknown',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(children: [
              _InfoChip(label: project.fileSizeFormatted, icon: Icons.data_usage, theme: theme),
              const SizedBox(width: 8),
              _InfoChip(label: (project.fileExtension ?? '').toUpperCase(), icon: Icons.extension, theme: theme),
              if (project.isAsset) ...[
                const SizedBox(width: 8),
                _InfoChip(label: 'Bundled', icon: Icons.inventory_2, theme: theme, color: const Color(0xFF6C5CE7)),
              ],
            ]),
          ])),
          Consumer(builder: (context, ref, _) => IconButton(
            icon: const Icon(Icons.swap_horiz, size: 20), tooltip: 'Replace model',
            onPressed: () async {
              final result = await ref.read(modelBuilderProvider.notifier).importModel();
              if (result is ImportFailure && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result.message), backgroundColor: Colors.orangeAccent));
              }
            },
          )),
        ]),
        vertexCount.when(
          data: (count) => count == null ? const SizedBox.shrink() : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Icon(Icons.grain, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text('~$count vertices', style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
            ]),
          ),
          loading: () => const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ]),
    );
  }

  IconData _iconForExt(String? ext) {
    switch (ext?.toLowerCase()) {
      case '.glb': case '.gltf': return Icons.view_in_ar;
      case '.dae': return Icons.architecture;
      case '.kmz': return Icons.folder_zip;
      case '.obj': case '.fbx': case '.blend': return Icons.category;
      case '.stl': case '.ply': case '.3ds': return Icons.grid_on;
      default: return Icons.insert_drive_file;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final String label; final IconData icon; final ThemeData theme; final Color? color;
  const _InfoChip({required this.label, required this.icon, required this.theme, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? theme.colorScheme.onSurface.withValues(alpha: 0.5);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: c), const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: c)),
    ]);
  }
}

class _ImportButton extends ConsumerWidget {
  final ThemeData theme;
  const _ImportButton({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        final result = await ref.read(modelBuilderProvider.notifier).importModel();
        if (result is ImportFailure && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message), backgroundColor: Colors.orangeAccent));
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2), width: 1.5),
          color: theme.colorScheme.primary.withValues(alpha: 0.03),
        ),
        child: Column(children: [
          Icon(Icons.cloud_upload_outlined, size: 36, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
          const SizedBox(height: 6),
          Text('Tap to import from device', style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text('.dae · .obj · .fbx · .blend · .gltf · .glb · .stl & more', style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
        ]),
      ),
    );
  }
}



// ═══════════════════════════════════════════════════════════════════
// PUSH TO LG CARD
// ═══════════════════════════════════════════════════════════════════

class _PushToLGCard extends ConsumerWidget {
  final ThemeData theme; final PushState pushState; final bool isReady; final bool isConnected;
  const _PushToLGCard({required this.theme, required this.pushState, required this.isReady, required this.isConnected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPushing = pushState.status == PushStatus.pushing;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0984E3).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.rocket_launch, color: Color(0xFF0984E3), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Push to Liquid Galaxy', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              Text(_getSubtitle(), style: theme.textTheme.bodySmall?.copyWith(color: _getSubtitleColor())),
            ])),
          ]),
          const SizedBox(height: 16),
          _CheckItem(label: '3D model imported', checked: ref.watch(modelBuilderProvider).hasModel, theme: theme),
          _CheckItem(label: 'Location placed on map', checked: ref.watch(modelBuilderProvider).hasLocation, theme: theme),
          _CheckItem(label: 'SSH connected', checked: isConnected, theme: theme),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 52,
            child: FilledButton.icon(
              onPressed: (isReady && isConnected && !isPushing) ? () => ref.read(pushProvider.notifier).push() : null,
              icon: isPushing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload),
              label: Text(isPushing ? 'Pushing...' : 'Push Model & KML'),
              style: FilledButton.styleFrom(backgroundColor: isReady && isConnected ? const Color(0xFF0984E3) : null),
            ),
          ),
          if (isConnected) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity, height: 44,
              child: OutlinedButton.icon(
                onPressed: !isPushing ? () => ref.read(pushProvider.notifier).clearMasterKml() : null,
                icon: const Icon(Icons.layers_clear),
                label: const Text('Clear Master KML'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ],
          if (pushState.message != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (pushState.status == PushStatus.success ? Colors.greenAccent : pushState.status == PushStatus.error ? Colors.redAccent : Colors.blueAccent).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(
                  pushState.status == PushStatus.success ? Icons.check_circle : pushState.status == PushStatus.error ? Icons.error_outline : Icons.hourglass_top,
                  size: 16,
                  color: pushState.status == PushStatus.success ? Colors.greenAccent[400] : pushState.status == PushStatus.error ? Colors.redAccent : Colors.blueAccent,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(pushState.message!, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500))),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  String _getSubtitle() {
    if (!isConnected) return 'Connect via Settings first';
    if (!isReady) return 'Complete all steps above';
    return 'Upload model and KML to master node';
  }

  Color _getSubtitleColor() {
    if (!isConnected) return Colors.redAccent;
    if (!isReady) return theme.colorScheme.onSurface.withValues(alpha: 0.5);
    return const Color(0xFF0984E3);
  }
}

class _CheckItem extends StatelessWidget {
  final String label; final bool checked; final ThemeData theme;
  const _CheckItem({required this.label, required this.checked, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(checked ? Icons.check_circle : Icons.radio_button_unchecked, size: 16,
          color: checked ? Colors.greenAccent[400] : theme.colorScheme.onSurface.withValues(alpha: 0.3)),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(
          color: checked ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          decoration: checked ? TextDecoration.lineThrough : null)),
      ]),
    );
  }
}
