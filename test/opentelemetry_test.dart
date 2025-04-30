import 'package:flutter_test/flutter_test.dart';
import 'package:opentelemetry/opentelemetry.dart';
import 'package:opentelemetry/opentelemetry_platform_interface.dart';
import 'package:opentelemetry/opentelemetry_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockOpentelemetryPlatform
    with MockPlatformInterfaceMixin
    implements OpentelemetryPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final OpentelemetryPlatform initialPlatform = OpentelemetryPlatform.instance;

  test('$MethodChannelOpentelemetry is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelOpentelemetry>());
  });

  test('getPlatformVersion', () async {
    Opentelemetry opentelemetryPlugin = Opentelemetry();
    MockOpentelemetryPlatform fakePlatform = MockOpentelemetryPlatform();
    OpentelemetryPlatform.instance = fakePlatform;

    expect(await opentelemetryPlugin.getPlatformVersion(), '42');
  });
}
