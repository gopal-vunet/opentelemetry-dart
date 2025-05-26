// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import '../../api.dart' as api;

/// A provider to manage span context updates and retrieval.
class SpanContextProvider {
  /// Returns the current span context from the given context.
  /// If no span context exists, returns an invalid span context.
  static api.SpanContext getCurrentContext(api.Context context) {
    return api.spanContextFromContext(context);
  }

  /// Updates the given context with a new span context.
  /// Returns a new context containing the span context.
  static api.Context updateContext(api.Context context, api.SpanContext spanContext) {
    return api.contextWithSpanContext(context, spanContext);
  }

  /// Checks if the given span context is valid.
  /// A span context is valid if it has both a valid trace ID and span ID.
  static bool isContextValid(api.SpanContext spanContext) {
    return spanContext.isValid;
  }

  /// Creates a new remote span context.
  /// Used when receiving span context from external sources.
  static api.SpanContext createRemoteContext(
      api.TraceId traceId,
      api.SpanId spanId,
      int traceFlags,
      api.TraceState traceState) {
    return api.SpanContext.remote(traceId, spanId, traceFlags, traceState);
  }
}
