import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lg_interactive_onboarding/main.dart';
import 'package:lg_interactive_onboarding/src/features/settings/data/settings_service.dart';
import 'package:lg_interactive_onboarding/src/features/settings/presentation/settings_screen.dart';

void main() {
  testWidgets('Smoke test: App compiles and pumps SettingsScreen', (WidgetTester tester) async {
    // Setup mock values for SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Setup mock secure storage
    FlutterSecureStorage.setMockInitialValues({});
    const secureStorage = FlutterSecureStorage();
    final initialPassword = await secureStorage.read(key: 'password') ?? '';

    // Build our app and trigger a frame
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStorageProvider.overrideWithValue(secureStorage),
          initialPasswordProvider.overrideWithValue(initialPassword),
        ],
        child: const LGContentStudioApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify that the app launches and the SettingsScreen is shown
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Host IP'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
  });
}
