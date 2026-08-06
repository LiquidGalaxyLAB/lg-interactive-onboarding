import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/common/constants/app_constants.dart';

import 'package:lg_interactive_onboarding/src/common/lg/lg_service.dart';
import 'package:lg_interactive_onboarding/src/features/kml_playground/data/kml_playground_service.dart';
import 'package:lg_interactive_onboarding/src/common/utils/geo_math.dart';
import 'package:lg_interactive_onboarding/src/features/kml_playground/domain/kml_generator.dart';
import 'package:lg_interactive_onboarding/src/features/kml_playground/domain/kml_template.dart';
import 'package:lg_interactive_onboarding/src/features/kml_playground/domain/kml_validator.dart';
import 'package:lg_interactive_onboarding/src/common/kml/educational_balloon_kml_model.dart';
import 'package:lg_interactive_onboarding/src/common/constants/educational_content.dart';
// ─── State ─────────────────────────────────────────────────────────────

/// Immutable state snapshot for the KML Playground.
class PlaygroundState {
  /// The currently selected template (null if nothing is selected).
  final KmlTemplate? activeTemplate;

  /// Current parameter values keyed by [KmlParameter.id].
  final Map<String, dynamic> activeParameters;

  /// The generated KML string (recalculated on every parameter change).
  final String? generatedKml;

  /// Whether the KML was successfully validated as well-formed XML.
  final bool isKmlValid;

  /// Optional validation error message.
  final String? validationError;

  /// Whether a push-to-LG operation is currently in flight.
  final bool isPushing;

  /// Whether a clear-from-LG operation is currently in flight.
  final bool isClearing;

  /// Whether a tour is currently playing on the rig.
  final bool isTourPlaying;

  /// Whether a native orbit tour is currently playing.
  final bool isOrbiting;

  /// Whether the current KML configuration has been successfully pushed.
  final bool isPushed;

  PlaygroundState({
    this.activeTemplate,
    this.activeParameters = const {},
    this.generatedKml,
    this.isKmlValid = true,
    this.validationError,
    this.isPushing = false,
    this.isClearing = false,
    this.isTourPlaying = false,
    this.isOrbiting = false,
    this.isPushed = false,
  });

  PlaygroundState copyWith({
    KmlTemplate? activeTemplate,
    Map<String, dynamic>? activeParameters,
    String? generatedKml,
    bool? isKmlValid,
    String? validationError,
    bool? isPushing,
    bool? isClearing,
    bool? isTourPlaying,
    bool? isOrbiting,
    bool? isPushed,
  }) {
    return PlaygroundState(
      activeTemplate: activeTemplate ?? this.activeTemplate,
      activeParameters: activeParameters ?? this.activeParameters,
      generatedKml: generatedKml ?? this.generatedKml,
      isKmlValid: isKmlValid ?? this.isKmlValid,
      validationError: validationError,
      isPushing: isPushing ?? this.isPushing,
      isClearing: isClearing ?? this.isClearing,
      isTourPlaying: isTourPlaying ?? this.isTourPlaying,
      isOrbiting: isOrbiting ?? this.isOrbiting,
      isPushed: isPushed ?? this.isPushed,
    );
  }
}

// ─── Controller ────────────────────────────────────────────────────────

/// Manages all playground interactions: template selection, parameter
/// editing, KML generation, validation, and pushing to the LG rig.
class PlaygroundController extends Notifier<PlaygroundState> {
  static const _generator = KmlGenerator();
  static const _validator = KmlValidator();
  
  Timer? _orbitTimer;
  Timer? _flyToTimer;

  @override
  PlaygroundState build() {
    ref.onDispose(() {
      _orbitTimer?.cancel();
      _flyToTimer?.cancel();
    });
    return PlaygroundState();
  }

  // ─── Template Selection ────────────────────────────────────────────

