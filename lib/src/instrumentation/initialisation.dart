import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:opentelemetry/api.dart';
import 'package:opentelemetry/flutter_sdk.dart';
import 'package:opentelemetry/opentelemetry_platform_interface.dart';
import 'package:opentelemetry/sdk.dart';
import 'package:opentelemetry/src/instrumentation/frame_monitoring.dart';
import 'package:opentelemetry/src/instrumentation/global_attribute.dart';

class InitialisationParams {
  final String logsIngestUrl;
  final String tracesIngestUrl;
  final String appName;
  final String appType;
  final bool enableSlowFrameTracking;

  InitialisationParams({
    required this.logsIngestUrl,
    required this.tracesIngestUrl,
    required this.appName,
    required this.appType,
    this.enableSlowFrameTracking = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'logsIngestUrl': logsIngestUrl,
      'tracesIngestUrl': tracesIngestUrl,
      'appName': appName,
      'appType': appType,
    };
  }
}

class VuTelemetry {
  /// Attributes to be added to all spans
  /// Fetched via the method channel for the respective platform
  /// and set as global attributes
  static final _globalAttributes = <String, String>{};

  static Map<String, String> get globalAttributes => _globalAttributes;

  /// Set multiple custom attributes
  static set customAttributes(Map<String, String> attributes) {
    _globalAttributes.addAll(attributes);
  }

  /// Set a single custom attribute
  static setCustomAttribute(String key, String value) {
    _globalAttributes[key] = value;
  }

  static bool _isInitialised = false;
  static late InitialisationParams _initialisationParams;

  static bool get isInitialised => _isInitialised;
  static InitialisationParams get initialisationParams => _initialisationParams;

  static Future<void> initialise({
    required InitialisationParams params,
    Client? httpClient,
  }) async {
    _initialisationParams = params;
    // Initialize the Native OpenTelemetry SDK
    OpentelemetryPlatform.instance.initialise(params);

    // Gathering all the device information
    // and setting it as global attributes
    await _collectDeviceInfo();

    final platformOriginalOnError = PlatformDispatcher.instance.onError;

    // Set the error handler to capture errors
    PlatformDispatcher.instance.onError = (e, st) {
      final span = globalTracerProvider
          .getTracer('platform-error-handler')
          .startSpan('Error');

      span.recordException(e, stackTrace: st);

      span.setStatus(StatusCode.error, e.toString());

      span.setAttribute(
        Attribute.fromString(
          'screen.name',
          RouteObserverService().currentScreenName ?? 'unknown',
        ),
      );

      addGlobalAttribute(span).then((_) {
        span.end();
      });

      return platformOriginalOnError?.call(e, st) ?? false;
    };

    final exporter = CollectorExporter(
      Uri.parse(params.tracesIngestUrl),
      httpClient: httpClient,
    );

    FlutterError.onError = (FlutterErrorDetails details) async {
      FlutterError.dumpErrorToConsole(details);

      final span =
          globalTracerProvider.getTracer('error-handler').startSpan('error');

      span.recordException(
        details.exception,
        stackTrace: details.stack ?? StackTrace.current,
      );

      span.setStatus(StatusCode.error, details.exception.toString());

      span.setAttribute(
        Attribute.fromString(
          'screen.name',
          RouteObserverService().currentScreenName ?? 'unknown',
        ),
      );
      await addGlobalAttribute(span);

      span.end();
    };

    final processor = DiskSpanProcessor(
      exporter,
      maxExportBatchSize: 24,
      scheduledDelayMillis: 5000,
    );

    final provider = TracerProviderBase(
      processors: [processor],
      resource: Resource(
        [Attribute.fromString("service.name", "vuBank-flutter")],
      ),
    );

    registerGlobalTracerProvider(provider);

    if (_initialisationParams.enableSlowFrameTracking) {
      // Enable slow frame tracking
      startFrameMonitoring(globalTracerProvider.getTracer('frame-monitoring'));
    }

    _isInitialised = true;
  }

  static Future<void> _collectDeviceInfo() async {
    try {
      final deviceInfo = await OpentelemetryPlatform.instance.getDeviceInfo();
      deviceInfo?.forEach((key, value) {
        _globalAttributes[key] = value;
      });
    } catch (e) {
      print('Failed to get device info: $e');
    }
  }

  static void logClickEvent(
    String eventName, {
    Map<String, String>? attributes,
  }) async {
    logClickEvent(eventName, attributes: attributes);
  }
}
