import 'package:vutelemetry/api.dart';
import 'package:vutelemetry/opentelemetry_platform_interface.dart';
import 'package:vutelemetry/src/instrumentation/initialisation.dart';

/// This method is called to add global attributes to a span
/// before it is sent to the server.
Future<void> addGlobalAttribute(Span span) async {
  final sessionId = await OpentelemetryPlatform.instance.getSessionId() ?? '';

  span.setAttribute(
    Attribute.fromString('session.id', sessionId),
  );

  VuTelemetry.globalAttributes.forEach((key, value) {
    span.setAttribute(Attribute.fromString(key, value));
  });

  VuTelemetry.customAttributes.forEach((key, value) {
    span.setAttribute(Attribute.fromString(key, value));
  });


  span.setAttribute(
    Attribute.fromString(
        'android.type', VuTelemetry.initialisationParams.appType),
  );
  span.setAttribute(
    Attribute.fromString('app.name', VuTelemetry.initialisationParams.appName),
  );
}