  /// Sets the active template and initialises parameters to their defaults.
  void setTemplate(KmlTemplate template) {
    final Map<String, dynamic> defaultParams = {};
    for (final param in template.parameters) {
      defaultParams[param.id] = param.defaultValue;
    }

    state = state.copyWith(
      activeTemplate: template,
      activeParameters: defaultParams,
      isPushed: false,
    );
    _regenerateKml();
  }

  // ─── Parameter Editing ─────────────────────────────────────────────

  /// Updates a single parameter and regenerates the KML.
  void updateParameter(String id, dynamic value) {
    if (state.activeTemplate == null) return;

    final newParams = Map<String, dynamic>.from(state.activeParameters);
    newParams[id] = value;

    state = state.copyWith(activeParameters: newParams, isPushed: false);
    _regenerateKml();
  }

  /// Updates latitude / longitude from a map tap event.
  void updateCoordinates(double lat, double lng) {
    if (state.activeTemplate == null) return;

    final newParams = Map<String, dynamic>.from(state.activeParameters);

    if (newParams.containsKey('latitude')) newParams['latitude'] = lat;
    if (newParams.containsKey('longitude')) newParams['longitude'] = lng;

    state = state.copyWith(activeParameters: newParams, isPushed: false);
    _regenerateKml();
  }

  /// Appends a vertex {lat, lng} to the 'vertices' parameter list.
  void addVertex(double lat, double lng) {
    if (state.activeTemplate == null) return;

    final newParams = Map<String, dynamic>.from(state.activeParameters);
    final existing = List<Map<String, double>>.from(
      (newParams['vertices'] as List? ?? []).map((v) => Map<String, double>.from(v as Map)),
    );
    existing.add({'lat': lat, 'lng': lng});
    newParams['vertices'] = existing;

    state = state.copyWith(activeParameters: newParams, isPushed: false);
    _regenerateKml();
  }

  /// Removes the vertex at [index] from the 'vertices' parameter list.
  void removeVertex(int index) {
    if (state.activeTemplate == null) return;

    final newParams = Map<String, dynamic>.from(state.activeParameters);
    final existing = List<Map<String, double>>.from(
      (newParams['vertices'] as List? ?? []).map((v) => Map<String, double>.from(v as Map)),
    );
    if (index >= 0 && index < existing.length) {
      existing.removeAt(index);
    }
    newParams['vertices'] = existing;

    state = state.copyWith(activeParameters: newParams, isPushed: false);
    _regenerateKml();
  }

  /// Clears all vertices from the polygon.
  void clearVertices() {
    if (state.activeTemplate == null) return;

    final newParams = Map<String, dynamic>.from(state.activeParameters);
    newParams['vertices'] = <Map<String, double>>[];

    state = state.copyWith(activeParameters: newParams, isPushed: false);
    _regenerateKml();
  }

  // ─── Reset ─────────────────────────────────────────────────────────

  /// Resets parameters back to their defaults without changing the
  /// selected template.
  void resetParameters() {
    final template = state.activeTemplate;
    if (template == null) return;

    final Map<String, dynamic> defaultParams = {};
    for (final param in template.parameters) {
      defaultParams[param.id] = param.defaultValue;
    }

    state = state.copyWith(activeParameters: defaultParams, isPushed: false);
    _regenerateKml();
  }

  /// Clears everything — deselects template and wipes generated KML.
  void clear() {
    state = PlaygroundState();
  }

  // ─── Push to Liquid Galaxy ─────────────────────────────────────────

