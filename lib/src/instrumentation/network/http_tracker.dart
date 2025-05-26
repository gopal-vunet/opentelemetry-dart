import 'dart:io';

import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:vutelemetry/api.dart';
import 'package:vutelemetry/flutter_sdk.dart';
import 'package:vutelemetry/src/instrumentation/global_attribute.dart';

class _TextMapSetter implements TextMapSetter<Map<String, String>> {
  @override
  void set(Map<String, String> carrier, String key, String value) {
    carrier[key] = value;
  }
}

class TrackedHttpClient extends BaseClient {
  final Client _httpClient;
  final Tracer _tracer = globalTracerProvider.getTracer('http-instrumentation');
  static final Map<String, String> _ipAddressCache = {};

  TrackedHttpClient(this._httpClient);

  factory TrackedHttpClient.createDefault() {
    return TrackedHttpClient(Client());
  }

  bool _isIpAddress(String host) {
    return RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(host) || // IPv4
        host.contains(':'); // IPv6
  }

  Future<String> _getIpAddress(String host) async {
    if (_isIpAddress(host)) {
      return host;
    }

    if (_ipAddressCache.containsKey(host)) {
      return _ipAddressCache[host]!;
    }

    try {
      final addresses = await InternetAddress.lookup(host);
      final ipAddress =
          addresses.isNotEmpty ? addresses.first.address : 'UNKNOWN';
      _ipAddressCache[host] = ipAddress;
      return ipAddress;
    } catch (e) {
      return 'UNKNOWN';
    }
  }

  String _getProtocolVersion(StreamedResponse response) {
    if (response is IOStreamedResponse) {
      final httpResponse = response;
      return httpResponse.headers['version'] ?? '1.1';
    }
    return '1.1';
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final rootSpan = _tracer.startSpan(request.method, kind: SpanKind.client);

    print('Request: ${request.method} ${request.url}');
    print('span: ${rootSpan.toString()}, trcer: ${_tracer.toString()}');

    W3CTraceContextPropagator().inject(
      contextWithSpan(Context.current, rootSpan),
      request.headers,
      _TextMapSetter(),
    );

    final urlString = request.url.toString();

    rootSpan.setAttribute(
      Attribute.fromString('server.address', request.url.host),
    );
    rootSpan.setAttribute(
      Attribute.fromInt('server.port', request.url.port),
    );

    return _httpClient.send(request).then((response) async {
      // final headers = response.request?.headers ?? request.headers;
      // final requestHeaders = headers.map((k, v) => MapEntry(k, <String>[v]));
      // final responseHeaders = response.headers.map((k, v) => MapEntry(k, <String>[v]));

      rootSpan.setAttribute(
          Attribute.fromString('http.request.method', request.method));

      rootSpan.setAttribute(
          Attribute.fromInt('http.response.status_code', response.statusCode));
      rootSpan.setAttribute(Attribute.fromString(
          'http.status_text', response.reasonPhrase.toString()));

      rootSpan.setAttribute(
        Attribute.fromString(
          'network.protocol.version',
          // response.request?.url.scheme.toUpperCase() ?? 'UNKNOWN',
          _getProtocolVersion(response),
        ),
      );
      return response;
    }, onError: (e, StackTrace stacktrace) async {
      rootSpan.recordException(e, stackTrace: stacktrace);

      rootSpan.setAttribute(
        Attribute.fromString('exception.type', e.runtimeType.toString()),
      );

      rootSpan.setAttribute(
        Attribute.fromString(
          'exception.time',
          DateTime.now().microsecondsSinceEpoch.toString(),
        ),
      );

      throw e;
    }).whenComplete(() async {
      rootSpan.setAttribute(Attribute.fromString('url.full', urlString));

      final ipAddress = await _getIpAddress(request.url.host);

      rootSpan.setAttribute(
        Attribute.fromString('network.peer.address', ipAddress),
      );
      rootSpan.setAttribute(
        Attribute.fromInt('network.peer.port', request.url.port),
      );

      rootSpan.setAttribute(
        Attribute.fromString(
          'screen.name',
          RouteObserverService().currentScreenName ?? 'unknown',
        ),
      );

      await addGlobalAttribute(rootSpan);
      rootSpan.end();
    });
  }
}


