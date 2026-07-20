import 'package:xml/xml.dart';

/// Lightweight KML validation utilities.
///
/// Uses the `xml` package (already in pubspec.yaml) to parse and
/// validate KML strings before they are sent to the Liquid Galaxy rig.
class KmlValidator {
  const KmlValidator();

  /// Validates the given [kmlString] as well-formed XML.
  ///
  /// Returns a [KmlValidationResult] with [isValid] true if the string
  /// parses successfully, or false with an [errorMessage] if it does not.
  KmlValidationResult validate(String kmlString) {
    try {
      XmlDocument.parse(kmlString);
      return const KmlValidationResult(isValid: true);
    } on XmlParserException catch (e) {
      return KmlValidationResult(
        isValid: false,
        errorMessage: 'XML parse error at line ${e.position}: ${e.message}',
      );
    } catch (e) {
      return KmlValidationResult(
        isValid: false,
        errorMessage: 'Unexpected error: $e',
      );
    }
  }
}

/// The result of a KML validation check.
class KmlValidationResult {
  final bool isValid;
  final String? errorMessage;

  const KmlValidationResult({
    required this.isValid,
    this.errorMessage,
  });
}
