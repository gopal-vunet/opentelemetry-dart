// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import '../../../api.dart' as api;

class SpanLink {
  final api.SpanContext context;
  final List<api.Attribute> attributes;
  final int droppedAttributes;

  SpanLink(this.context,
      {this.attributes = const [], this.droppedAttributes = 0});

  Map<String, dynamic> toJson() {
    return {
      'context': context.toJson(),
      'attributes': attributes.map((e) => e.toJson()).toList(),
      'droppedAttributes': droppedAttributes,
    };
  }

  factory SpanLink.fromJson(Map<String, dynamic> json) {
    return SpanLink(
      api.SpanContext.fromJson(json['context']),
      attributes: (json['attributes'] as List).map((e) => api.Attribute.fromJson(e)).toList(),
      droppedAttributes: json['droppedAttributes'],
    );
  }
}
