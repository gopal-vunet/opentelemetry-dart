import 'package:opentelemetry/api.dart';
import 'package:opentelemetry/src/instrumentation/global_attribute.dart';
import 'package:opentelemetry/src/instrumentation/nav_tracking/route_observer.dart';

final Tracer _tracer = globalTracerProvider.getTracer('click-instrumentation');

void logClickEvent(String eventName, {Map<String, String>? attributes}) async {
  
  final span = _tracer.startSpan(
    'Click',
    kind: SpanKind.client,
  );

  // Set the button name as an attribute
  span.setAttribute(Attribute.fromString('event.name', eventName));

  // Set any additional attributes
  attributes?.forEach((key, value) {
    span.setAttribute(Attribute.fromString(key, value));
  });

  span.setAttribute(
    Attribute.fromString(
      'screen.name',
      RouteObserverService().currentScreenName ?? 'unknown',
    ),
  );

  await addGlobalAttribute(span);

  // End the span
  span.end();
}
