// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

/// A representation of a single piece of metadata attached to trace span.
class Attribute {
  final String key;
  final Object value;

  Attribute._(this.key, this.value);

  /// Create an Attribute from a String value.
  Attribute.fromString(this.key, String this.value);

  /// Create an Attribute from a boolean value.
  // ignore: avoid_positional_boolean_parameters
  Attribute.fromBoolean(this.key, bool this.value);

  /// Create an Attribute from a double-precision floating-point value.
  Attribute.fromDouble(this.key, double this.value);

  /// Create an Attribute from an integer value.
  Attribute.fromInt(this.key, int this.value);

  /// Create an Attribute from a list of String values.
  Attribute.fromStringList(this.key, List<String> this.value);

  /// Create an Attribute from a list of boolean values.
  Attribute.fromBooleanList(this.key, List<bool> this.value);

  /// Create an Attribute from a list of double-precision floating-point values.
  Attribute.fromDoubleList(this.key, List<double> this.value);

  /// Create an Attribute from a list of integer values.
  Attribute.fromIntList(this.key, List<int> this.value);

  Attribute.fromObject(this.key, this.value);

  /// Create an Attribute from a JSON object.
  factory Attribute.fromJson(Map<String, dynamic> json) {
    final key = json['key'] as String;
    final value = json['value'];

    return Attribute._(key, value);
    
    // if (value is String) {
    //   return Attribute.fromString(key, value);
    // } else if (value is bool) {
    //   return Attribute.fromBoolean(key, value);
    // } else if (value is double) {
    //   return Attribute.fromDouble(key, value);
    // // ignore: avoid_double_and_int_checks
    // } else if (value is int) {
    //   return Attribute.fromInt(key, value);
    // } else if (value is List<String>) {
    //   return Attribute.fromStringList(key, value);
    // } else if (value is List<bool>) {
    //   return Attribute.fromBooleanList(key, value);
    // } else if (value is List<double>) {
    //   return Attribute.fromDoubleList(key, value);
    // } else if (value is List<int>) {
    //   return Attribute.fromIntList(key, value);
    // } else {
    //   throw ArgumentError('Invalid attribute value type');
    // }
  }

  /// Convert an Attribute to a JSON object.
  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'value': value,
    };
  }
}
