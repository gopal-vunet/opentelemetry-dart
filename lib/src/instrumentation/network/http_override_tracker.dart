import 'dart:convert';
import 'dart:io';
import 'package:vutelemetry/api.dart';
import 'package:vutelemetry/flutter_sdk.dart';
import 'package:vutelemetry/src/instrumentation/global_attribute.dart';

class TrackedHttpOverrides extends HttpOverrides {
  static final Map<String, String> _ipAddressCache = {};

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _TrackedHttpClient(super.createHttpClient(context));
  }
}

class _TrackedHttpClient implements HttpClient {
  final HttpClient _inner;

  _TrackedHttpClient(this._inner)
      : autoUncompress = true,
        idleTimeout = const Duration(seconds: 15);

  bool _isIpAddress(String host) {
    return RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(host) || // IPv4
        host.contains(':'); // IPv6
  }

  Future<String> _getIpAddress(String host) async {
    if (_isIpAddress(host)) {
      return host;
    }

    if (TrackedHttpOverrides._ipAddressCache.containsKey(host)) {
      return TrackedHttpOverrides._ipAddressCache[host]!;
    }

    try {
      final addresses = await InternetAddress.lookup(host);
      final ipAddress =
          addresses.isNotEmpty ? addresses.first.address : 'UNKNOWN';
      TrackedHttpOverrides._ipAddressCache[host] = ipAddress;
      return ipAddress;
    } catch (e) {
      return 'UNKNOWN';
    }
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    print('➡️ Intercepted Request: $method $url');
    final request = await _inner.openUrl(method, url);
    return _wrapRequest(request, method, url);
  }

  Future<HttpClientRequest> _wrapRequest(
    HttpClientRequest request,
    String method,
    Uri url,
  ) async {
    final Tracer _tracer =
        globalTracerProvider.getTracer('http-instrumentation');

    final span = _tracer.startSpan(method, kind: SpanKind.client);

    W3CTraceContextPropagator().inject(
      contextWithSpan(Context.current, span),
      request.headers,
      _HeaderSetter(),
    );

    span.setAttribute(Attribute.fromString('server.address', url.host));
    span.setAttribute(Attribute.fromInt('server.port', url.port));

    return _TrackedHttpClientRequest(request, span, url, _getIpAddress);
  }

  @override
  bool autoUncompress;

  @override
  Duration? connectionTimeout;

  @override
  Duration idleTimeout;

  @override
  int? maxConnectionsPerHost;

  @override
  String? userAgent;

  @override
  void addCredentials(
          Uri url, String realm, HttpClientCredentials credentials) =>
      _inner.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(String host, int port, String realm,
          HttpClientCredentials credentials) =>
      _inner.addProxyCredentials(host, port, realm, credentials);

  @override
  set authenticate(
      Future<bool> Function(Uri url, String scheme, String? realm)? f) {
    _inner.authenticate = f;
  }

  @override
  set authenticateProxy(
      Future<bool> Function(
              String host, int port, String scheme, String? realm)?
          f) {
    _inner.authenticateProxy = f;
  }

  @override
  set badCertificateCallback(
      bool Function(X509Certificate cert, String host, int port)? callback) {
    _inner.badCertificateCallback = callback;
  }

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  set connectionFactory(
      Future<ConnectionTask<Socket>> Function(
              Uri url, String? proxyHost, int? proxyPort)?
          f) {
    _inner.connectionFactory = f;
  }

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      _inner.delete(host, port, path);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => _inner.deleteUrl(url);

  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      _inner.get(host, port, path);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => _inner.getUrl(url);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      _inner.head(host, port, path);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => _inner.headUrl(url);

  @override
  set keyLog(Function(String line)? callback) => _inner.keyLog = callback;

  @override
  Future<HttpClientRequest> open(
          String method, String host, int port, String path) =>
      _inner.open(method, host, port, path);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      _inner.patch(host, port, path);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => _inner.patchUrl(url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      _inner.post(host, port, path);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => _inner.postUrl(url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      _inner.put(host, port, path);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => _inner.putUrl(url);
}

class _TrackedHttpClientRequest implements HttpClientRequest {
  final HttpClientRequest _inner;
  final Span _span;
  final Uri _url;
  final Future<String> Function(String) _getIpAddress;

  _TrackedHttpClientRequest(
      this._inner, this._span, this._url, this._getIpAddress)
      : bufferOutput = _inner.bufferOutput,
        contentLength = _inner.contentLength,
        encoding = _inner.encoding,
        followRedirects = _inner.followRedirects,
        maxRedirects = _inner.maxRedirects,
        persistentConnection = _inner.persistentConnection;

  @override
  Future<HttpClientResponse> close() async {
    try {
      final response = await _inner.close();
      return _processResponse(response);
    } catch (e, stackTrace) {
      _span.recordException(e, stackTrace: stackTrace);
      _span.setAttribute(
          Attribute.fromString('exception.type', e.runtimeType.toString()));
      _span.setAttribute(
        Attribute.fromString(
            'exception.time', DateTime.now().microsecondsSinceEpoch.toString()),
      );
      rethrow;
    }
  }

  Future<HttpClientResponse> _processResponse(
      HttpClientResponse response) async {
    _span.setAttribute(
        Attribute.fromString('http.request.method', _inner.method));
    _span.setAttribute(
        Attribute.fromInt('http.response.status_code', response.statusCode));
    _span.setAttribute(
        Attribute.fromString('http.status_text', response.reasonPhrase));
    _span.setAttribute(Attribute.fromString('url.full', _url.toString()));

    final ipAddress = await _getIpAddress(_url.host);
    _span.setAttribute(Attribute.fromString('network.peer.address', ipAddress));
    _span.setAttribute(Attribute.fromInt('network.peer.port', _url.port));
    _span.setAttribute(
      Attribute.fromString(
        'screen.name',
        RouteObserverService().currentScreenName ?? 'unknown',
      ),
    );

    await addGlobalAttribute(_span);
    _span.end();

    return response;
  }

  @override
  bool bufferOutput;

  @override
  int contentLength;

  @override
  Encoding encoding;

  @override
  bool followRedirects;

  @override
  int maxRedirects;

  @override
  bool persistentConnection;

  @override
  void abort([Object? exception, StackTrace? stackTrace]) => _inner.abort;

  @override
  void add(List<int> data) => _inner.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future addStream(Stream<List<int>> stream) => _inner.addStream(stream);

  @override
  HttpConnectionInfo? get connectionInfo => _inner.connectionInfo;

  @override
  List<Cookie> get cookies => _inner.cookies;

  @override
  Future<HttpClientResponse> get done => _inner.done;

  @override
  Future flush() => _inner.flush();

  @override
  HttpHeaders get headers => _inner.headers;

  @override
  String get method => _inner.method;

  @override
  Uri get uri => _inner.uri;

  @override
  void write(Object? object) => _inner.write(object);

  @override
  void writeAll(Iterable objects, [String separator = ""]) =>
      _inner.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _inner.writeCharCode(charCode);

  @override
  void writeln([Object? object = ""]) => _inner.writeln(object);
}

class _HeaderSetter implements TextMapSetter<HttpHeaders> {
  @override
  void set(HttpHeaders carrier, String key, String value) {
    carrier.set(key, value);
  }
}
