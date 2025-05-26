// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import '../../../api.dart' as api;
import '../common/attributes.dart';

class Resource {
  final Attributes _attributes;

  Resource(List<api.Attribute> attributes)
      : _attributes = Attributes.empty()..addAll(attributes);

  Attributes get attributes => _attributes;

  Map<String, dynamic> toJson() {
    return {
      'attributes': _attributes.toJson(),
    };
  }

  factory Resource.fromJson(Map<String, dynamic> json) {
    return Resource(
      (json['attributes'] as List).map((e) => api.Attribute.fromJson(e)).toList(),
    );
  }
}