  /// Generates the KML, validates it, and sends it to the LG rig.
  ///
  /// Returns `true` on success.
  Future<bool> pushToLG() async {
    final kml = state.generatedKml;
    if (kml == null || !state.isKmlValid) {
      debugPrint('Playground: Cannot push — KML is null or invalid.');
      return false;
    }

    state = state.copyWith(isPushing: true);

    try {
      final playgroundService = ref.read(kmlPlaygroundServiceProvider);
      final lgService = ref.read(lgServiceProvider);

      // Stop any running background tours or orbits before pushing new KML
      await stopOrbit();
      await lgService.stopTour();
      await Future.delayed(const Duration(milliseconds: 100)); // Brief pause for GE to stabilize

      // 1. Extract lat/long depending on the template type to point the camera there
      final params = state.activeParameters;
      double lat = GeoMath.extractDouble(params, 'latitude') ??
          GeoMath.extractDouble(params, 'startLatitude') ??
          0.0;
      double lng = GeoMath.extractDouble(params, 'longitude') ??
          GeoMath.extractDouble(params, 'startLongitude') ??
          0.0;

      // If lat/lng are 0, check if this is a polygon with vertices and calculate centroid
      if (lat == 0.0 && lng == 0.0 && params['vertices'] != null) {
        final centroid = GeoMath.calculateCentroid(params['vertices']);
        if (centroid.$1 != 0.0 || centroid.$2 != 0.0) {
          lat = centroid.$1;
          lng = centroid.$2;
        }
      }

      // 2. Send Educational Balloon KML if applicable.
      // Doing this BEFORE sending the main KML ensures the balloon file is already on the 
      // server when the forced refresh is triggered.
      final templateName = state.activeTemplate?.name;
      if (templateName != null) {
        String key = templateName;
        if (templateName.contains('Placemark')) {
          key = 'Placemark';
        } else if (templateName.contains('Polygon')) {
          key = 'Polygon';
        } else if (templateName.contains('Path') || templateName.contains('LineString')) {
          key = 'LineString';
        }

        final content = EducationalConstants.kmlContent[key];
        if (content != null) {
          final balloonKml = EducationalBalloonKmlModel.generateBalloonKml(
            id: key.toLowerCase(),
            title: content.title,
            description: content.description,
            iconUrl: content.iconUrl,
            latitude: lat,
            longitude: lng,
          );
          await lgService.sendBalloonKml(balloonKml);
        }
      }

      // 3. Upload the KML to the master screen (triggers force refresh).
      final uploaded = await playgroundService.sendKml(kml);
      if (!uploaded) {
        debugPrint('Playground: KML upload failed.');
        state = state.copyWith(isPushing: false);
        return false;
      }

      // 4. Fly the camera to the relevant location without starting an automatic stream orbit.
      await lgService.flyTo(
        latitude: lat,
        longitude: lng,
        altitude: GeoMath.extractDouble(params, 'altitude') ?? 0.0,
        heading: GeoMath.extractDouble(params, 'heading') ?? 0.0,
        tilt: GeoMath.extractDouble(params, 'tilt') ?? 45.0,
        range: GeoMath.extractDouble(params, 'range') ?? 1000.0,
      );

      debugPrint('Playground: KML pushed and camera moved.');
      state = state.copyWith(isPushing: false);

      // We add a delay to allow Google Earth to finish the physical flyTo animation
      // before enabling the Orbit/Tour buttons. Otherwise, starting an orbit instantly
      // will abruptly cancel the camera flight.
      _flyToTimer?.cancel();
      _flyToTimer = Timer(AppConstants.lgFlyToDuration, () {
        state = state.copyWith(isPushed: true);
      });

      return true;
    } catch (e) {
      debugPrint('Playground: pushToLG error: $e');
      state = state.copyWith(isPushing: false);
      return false;
    }
  }

