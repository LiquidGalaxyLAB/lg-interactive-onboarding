import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lg_interactive_onboarding/src/app_shell.dart';
import 'package:lg_interactive_onboarding/src/common/curriculum/guided_mode_controller.dart';
import 'package:lg_interactive_onboarding/src/common/curriculum/learning_module.dart';
import 'package:lg_interactive_onboarding/src/common/theme/app_theme.dart';
import 'package:lg_interactive_onboarding/src/features/architecture_explorer/presentation/architecture_explorer_screen.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/presentation/model_builder_screen.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/logo_overlay_service.dart';
import 'package:lg_interactive_onboarding/src/features/settings/data/settings_service.dart';
import 'package:lg_interactive_onboarding/src/features/settings/presentation/settings_screen.dart';

/// Root navigator key — injected into [GuidedModeController] so the overlay
/// can be inserted into the navigator overlay and survive tab switches.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences for persistent settings
  final prefs = await SharedPreferences.getInstance();
  const secureStorage = FlutterSecureStorage();
  final initialPassword = await secureStorage.read(key: 'password') ?? '';

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(secureStorage),
        initialPasswordProvider.overrideWithValue(initialPassword),
      ],
      child: LGContentStudioApp(navigatorKey: rootNavigatorKey),
    ),
  );
}

/// Root application widget.
class LGContentStudioApp extends ConsumerWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const LGContentStudioApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    // Inject navigator key into GuidedModeController so it can insert overlays.
    ref.read(guidedModeControllerProvider.notifier).navigatorKey = navigatorKey;

    // Activate the logo connection watcher for the full app lifetime.
    // This sends the logo on SSH connect and clears it on disconnect / app exit.
    ref.read(logoConnectionWatcherProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'LG Content Studio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      // The shell is the initial screen; Settings was the old home.
      home: const AppShell(),
      // Named routes for guided-mode navigation
      routes: {
        AppRoutes.settings: (_) => const SettingsScreen(),
        AppRoutes.modelBuilder: (_) => const ModelBuilderScreen(),
        AppRoutes.architectureExplorer: (_) =>
            const ArchitectureExplorerScreen(),
      },
    );
  }
}
