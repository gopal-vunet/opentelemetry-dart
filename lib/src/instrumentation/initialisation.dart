import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:vutelemetry/api.dart';
import 'package:vutelemetry/flutter_sdk.dart';
import 'package:vutelemetry/opentelemetry_platform_interface.dart';
import 'package:vutelemetry/sdk.dart';
import 'package:vutelemetry/src/instrumentation/frame_monitoring.dart';
import 'package:vutelemetry/src/instrumentation/global_attribute.dart';
import 'package:vutelemetry/src/instrumentation/user_interaction/activity_tracket.dart';
import 'package:vutelemetry/src/instrumentation/user_interaction/maual_click_span.dart'
    as user_interaction;

class InitialisationParams {
  final String logsIngestUrl;
  final String tracesIngestUrl;
  final String appName;
  /// The type of app (e.g., 'Flutter', 'Kotlin', 'Swift')
  final String appType;
  /// The API key for authentication
  final String apiKey;
  /// The type of build (e.g., 'debug', 'release', 'uat')
  final String buildType; 
  final bool enableSlowFrameTracking;

  InitialisationParams({
    required this.logsIngestUrl,
    required this.tracesIngestUrl,
    required this.appName,
    required this.apiKey,
    required this.appType,
    required this.buildType,
    this.enableSlowFrameTracking = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'logsIngestUrl': logsIngestUrl,
      'tracesIngestUrl': tracesIngestUrl,
      'appName': appName,
      'appType': appType,
      'apiKey': apiKey,
      'buildType': buildType,
    };
  }
}

class VuTelemetry {
  /// Attributes to be added to all spans
  /// Fetched via the method channel for the respective platform
  /// and set as global attributes
  static final _globalAttributes = <String, String>{};

  static final _customAttributes = <String, String>{};

  static Map<String, String> get globalAttributes => _globalAttributes;

  static Map<String, String> get customAttributes => _customAttributes;


  /// Set multiple custom attributes
  static set customAttributes(Map<String, String> attributes) {
    _customAttributes.addAll(attributes);
  }

  /// Set a single custom attribute
  static setCustomAttribute(String key, String value) {
    _customAttributes[key] = value;
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

    // Set the buildType to global attributes
    _globalAttributes.addAll({
      'build.type': params.buildType,
    });

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
      // headers: {
      //   'Content-Type': 'application/x-protobuf',
      //   'X-API-Key': params.apiKey,
      //   'app-name': params.appName,
      //   'app-type': params.appType,
      // },
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

  static ActivityTracer logActivity(
    String eventName, {
    Map<String, String>? attributes,
  }) {
    final span = globalTracerProvider
        .getTracer('activity-instrumentation')
        .startSpan('Activity');

    // Set the activity name as an attribute
    span.setAttribute(Attribute.fromString('event.name', eventName));

    // Set any additional attributes
    attributes?.forEach((key, value) {
      span.setAttribute(Attribute.fromString(key, value));
    });

    return ActivityTracer(
      eventName,
      span,
    );
  }

  static void logClickEvent(
    String eventName, {
    Map<String, String>? attributes,
  }) async {
    user_interaction.logClickEvent(eventName, attributes: attributes);
  }
}
