// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:fixnum/fixnum.dart';
import 'package:vutelemetry/src/sdk/trace/read_only_span_impl.dart';

import '../../../api.dart' as api;
import '../../../sdk.dart' as sdk;
import '../../sdk/common/attributes.dart';

/// A representation of the readable portions of a single operation
/// within a trace.
///
/// Warning: methods may be added to this interface in minor releases.
abstract class ReadOnlySpan {
  /// The name of the span.
  String get name;

  /// The kind of the span.
  api.SpanKind get kind;

  /// The context associated with this span.
  ///
  /// This context is an immutable, serializable identifier for this span that
  /// can be used to create new child spans and remains usable even after this
  /// span ends.
  api.SpanContext get spanContext;

  /// The parent span id.
  api.SpanId get parentSpanId;

  /// The time when the span was started.
  Int64 get startTime;

  /// The time when the span was closed, or null if still open.
  Int64? get endTime;

  /// The status of the span.
  api.SpanStatus get status;

  List<api.SpanEvent> get events;

  int get droppedEventsCount;

  /// The instrumentation library for the span.
  sdk.InstrumentationScope get instrumentationScope;

  List<api.SpanLink> get links;

  int get droppedLinksCount;

  Attributes get attributes;

  int get droppedAttributes;

  sdk.Resource get resource;

  Map<String, dynamic> toJson();

  factory ReadOnlySpan.fromJson(Map<String, dynamic> json) {
    return ReadOnlySpanImpl(
      name: json['name'],
      kind: api.SpanKind.values.firstWhere((e) => e.toString() == json['kind']),
      spanContext: api.SpanContext.fromJson(json['spanContext']),
      parentSpanId: api.SpanId.fromJson(json['parentSpanId']),
      startTime: Int64.parseInt(json['startTime']),
      endTime: json['endTime'] != null ? Int64.parseInt(json['endTime']) : null,
      status: api.SpanStatus.fromJson(json['status']),
      events: (json['events'] as List)
          .map((e) => api.SpanEvent.fromJson(e))
          .toList(),
      droppedEventsCount: json['droppedEventsCount'],
      instrumentationScope:
          sdk.InstrumentationScope.fromJson(json['instrumentationScope']),
      links:
          (json['links'] as List).map((l) => api.SpanLink.fromJson(l)).toList(),
      droppedLinksCount: json['droppedLinksCount'],
      attributes: Attributes.fromJson(json['attributes']),
      droppedAttributes: json['droppedAttributes'],
      resource: sdk.Resource.fromJson(json['resource']),
    );
  }
}
