import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lg_interactive_onboarding/src/common/lg/lg_service.dart';
import 'package:lg_interactive_onboarding/src/features/kml_playground/data/kml_playground_service.dart';
import 'package:lg_interactive_onboarding/src/features/kml_playground/domain/kml_generator.dart';
import 'package:lg_interactive_onboarding/src/features/kml_playground/domain/kml_template.dart';
import 'package:lg_interactive_onboarding/src/features/kml_playground/domain/kml_validator.dart';

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

  /// Whether a tour is currently playing on the rig.
  final bool isTourPlaying;

  PlaygroundState({
    this.activeTemplate,
    this.activeParameters = const {},
    this.generatedKml,
    this.isKmlValid = true,
    this.validationError,
    this.isPushing = false,
    this.isTourPlaying = false,
  });

  PlaygroundState copyWith({
    KmlTemplate? activeTemplate,
    Map<String, dynamic>? activeParameters,
    String? generatedKml,
    bool? isKmlValid,
    String? validationError,
    bool? isPushing,
    bool? isTourPlaying,
  }) {
    return PlaygroundState(
      activeTemplate: activeTemplate ?? this.activeTemplate,
      activeParameters: activeParameters ?? this.activeParameters,
      generatedKml: generatedKml ?? this.generatedKml,
      isKmlValid: isKmlValid ?? this.isKmlValid,
      validationError: validationError,
      isPushing: isPushing ?? this.isPushing,
      isTourPlaying: isTourPlaying ?? this.isTourPlaying,
    );
  }
}

// ─── Controller ────────────────────────────────────────────────────────

/// Manages all playground interactions: template selection, parameter
/// editing, KML generation, validation, and pushing to the LG rig.
class PlaygroundController extends Notifier<PlaygroundState> {
  static const _generator = KmlGenerator();
  static const _validator = KmlValidator();

  @override
  PlaygroundState build() {
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
    );
    _regenerateKml();
  }

  // ─── Parameter Editing ─────────────────────────────────────────────

  /// Updates a single parameter and regenerates the KML.
  void updateParameter(String id, dynamic value) {
    if (state.activeTemplate == null) return;

    final newParams = Map<String, dynamic>.from(state.activeParameters);
    newParams[id] = value;

    state = state.copyWith(activeParameters: newParams);
    _regenerateKml();
  }

  /// Updates latitude / longitude from a map tap event.
  void updateCoordinates(double lat, double lng) {
    if (state.activeTemplate == null) return;

    final newParams = Map<String, dynamic>.from(state.activeParameters);

    if (newParams.containsKey('latitude')) newParams['latitude'] = lat;
    if (newParams.containsKey('longitude')) newParams['longitude'] = lng;

    state = state.copyWith(activeParameters: newParams);
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

    state = state.copyWith(activeParameters: newParams);
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

    state = state.copyWith(activeParameters: newParams);
    _regenerateKml();
  }

  /// Clears all vertices from the polygon.
  void clearVertices() {
    if (state.activeTemplate == null) return;

    final newParams = Map<String, dynamic>.from(state.activeParameters);
    newParams['vertices'] = <Map<String, double>>[];

    state = state.copyWith(activeParameters: newParams);
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

    state = state.copyWith(activeParameters: defaultParams);
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

      // 1. Upload the KML to the master screen.
      final uploaded = await playgroundService.sendKml(kml);
      if (!uploaded) {
        debugPrint('Playground: KML upload failed.');
        state = state.copyWith(isPushing: false);
        return false;
      }

      // 2. Fly the camera to the relevant location.
      final params = state.activeParameters;
      double lat = _extractDouble(params, 'latitude') ??
          _extractDouble(params, 'startLatitude') ??
          0.0;
      double lng = _extractDouble(params, 'longitude') ??
          _extractDouble(params, 'startLongitude') ??
          0.0;

      // If lat/lng are 0, check if this is a polygon with vertices and calculate centroid
      if (lat == 0.0 && lng == 0.0 && params['vertices'] != null) {
        final vertices = params['vertices'];
        if (vertices is List && vertices.isNotEmpty) {
          double sumLat = 0;
          double sumLng = 0;
          int count = 0;
          for (final v in vertices) {
            if (v is Map) {
              sumLat += (v['lat'] as num?)?.toDouble() ?? 0.0;
              sumLng += (v['lng'] as num?)?.toDouble() ?? 0.0;
              count++;
            }
          }
          if (count > 0) {
            lat = sumLat / count;
            lng = sumLng / count;
          }
        }
      }

      final lgService = ref.read(lgServiceProvider);
      await lgService.flyTo(
        latitude: lat,
        longitude: lng,
        altitude: _extractDouble(params, 'altitude') ?? 0.0,
        heading: _extractDouble(params, 'heading') ?? 0.0,
        tilt: _extractDouble(params, 'tilt') ?? 45.0,
        range: _extractDouble(params, 'range') ?? 1000.0,
      );

      debugPrint('Playground: KML pushed and camera moved.');
      state = state.copyWith(isPushing: false);
      return true;
    } catch (e) {
      debugPrint('Playground: pushToLG error: $e');
      state = state.copyWith(isPushing: false);
      return false;
    }
  }

  /// Clears the KML from the Liquid Galaxy screens.
  Future<bool> clearFromLG() async {
    try {
      final playgroundService = ref.read(kmlPlaygroundServiceProvider);
      return await playgroundService.clearKml();
    } catch (e) {
      debugPrint('Playground: clearFromLG error: $e');
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

  /// Stops the currently playing tour on Liquid Galaxy.
  Future<bool> stopTour() async {
    try {
      final lgService = ref.read(lgServiceProvider);
      final ok = await lgService.stopTour();
      if (ok) state = state.copyWith(isTourPlaying: false);
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

  // ─── Internal Helpers ──────────────────────────────────────────────

  /// Regenerates the KML string from the current template + parameters,
  /// validates it, and updates the state.
  void _regenerateKml() {
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

  double? _extractDouble(Map<String, dynamic> params, String key) {
    final value = params[key];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

// ─── Provider ──────────────────────────────────────────────────────────

final playgroundControllerProvider =
    NotifierProvider<PlaygroundController, PlaygroundState>(() {
  return PlaygroundController();
});
