import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vutelemetry/src/instrumentation/initialisation.dart';

import 'opentelemetry_platform_interface.dart';

/// An implementation of [OpentelemetryPlatform] that uses method channels.
class MethodChannelOpentelemetry extends OpentelemetryPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('opentelemetry');

  @override
  Future<String?> getSessionId() async {
    final version = await methodChannel.invokeMethod<String>('getSessionId');
    return version;
  }

  @override
  Future getDeviceInfo() async {
    return await methodChannel.invokeMethod('getDeviceInfo');
  }

  @override
  Future<String?> initialise(InitialisationParams params) async {
    final version = await methodChannel.invokeMethod<String>(
      'initialise',
      params.toJson(),
    );
    return version;
  }
}
