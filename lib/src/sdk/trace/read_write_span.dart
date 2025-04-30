// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:vutelemetry/api.dart' as api;
import 'package:vutelemetry/sdk.dart' as sdk;

abstract class ReadWriteSpan implements sdk.ReadOnlySpan, api.Span {}
