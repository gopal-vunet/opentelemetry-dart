import 'package:vutelemetry/src/instrumentation/initialisation.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'opentelemetry_method_channel.dart';

abstract class OpentelemetryPlatform extends PlatformInterface {
  /// Constructs a OpentelemetryPlatform.
  OpentelemetryPlatform() : super(token: _token);

  static final Object _token = Object();

  static OpentelemetryPlatform _instance = MethodChannelOpentelemetry();

  /// The default instance of [OpentelemetryPlatform] to use.
  ///
  /// Defaults to [MethodChannelOpentelemetry].
  static OpentelemetryPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [OpentelemetryPlatform] when
  /// they register themselves.
  static set instance(OpentelemetryPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getSessionId() {
    throw UnimplementedError('sessionId() has not been implemented.');
  }

  Future getDeviceInfo() async {
    throw UnimplementedError('getDeviceInfo() has not been implemented.');
  }

  Future<String?> initialise(InitialisationParams params) async {
    throw UnimplementedError('getDeviceId() has not been implemented.');
  }
}
