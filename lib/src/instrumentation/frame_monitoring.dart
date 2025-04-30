import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:vutelemetry/api.dart';
import 'package:vutelemetry/src/instrumentation/global_attribute.dart';
import 'package:vutelemetry/src/instrumentation/nav_tracking/route_observer.dart';

void startFrameMonitoring(Tracer tracer) async {
  const aggregationInterval = Duration(seconds: 5);
  Timer? statsTimer;

  Map<String, int> frameStats = {};

  SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
    for (var timing in timings) {
      final buildTime = timing.buildDuration.inMilliseconds;
      final rasterTime = timing.rasterDuration.inMilliseconds;

      // Define slow rendering thresholds
      bool isSlowBuild = buildTime > (kDebugMode ? 22 : 16); // 16ms for 60FPS
      bool isSlowRaster = rasterTime > (kDebugMode ? 16 : 8); // 8ms for 60FPS

      if (isSlowBuild || isSlowRaster) {
        frameStats[RouteObserverService().currentScreenName ?? "unknown"] =
            (frameStats[RouteObserverService().currentScreenName] ?? 0) + 1;

        statsTimer ??= Timer(aggregationInterval, () {
          if (frameStats.isNotEmpty) {
            final span = tracer.startSpan('slowRenders');

            for (var entry in frameStats.entries) {
              span.setAttribute(
                Attribute.fromString(
                  'screen.name',
                  entry.key,
                ),
              );
              span.setAttribute(
                Attribute.fromInt(
                  'count',
                  entry.value,
                ),
              );
            }
            addGlobalAttribute(span).then((_) => span.end());
            frameStats.clear();
          }

          statsTimer = null;
        });
      }
    }
  });
}
