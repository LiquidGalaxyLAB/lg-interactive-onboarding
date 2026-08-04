import 'package:flutter/material.dart';

/// The About / Help screen detailing app features and developer credits.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Hero(
                  tag: 'app_logo',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/logos/apk_logo.png',
                      width: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'LG Interactive Onboarding',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  'Built by Darpan Baviskar (darpanbaviskar@gmail.com) for Google Summer of Code (GSoC) 2026 with Liquid Galaxy.',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: colorScheme.onSurface.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Image.asset(
                        'assets/logos/logo_banner.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Project Contributions:\n\n'
                  '• OpenRouter AI Mentor with Local Vector RAG and Full Speech Accessibility.\n'
                  '• Interactive KML Playground & System KML Slot Architecture.\n'
                  '• Rebuilt 3D Model Rendering Pipeline (fixing distortion & shaders on LG rig).\n'
                  '• Live-Streamed Orbital Tours & Educational KML Balloon integrations.\n'
                  '• Curriculum Engine with auto-verification & Minimal Surface UI integration.\n'
                  '• Ultimate Deep Clean system for flawless Liquid Galaxy state management.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 32),
                Text(
                  'Credits:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Special thanks to Kabir Khanuja(GSoC 2026 fellow contributor for Liquid Galaxy) for suggesting the LLM service provider settings.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: colorScheme.onSurface.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
