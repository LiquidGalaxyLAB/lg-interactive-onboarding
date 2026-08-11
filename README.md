<div align="center">

# LG Interactive Onboarding: Guided Tutorial & Learning System

**A Flutter-based onboarding, learning, and 3D content platform for the Liquid Galaxy ecosystem**

<p>
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Liquid_Galaxy-4285F4?style=for-the-badge&logo=google&logoColor=white" alt="Liquid Galaxy" />
  <img src="https://img.shields.io/badge/KML-000000?style=for-the-badge&logo=googleearth&logoColor=white" alt="KML" />
  <img src="https://img.shields.io/badge/COLLADA-333333?style=for-the-badge" alt="Collada" />
  <img src="https://img.shields.io/badge/Google_Earth-4285F4?style=for-the-badge&logo=googleearth&logoColor=white" alt="Google Earth" />
</p>

<p>
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License" />
  <img src="https://img.shields.io/badge/PRs-welcome-brightgreen?style=flat-square" alt="PRs Welcome" />
  <img src="https://img.shields.io/badge/status-completed-green?style=flat-square" alt="Status" />
</p>

<img src="assets/logos/apk_logo.png" alt="LG Interactive Onboarding Logo" width="180"/>

</div>

---

## Table of Contents

- [Overview](#overview)
- [Core Features](#core-features)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Building for Platforms](#building-for-platforms)
- [Project Structure](#project-structure)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgments](#acknowledgments)

---

## Overview

**LG Interactive Onboarding** is a comprehensive Flutter application that lowers the barrier to entry for using [Liquid Galaxy](https://www.liquidgalaxy.eu/) rigs. It combines a gamified learning curriculum, a no-code 3D model builder, and a full rig control dashboard into a single, cohesive interface — so users can learn, create, and control without needing deep technical knowledge of KML or SSH.

The project aims to:

- **Educate** — a gamified, curriculum-based path to learning Liquid Galaxy's features and capabilities.
- **Empower creation** — an intuitive 3D model builder for importing, manipulating, and projecting custom models onto a rig without hand-writing KML.
- **Simplify control** — a centralized dashboard for managing rig state and executing complex commands safely.
- **Assist in real time** — an AI mentor with local vector RAG and full speech accessibility.

---

## Core Features

###  Curriculum Engine & Learning
- Guided and self-paced interactive learning modules covering the Liquid Galaxy ecosystem.
- Real-time auto-verification that polls rig/provider state to confirm task completion.
- Voice narration via `flutter_tts`, with user-configurable preferences.
- Reward animations and gamification on module completion.
- KML educational balloons that surface contextual information directly on the LG screens.

###  3D Model Builder
- Import support for native COLLADA (`.dae`) and compressed (`.kmz`) files.
- Drag-and-drop geospatial placement on an interactive `flutter_map` (OpenStreetMap) view.
- Fine-grained orientation control — heading, tilt, and roll sliders.
- Automatic triangulation, KMZ/KML packaging, and one-click deployment to the rig.
- Model grouping and validation, with an optimized rendering pipeline for large models.

###  AI Mentor & Help System
- Multi-provider LLM integration via OpenRouter for contextual, dynamic assistance.
- Local vector RAG for accurate, system-specific answers.
- Built-in FAQ and troubleshooting guide integrated into the dashboard.

###  Advanced Liquid Galaxy Features
- Interactive KML playground with a system KML slot architecture for live experimentation.
- Live-streamed orbital tours of geospatial locations on the Google Earth instance.
- Architecture Explorer — UML and SVG-based diagrams documenting data flow, state, and the physical structure of an LG cluster.

###  Dashboard & SSH Control
- Secure SSH connection to the LG master node via `dartssh2` and `flutter_secure_storage`.
- Power management commands (shutdown, reboot, relaunch, clear screens) with confirmation dialogs for all critical operations.
- Dynamic logo banner overlay on the leftmost LG screen, with manual clear support.

###  UI/UX Architecture
- `AppShell` navigation built on an `IndexedStack` for persistent, state-preserving tabs and overlays.
- State management fully migrated to Riverpod (`ListenableBuilder`s and `NotifierProvider`s).
- A warm, modern dark theme with a minimal-surface design and Liquid Galaxy brand color integration.

---

## Tech Stack

| Category | Technologies |
|---|---|
| Framework | Flutter (SDK `^3.10.4`) |
| State Management | `flutter_riverpod` |
| Networking / SSH | `dartssh2`, `http` |
| Mapping | `flutter_map`, `latlong2` |
| Data Processing | `xml`, `archive` |
| Storage | `shared_preferences`, `flutter_secure_storage` |
| Media & AI | `flutter_svg`, `flutter_tts`, `speech_to_text`, `tflite_flutter` |
| 3D Processing | Custom Assimp integration, DAE triangulation |

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed and available on your `PATH`.
- Android Studio or Xcode for building to their respective platforms.
- A running Liquid Galaxy rig (or a virtual machine configured as one) for testing SSH commands and KML rendering.

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/LiquidGalaxyLAB/lg-interactive-onboarding.git
   cd lg-interactive-onboarding
   ```

2. **Verify your Flutter installation**
   ```bash
   flutter --version
   ```

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the application**
   ```bash
   # List available devices
   flutter devices

   # Run the app
   flutter run
   ```

### Building for Platforms

**Android (debug APK):**
```bash
flutter build apk --debug
```

**Web:**
```bash
flutter build web
```

---

## Project Structure

> Review the `ARCHITECTURE_EXPLORER` components within the app for a visual, up-to-date breakdown of module boundaries and state flow before diving into the codebase.

```
lib/
├── curriculum/        # Guided learning modules, TTS, gamification
├── model_builder/      # 3D import, placement, KML/KMZ generation
├── ai_mentor/           # OpenRouter integration, local vector RAG
├── dashboard/            # SSH control, power management, logo overlay
├── architecture_explorer/ # UML/SVG diagram viewer
└── shared/                # AppShell, theming, common widgets/providers
```

---

## Contributing

Contributions are welcome and appreciated! Before opening a pull request, please review the `ARCHITECTURE_EXPLORER` components within the app to understand the current state flow and UI structure.

1. Fork the repository.
2. Create your feature branch:
   ```bash
   git checkout -b feature/AmazingFeature
   ```
3. Commit your changes:
   ```bash
   git commit -m 'Add some AmazingFeature'
   ```
4. Push to the branch:
   ```bash
   git push origin feature/AmazingFeature
   ```
5. Open a Pull Request.

Please keep PRs focused and include a clear description of the change and its motivation.

---

## License

Distributed under the MIT License. See `LICENSE` for more information.

---

## Acknowledgments

*Developed for the [Liquid Galaxy Project](https://www.liquidgalaxy.eu/).*

A special thank you to the following individuals for their invaluable guidance, support, and mentorship throughout the development of this project:

- **Andreu Ibañez** — Organization Administrator, Liquid Galaxy Lab & Project Mentor
- **[Óscar Carrasco](https://github.com/oxcabe)** — Project Mentor
- **[Deniz Yuksel](https://github.com/denizyuksel)** — Project Mentor