  /// Clears the KML from the Liquid Galaxy screens.
  Future<bool> clearFromLG() async {
    if (state.isClearing) return false;
    
    try {
      final playgroundService = ref.read(kmlPlaygroundServiceProvider);
      final lgService = ref.read(lgServiceProvider);
      final wasPlaying = state.isOrbiting || state.isTourPlaying;

      state = state.copyWith(isClearing: true);

      // Stop any running background tours or orbits before clearing
      await stopOrbit();
      await lgService.stopTour();
      
      if (wasPlaying) {
        // Give Google Earth ample time to fully exit the tour mode and 
        // stabilize its UI. Otherwise, it might ignore the subsequent 
        // network link refresh signal.
        await Future.delayed(AppConstants.lgTourExitDelay);
      } else {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      await lgService.cleanBalloonKML();
      final cleared = await playgroundService.clearKml();
      
      _flyToTimer?.cancel();
      state = state.copyWith(isClearing: false, isPushed: !cleared && state.isPushed);
      
      return cleared;
    } catch (e) {
      debugPrint('Playground: clearFromLG error: $e');
      state = state.copyWith(isClearing: false);
      return false;
    }
  }


  /// Tells the Liquid Galaxy to start playing the tour named in parameters.
  Future<bool> playTour() async {
    final tourName = state.activeParameters['name'] as String? ?? 'My Tour';
    try {
      final lgService = ref.read(lgServiceProvider);
      final ok = await lgService.playTour(tourName);
      if (ok) state = state.copyWith(isTourPlaying: true);
      return ok;
    } catch (e) {
      debugPrint('Playground: playTour error: $e');
      return false;
    }
  }

  /// Stops the currently playing tour and any active orbit streams on Liquid Galaxy.
  Future<bool> stopTour() async {
    try {
      final lgService = ref.read(lgServiceProvider);
      await lgService.orbitStop();
      final ok = await lgService.stopTour();
      
      state = state.copyWith(isTourPlaying: false);
      return ok;
    } catch (e) {
      debugPrint('Playground: stopTour error: $e');
      return false;
    }
  }

  /// Restarts the tour: stops then immediately plays again.
  Future<void> restartTour() async {
    await stopTour();
    await Future.delayed(const Duration(milliseconds: 1200));
    await playTour();
  }

  // ─── Native Orbit Playback ──────────────────────────────────────────

  /// Starts the native gx:Tour orbit for Playground shapes.
  Future<void> startOrbit() async {
    final lgService = ref.read(lgServiceProvider);
    state = state.copyWith(isOrbiting: true);

    // Cancel any existing timer
    _orbitTimer?.cancel();
    
    // Tell GE to play the embedded tour
    await lgService.playTour('Orbit_Playground');

    // The _generateOrbitTour creates exactly 20 revolutions, taking 14.4 minutes (864 seconds).
    // When it finishes, GE stops moving, but our UI would be permanently stuck on "Stop Orbit"
    // because GE cannot send a "Tour Finished" callback over SSH.
    // So, we set a precise timer to auto-reset the UI back to "Start Orbit" exactly
    // when the native tour naturally completes!
    _orbitTimer = Timer(const Duration(seconds: 864), () {
      state = state.copyWith(isOrbiting: false);
    });
  }

  /// Stops the native orbit tour and resets the UI state immediately.
  Future<void> stopOrbit() async {
    final lgService = ref.read(lgServiceProvider);
    
    // Stop any active tours/orbits in Google Earth
    await lgService.orbitStop();
    
    // Immediately cancel the auto-reset timer and revert UI state
    _orbitTimer?.cancel();
    state = state.copyWith(isOrbiting: false);
  }

  // ─── Internal Helpers ──────────────────────────────────────────────

  /// Regenerates the KML string from the current template + parameters,
  /// validates it, and updates the state.
  void _regenerateKml() {
    _flyToTimer?.cancel();
    final template = state.activeTemplate;
    if (template == null) return;

    final kml = _generator.generate(template.type, state.activeParameters);

    if (kml != null) {
      final result = _validator.validate(kml);
      state = state.copyWith(
        generatedKml: kml,
        isKmlValid: result.isValid,
        validationError: result.errorMessage,
      );
    } else {
      state = state.copyWith(
        generatedKml: null,
        isKmlValid: false,
        validationError: 'Unsupported template type.',
      );
    }
  }
}

// ─── Provider ──────────────────────────────────────────────────────────

final playgroundControllerProvider =
    NotifierProvider<PlaygroundController, PlaygroundState>(() {
  return PlaygroundController();
});
