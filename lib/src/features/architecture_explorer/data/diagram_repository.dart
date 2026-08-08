import 'package:flutter/material.dart';

import 'diagram_model.dart';

/// Hard-coded registry of all Architecture Explorer diagrams.
///
/// ### Extensibility
/// To add a new diagram from a future feature, append a [DiagramDefinition]
/// to the [all] list. The [ArchitectureExplorerScreen] and [DiagramViewer]
/// automatically pick it up.
class DiagramRepository {
  const DiagramRepository._();

  static List<DiagramDefinition> get all => [
        _masterSlave,
        _viewSync,
        _sshFlow,
        _kmlPropagation,
      ];

  static DiagramDefinition? byId(String id) {
    try {
      return all.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Diagram 1: Master-Slave Topology ─────────────────────────────────────
  static const _masterSlave = DiagramDefinition(
    id: 'master_slave',
    title: 'Master-Slave Topology',
    subtitle: 'How nodes are physically connected in the LG rig',
    icon: Icons.schema_outlined,
    accentColor: Color(0xFF4A6572), // Slate Blue
    hotspots: [
      HotspotDefinition(
        id: 'master_node',
        label: 'Master',
        tapArea: Rect.fromLTWH(0.38, 0.08, 0.24, 0.18),
        icon: Icons.computer_rounded,
        detailTitle: 'Master Node',
        detailBody:
            'The master node is the central controller of the LG rig. '
            'It receives commands from the tablet app via SSH, executes them, '
            'and instructs slave nodes via the internal network.\n\n'
            'KML files are written to the master\'s web server '
            '(/var/www/html/kml/) and served to slaves via NetworkLink.',
        relatedModuleId: 'connect_lg',
      ),
      HotspotDefinition(
        id: 'slave_nodes',
        label: 'Slaves',
        tapArea: Rect.fromLTWH(0.05, 0.60, 0.90, 0.20),
        icon: Icons.monitor_rounded,
        detailTitle: 'Slave Nodes',
        detailBody:
            'Slave nodes run Google Earth and poll the master\'s web server '
            'for KML updates via NetworkLink. Each slave renders a different '
            'section of the panoramic view based on its screen position offset.\n\n'
            'Slaves do NOT receive SSH commands directly — they only fetch KML.',
      ),
      HotspotDefinition(
        id: 'internal_switch',
        label: 'Switch',
        tapArea: Rect.fromLTWH(0.38, 0.40, 0.24, 0.14),
        icon: Icons.device_hub_rounded,
        detailTitle: 'Internal Network Switch',
        detailBody:
            'The gigabit switch connects all LG nodes on a private LAN. '
            'This isolated network ensures low-latency, high-bandwidth '
            'communication between master and slaves for ViewSync and '
            'KML delivery.',
      ),
    ],
  );

  // ── Diagram 2: ViewSync Protocol ─────────────────────────────────────────
  static const _viewSync = DiagramDefinition(
    id: 'view_sync',
    title: 'ViewSync Protocol',
    subtitle: 'How camera positions are synchronized across all screens',
    icon: Icons.sync_alt_rounded,
    accentColor: Color(0xFF34495E), // Dark Slate
    hotspots: [
      HotspotDefinition(
        id: 'viewsync_packet',
        label: 'UDP Packet',
        tapArea: Rect.fromLTWH(0.30, 0.35, 0.40, 0.16),
        icon: Icons.podcasts_rounded,
        detailTitle: 'ViewSync UDP Packet',
        detailBody:
            'The master Google Earth instance continuously broadcasts its '
            'current camera state as a UDP packet on port 21567.\n\n'
            'The packet contains: latitude, longitude, altitude, heading, '
            'tilt, and roll. Slaves receive this and offset their cameras '
            'to render their slice of the panorama.',
        relatedModuleId: 'ssh_architecture',
      ),
      HotspotDefinition(
        id: 'master_camera',
        label: 'Master Camera',
        tapArea: Rect.fromLTWH(0.35, 0.06, 0.30, 0.18),
        icon: Icons.videocam_rounded,
        detailTitle: 'Master Camera',
        detailBody:
            'The master\'s Google Earth instance is the "source of truth" '
            'for the view. Any KML `<LookAt>` or `<Camera>` element '
            'pushed to master drives the entire rig\'s perspective.',
      ),
      HotspotDefinition(
        id: 'slave_cameras',
        label: 'Slave Cameras',
        tapArea: Rect.fromLTWH(0.05, 0.70, 0.90, 0.18),
        icon: Icons.view_array_rounded,
        detailTitle: 'Slave Cameras',
        detailBody:
            'Each slave applies a fixed horizontal offset (typically ±35°) '
            'to the received ViewSync heading. This creates the seamless '
            'multi-screen panoramic effect without requiring separate '
            'camera control for each screen.',
      ),
    ],
  );

  // ── Diagram 3: SSH Communication Flow ────────────────────────────────────
  static const _sshFlow = DiagramDefinition(
    id: 'ssh_flow',
    title: 'SSH Communication Flow',
    subtitle: 'How the tablet app talks to the LG master node',
    icon: Icons.security_rounded,
    accentColor: Color(0xFF5D6D7E), // Steel Gray
    hotspots: [
      HotspotDefinition(
        id: 'mobile_app',
        label: 'Tablet App',
        tapArea: Rect.fromLTWH(0.05, 0.20, 0.28, 0.35),
        icon: Icons.tablet_android_rounded,
        detailTitle: 'LG Interactive Onboarding (Tablet)',
        detailBody:
            'The tablet app uses the `dartssh2` Dart package to establish '
            'an SSH session with the master node over port 22.\n\n'
            'GOLDEN RULE: Always use `SSHService.execute()` to prevent channel '
            'exhaustion. SFTP is used only for file uploads.',
        relatedModuleId: 'connect_lg',
      ),
      HotspotDefinition(
        id: 'ssh_channel',
        label: 'SSH Session',
        tapArea: Rect.fromLTWH(0.33, 0.30, 0.34, 0.20),
        icon: Icons.lock_rounded,
        detailTitle: 'SSH Session',
        detailBody:
            'An SSH session is kept alive for the duration of the app session. '
            'Channels are opened per-command and closed immediately after '
            'to avoid the "SSH channel exhaustion" issue.\n\n'
            'Password authentication is used; credentials are stored in '
            'Flutter Secure Storage (AES-encrypted on device).',
      ),
      HotspotDefinition(
        id: 'master_execute',
        label: 'Master Executes',
        tapArea: Rect.fromLTWH(0.67, 0.20, 0.28, 0.35),
        icon: Icons.terminal_rounded,
        detailTitle: 'Master Node Execution',
        detailBody:
            'Commands received via SSH are executed in a bash shell on the '
            'master. Common commands include:\n\n'
            '• `python3 dae_triangulate.py` — mesh triangulation\n'
            '• `cat > master.kml` — KML injection\n'
            '• `pip3 install` — Python dependency management',
      ),
    ],
  );

  // ── Diagram 4: KML Propagation ────────────────────────────────────────────
  static const _kmlPropagation = DiagramDefinition(
    id: 'kml_propagation',
    title: 'KML Propagation',
    subtitle: 'How KML content reaches every Google Earth instance',
    icon: Icons.account_tree_outlined,
    accentColor: Color(0xFF2C3E50), // Midnight Blue
    hotspots: [
      HotspotDefinition(
        id: 'web_server',
        label: 'Web Server',
        tapArea: Rect.fromLTWH(0.34, 0.05, 0.32, 0.18),
        icon: Icons.dns_rounded,
        detailTitle: 'Master Web Server (Apache)',
        detailBody:
            'The master node runs an Apache web server on port 81. '
            'Model files and KML wrappers are stored under:\n\n'
            '• `/var/www/html/model/` — .dae model files\n'
            '• `/var/www/html/3d_model_wrapper/` — per-model KML\n'
            '• `/var/www/html/kml/master.kml` — top-level entry point',
        relatedModuleId: 'understand_kml',
      ),
      HotspotDefinition(
        id: 'master_kml',
        label: 'master.kml',
        tapArea: Rect.fromLTWH(0.34, 0.34, 0.32, 0.16),
        icon: Icons.description_rounded,
        detailTitle: 'master.kml — The Entry Point',
        detailBody:
            '`master.kml` is the single KML file that all slave Google Earth '
            'instances load via NetworkLink.\n\n'
            'It contains `<NetworkLink>` elements pointing to individual '
            'model KML wrappers. When the tablet pushes a model, this file '
            'is updated to add the new link, triggering a refresh on all slaves.',
      ),
      HotspotDefinition(
        id: 'network_link',
        label: 'NetworkLink',
        tapArea: Rect.fromLTWH(0.30, 0.56, 0.40, 0.14),
        icon: Icons.link_rounded,
        detailTitle: 'KML NetworkLink',
        detailBody:
            '`<NetworkLink>` is the KML mechanism for linking external KML '
            'documents. Slaves poll the master\'s web server at a set interval '
            '(or on change) and reload linked KML files automatically.\n\n'
            'This is how a model pushed from the tablet appears on all screens '
            'within seconds — no SSH command is sent to slaves.',
      ),
      HotspotDefinition(
        id: 'slave_earth',
        label: 'Slave Google Earth',
        tapArea: Rect.fromLTWH(0.05, 0.76, 0.90, 0.18),
        icon: Icons.public_rounded,
        detailTitle: 'Slave Google Earth Instances',
        detailBody:
            'Each slave runs a Google Earth instance that polls master.kml '
            'via NetworkLink. When a new model is pushed:\n\n'
            '1. master.kml is updated on the master\'s web server\n'
            '2. Each slave detects the change on its next poll\n'
            '3. Slaves independently load the model KML and render the model\n\n'
            'This pull-based approach means slaves are always in sync without '
            'needing direct SSH access.',
      ),
    ],
  );
}
