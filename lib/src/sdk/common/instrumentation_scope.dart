// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:vutelemetry/api.dart' as api;

class InstrumentationScope {
  final String _name;
  final String _version;
  final String _schemaUrl;
  final List<api.Attribute> _attributes;

  InstrumentationScope(
      this._name, this._version, this._schemaUrl, this._attributes);

  String get name {
    return _name;
  }

  String get version {
    return _version;
  }

  String get schemaUrl {
    return _schemaUrl;
  }

  List<api.Attribute> get attributes {
    return _attributes;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': _name,
      'version': _version,
      'schemaUrl': _schemaUrl,
      'attributes': _attributes.map((e) => e.toJson()).toList(),
    };
  }

  factory InstrumentationScope.fromJson(Map<String, dynamic> json) {
    return InstrumentationScope(
      json['name'],
      json['version'],
      json['schemaUrl'],
      (json['attributes'] as List)
          .map((e) => api.Attribute.fromJson(e))
          .toList(),
    );
  }
}
