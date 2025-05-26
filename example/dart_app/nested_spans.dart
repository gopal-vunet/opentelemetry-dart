import 'package:opentelemetry/sdk.dart';

void main(){
  // Create a tracer provider with a console exporter and a simple span
  // processor.
  final provider = TracerProviderBase(
    processors: [
      SimpleSpanProcessor(ConsoleExporter()),
    ],
  );

  // Create a tracer.
  final tracer = provider.getTracer('example');

  // Start a parent span.
  final parentSpan = tracer.startSpan('parent-span');

  // Start a child span.
  final childSpan = tracer.startSpan('child-span');

  // End the child span.
  childSpan.end();

  // End the parent span.
  parentSpan.end();
}