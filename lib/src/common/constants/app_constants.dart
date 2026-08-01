class AppConstants {
  // ─── Network & SSH Settings ──────────────────────────────────────────
  static const String defaultSshHost = '192.168.0.10';
  static const int defaultSshPort = 22;
  static const String defaultSshUsername = 'lg';
  static const int defaultRigsCount = 3;
  static const int lgHttpPort = 81;
  static const Duration sshConnectionTimeout = Duration(seconds: 10);

  // ─── LG Paths ────────────────────────────────────────────────────────
  static const String lgModelDir = '/var/www/html/model';
  static const String lgWrapperDir = '/var/www/html/3d_model_wrapper';
  static const String lgSystemMasterKml = '/var/www/html/kml/master.kml';
  static const String lgWrapperMasterKml = '/var/www/html/3d_model_wrapper/master.kml';
  static const String lgRemoteScriptPath = '/tmp/dae_triangulate.py';

  // ─── Timeouts & Delays ───────────────────────────────────────────────
  static const Duration sshChannelDelay = Duration(milliseconds: 500);
  static const Duration kmlClearDelay = Duration(milliseconds: 300);
  static const Duration kmlRefreshDelay = Duration(seconds: 1);
  static const Duration pushStateResetDelay = Duration(seconds: 3);

  // ─── Model Builder Defaults ──────────────────────────────────────────
  static const double defaultScale = 1.0;
  static const double defaultAltitude = 10.0;
  static const double defaultCameraTilt = 60.0;
  static const int idMaxRandom = 9999;
  static const int idPaddingLength = 4;

  // ─── Logo Overlay ────────────────────────────────────────────────────
  static const String lgLogoRemotePath = '/var/www/html/kml/logo_banner.png';
  static const String lgLogoAssetPath = 'assets/logos/logo_banner.png';
  static const int logoOverlayWidth = 554;
  static const int logoOverlayHeight = 500;
  static const String lgSlaveKmlDir = '/var/www/html/kml';
  // ─── AI Mentor Settings ──────────────────────────────────────────────
  static const String openRouterEmbeddingModel = 'nvidia/nemotron-3-embed-1b:free';

}
