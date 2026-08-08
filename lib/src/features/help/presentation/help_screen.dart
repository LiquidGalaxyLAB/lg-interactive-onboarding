import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/features/settings/data/settings_service.dart';

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(settingsServiceProvider.select((s) => s.themeMode == ThemeMode.dark));
    Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Troubleshooting'),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        children: [
          _buildSectionTitle(context, '3D Model Imports & Conversions'),
          _FAQItem(
            isDark: isDark,
            question: 'Can I import 3D models other than .DAE?',
            answer: 'No, currently only .dae (COLLADA) and .zip files containing .dae models are supported. We strictly limit the format support to these types for maximum stability and performance on the Liquid Galaxy rig.',
          ),
          _FAQItem(
            isDark: isDark,
            question: 'I imported a .ZIP archive, but I got a "MissingDaeException" error.',
            answer: 'Your .zip archive must contain a valid 3D model inside it. If you compress your model inside multiple nested folders, the app won\'t find it. Keep the model at the root of the zip. Note: .rar files are intentionally not supported to prevent memory crashes.',
          ),
          _FAQItem(
            isDark: isDark,
            question: 'Why does the app crash when I import a massive 3D model?',
            answer: 'We have implemented highly-optimized memory scanning to prevent Out-Of-Memory (OOM) crashes on large files. However, Google Earth strictly cannot render overly complex models. Ensure your model has fewer than 65,000 vertices per mesh.',
          ),
          _FAQItem(
            isDark: isDark,
            question: 'My model appears in Google Earth, but it is microscopic or gigantic.',
            answer: '3D models often use different units (inches, millimeters). Our app automatically detects the model\'s native <unit> and aggressively normalizes it to exactly 1.0 meters. If it still looks wrong, you can manually adjust the scale slider in the Model Builder.',
          ),
          _FAQItem(
            isDark: isDark,
            question: 'How do I correctly position my 3D model on the map?',
            answer: 'In the Model Builder workspace, use the OpenStreetMap preview to drag and drop your model exactly where you want it. You can also use the sliders to precisely adjust its Heading (rotation), Tilt (pitch), and Roll before pushing it to the rig.',
          ),
          const SizedBox(height: 48),
          
          _buildSectionTitle(context, 'Rig Connection & SSH'),
          _FAQItem(
            isDark: isDark,
            question: 'Why is the connection indicator showing as "Offline"?',
            answer: 'Ensure your device is connected to the exact same Wi-Fi network as the Liquid Galaxy. Go to the Settings page and verify that your Host IP, Port, Username, and Password perfectly match your master rig\'s configuration.',
          ),
          _FAQItem(
            isDark: isDark,
            question: 'The app takes a long time to connect and then times out.',
            answer: 'Verify that the Liquid Galaxy rig is fully powered on. If you are using a mobile hotspot or a dynamic router, the IP address of the master rig might have changed. Double check the IP address on the master rig.',
          ),
          _FAQItem(
            isDark: isDark,
            question: 'I\'m connected, but the rig isn\'t responding to any commands.',
            answer: 'Sometimes the Liquid Galaxy software may freeze. Try tapping "Relaunch" in the Settings -> Rig Controls section. If that fails, use the "Reboot" button to safely power cycle the entire rig.',
          ),
          const SizedBox(height: 48),

          _buildSectionTitle(context, 'KML Playgrounds & Rig Controls'),
          _FAQItem(
            isDark: isDark,
            question: 'I sent a model to the rig, but nothing appeared.',
            answer: 'If the model was pushed successfully, it is definitely on the Liquid Galaxy rig! However, because models are often downloaded from third-party websites, they may have anomalies. Potential reasons it is not visible: the model size is extremely small, the camera angle is too far away, or there is an inbuilt transparency tag made by the creator. You can also try going to Settings -> Rig Controls and tapping "Refresh Master KML" to force a re-sync.',
          ),
          _FAQItem(
            isDark: isDark,
            question: 'How do I safely remove everything from the LG screens?',
            answer: 'You can use the "Deep Clean" card on the main dashboard, or go to Settings -> Rig Controls and tap "Clear KML" and "Clear Logo". All critical buttons have safety popups, so you won\'t accidentally shut down the rig.',
          ),
          const SizedBox(height: 48),

          _buildSectionTitle(context, 'Curriculum & AI Features'),
          _FAQItem(
            isDark: isDark,
            question: 'How do I progress through the curriculum modules?',
            answer: 'The curriculum is entirely self-paced! You can explore the modules in any order. Each module teaches you a specific skill, from basic rig connections to advanced 3D model manipulations.',
          ),
          _FAQItem(
            isDark: isDark,
            question: 'Why are my AI features not working?',
            answer: 'Our app supports various AI providers like Gemini, OpenAI, Claude, and Groq. You must obtain an API Key from your chosen provider and paste it into the Settings page to unlock AI features.',
          ),
          const SizedBox(height: 48),

          _buildSectionTitle(context, 'General Troubleshooting'),
          _FAQItem(
            isDark: isDark,
            question: 'The AI narration is not playing any audio.',
            answer: 'Go to Settings and ensure you have entered a valid API Key for your selected LLM Provider (e.g., Gemini, OpenAI, Groq). Also, check that your device\'s media volume is turned up and not muted.',
          ),
          _FAQItem(
            isDark: isDark,
            question: 'Something is completely broken and nothing is working.',
            answer: 'Try restarting the app. If the Liquid Galaxy rig itself is frozen, go to Settings -> Rig Controls and tap "Reboot" to restart all screens.',
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          Divider(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
        ],
      ),
    );
  }
}

class _FAQItem extends StatelessWidget {
  final String question;
  final String answer;
  final bool isDark;

  const _FAQItem({
    required this.question,
    required this.answer,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          title: Text(
            question,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black87,
              height: 1.4,
            ),
          ),
          iconColor: theme.colorScheme.primary,
          collapsedIconColor: isDark ? Colors.white54 : Colors.black54,
          childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              answer,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                height: 1.6,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
