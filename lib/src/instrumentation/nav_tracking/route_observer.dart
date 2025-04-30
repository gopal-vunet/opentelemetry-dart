import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vutelemetry/api.dart';
import 'package:vutelemetry/src/instrumentation/global_attribute.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RouteObserverService extends NavigatorObserver {
  static final RouteObserverService _instance =
      RouteObserverService._internal();
  Map<String, String?> _currentScreen = {};
  final Tracer _tracer = globalTracerProvider.getTracer('nav-instrumentation');

  factory RouteObserverService() {
    return _instance;
  }

  RouteObserverService._internal();

  String? get currentScreenName => _currentScreen['widget'];
  String? get currentScreenRoute => _currentScreen['route'];

  String? _getWidgetClassName(Route<dynamic>? route) {
    if (route is MaterialPageRoute) {
      return route.buildContent(navigator!.context).runtimeType.toString();
    }

    if (route is CupertinoPageRoute) {
      return route.buildContent(navigator!.context).runtimeType.toString();
    }

    return null;
  }

  Map<String, String?> _identifyScreen(Route<dynamic>? route) {
    return {
      "route": route?.settings.name,
      "widget": _getWidgetClassName(route)
    };
  }

  void _startSpan(Map<String, String?> previousScreen, [String? log]) async {
    final span = _tracer.startSpan(
      'Created',
    );
    span.setAttribute(
      Attribute.fromString(
        'last.screen.name',
        previousScreen['widget'] ?? 'unknown',
      ),
    );
    span.setAttribute(
      Attribute.fromString(
        'screen.name',
        currentScreenName ?? 'unknown',
      ),
    );
    span.setAttribute(
      Attribute.fromString(
        'last.screen.route',
        previousScreen['route'] ?? 'unknown',
      ),
    );
    span.setAttribute(
      Attribute.fromString(
        'screen.route',
        currentScreenRoute ?? 'unknown',
      ),
    );

    await addGlobalAttribute(span);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      span.addEvent('first_frame_rendered');
      span.end();
    });
  }

  @override
  void didChangeTop(
      Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) async {
    if ((topRoute is! PageRoute) || (previousTopRoute is! PageRoute)) {
      super.didChangeTop(topRoute, previousTopRoute);
      return;
    }
    _currentScreen = _identifyScreen(topRoute);
    final previousScreen = _identifyScreen(previousTopRoute);

    _startSpan(previousScreen);

    // Save current route to preferences
    await SharedPreferences.getInstance().then((prefs) {
      prefs.setString('currentRoute', _currentScreen['route'] ?? 'unknown');
      prefs.setString('currentWidget', _currentScreen['widget'] ?? 'unknown');
    });

    super.didChangeTop(topRoute, previousTopRoute);
  }
}
