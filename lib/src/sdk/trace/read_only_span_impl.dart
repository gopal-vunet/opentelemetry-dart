import 'package:fixnum/fixnum.dart';

import '../../../api.dart' as api;
import '../../../sdk.dart' as sdk;
import '../../sdk/common/attributes.dart';
import 'read_only_span.dart';

class ReadOnlySpanImpl implements ReadOnlySpan {
  @override
  final String name;
  @override
  final api.SpanKind kind;
  @override
  final api.SpanContext spanContext;
  @override
  final api.SpanId parentSpanId;
  @override
  final Int64 startTime;
  @override
  final Int64? endTime;
  @override
  final api.SpanStatus status;
  @override
  final List<api.SpanEvent> events;
  @override
  final int droppedEventsCount;
  @override
  final sdk.InstrumentationScope instrumentationScope;
  @override
  final List<api.SpanLink> links;
  @override
  final int droppedLinksCount;
  @override
  final Attributes attributes;
  @override
  final int droppedAttributes;
  @override
  final sdk.Resource resource;

  ReadOnlySpanImpl({
    required this.name,
    required this.kind,
    required this.spanContext,
    required this.parentSpanId,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.events,
    required this.droppedEventsCount,
    required this.instrumentationScope,
    required this.links,
    required this.droppedLinksCount,
    required this.attributes,
    required this.droppedAttributes,
    required this.resource,
  });
  
  @override
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'kind': kind.toString(),
      'spanContext': spanContext.toJson(),
      'parentSpanId': parentSpanId.toJson(),
      'startTime': startTime.toString(),
      'endTime': endTime?.toString(),
      'status': status.toJson(),
      'events': events.map((e) => e.toJson()).toList(),
      'droppedEventsCount': droppedEventsCount,
      'instrumentationScope': instrumentationScope.toJson(),
      'links': links.map((l) => l.toJson()).toList(),
      'droppedLinksCount': droppedLinksCount,
      'attributes': attributes.toJson(),
      'droppedAttributes': droppedAttributes,
      'resource': resource.toJson(),
    };
  }
}
