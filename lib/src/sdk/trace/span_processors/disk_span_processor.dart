// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

import '../../../api/context/context.dart';
import '../../../api/trace/trace_flags.dart';
import '../exporters/span_exporter.dart';
import '../read_only_span.dart';
import '../read_write_span.dart';
import 'span_processor.dart';

class DiskSpanProcessor implements SpanProcessor {
  /// One request payload
  static const int _DEFAULT_MAXIMUM_BATCH_SIZE = 512;

  /// Stoted in memory
  static const int _DEFAULT_MAXIMUM_QUEUE_SIZE = 2048;

  static const int _DEFAULT_EXPORT_DELAY = 5000;

  final SpanExporter _exporter;
  final Logger _log = Logger('opentelemetry.DiskSpanProcessor');
  final int _maxExportBatchSize;
  final int _maxQueueSize;
  final List<ReadOnlySpan> _spanBuffer = [];

  late final Timer _timer;

  bool _isShutdown = false;

  DiskSpanProcessor(this._exporter,
      {int maxExportBatchSize = _DEFAULT_MAXIMUM_BATCH_SIZE,
      int scheduledDelayMillis = _DEFAULT_EXPORT_DELAY})
      : _maxExportBatchSize = maxExportBatchSize,
        _maxQueueSize = _DEFAULT_MAXIMUM_QUEUE_SIZE {
    _timer = Timer.periodic(
        Duration(milliseconds: scheduledDelayMillis), _exportBatch);
  }

  @override
  void forceFlush() {
    if (_isShutdown) {
      return;
    }
    while (_spanBuffer.isNotEmpty) {
      for (var span in _spanBuffer) {
        SpanFileStorage.saveSpan(span.toJson());
      }
      // _exportBatch(_timer);
    }
  }

  @override
  void onEnd(ReadOnlySpan span) {
    if (_isShutdown) {
      return;
    }
    _addToBuffer(span);
  }

  @override
  void onStart(ReadWriteSpan span, Context parentContext) {}

  @override
  void shutdown() {
    forceFlush();
    _isShutdown = true;
    _timer.cancel();
    _exporter.shutdown();
  }

  void _addToBuffer(ReadOnlySpan span) {
    if (_spanBuffer.length >= _maxQueueSize) {
      // runZonedGuarded(
      //   () async {
      //     print(jsonEncode(span.toJson()));
      //     await SpanFileStorage.saveSpan(span.toJson());
      //   },
      //   (error, stackTrace) {
      //     _log.severe('Error saving span to disk: $error', error, stackTrace);
      //   },
      //   zoneValues: {'logPrefix': '[DiskSpanProcessor] '},
      //   zoneSpecification: ZoneSpecification(
      //     print: (self, parent, zone, message) {
      //       parent.print(zone, '${zone['logPrefix']} $message');
      //     },
      //   ),
      // );

      SpanFileStorage.saveSpan(span.toJson());

      // _log.warning(
      //     'Max queue size exceeded. Dropping ${_spanBuffer.length} spans.');

      _exportBatch(_timer);

      // _log.info(
      //     'Max queue size exceeded in buffer ${_spanBuffer.length} spans. Storing in Disk');
      // return;
    }

    final isSampled =
        span.spanContext.traceFlags & TraceFlags.sampled == TraceFlags.sampled;
    if (isSampled) {
      _spanBuffer.add(span);
    }
  }

  void _exportBatch(Timer timer) {
    if (_spanBuffer.isEmpty) {
      return;
    }

    SpanFileStorage.getSpanFileCount().then((count) {
      if (count > 0) {
        final availableSpace = _maxQueueSize - _spanBuffer.length;
        SpanFileStorage.getAndDeleteSpans(min(availableSpace, count))
            .then((spans) {
          List<ReadOnlySpan>.from(
              spans.map((span) => ReadOnlySpan.fromJson(span))).forEach((span) {
            _addToBuffer(span);
          });
        });
      }
    });

    final batchSize = min(_spanBuffer.length, _maxExportBatchSize);
    final batch = _spanBuffer.sublist(0, batchSize);
    _spanBuffer.removeRange(0, batchSize);

    _exporter.export(batch);

    _log.info('Exporting batch of $batchSize spans');

    // Empty the buffer if it's not empty
    if(_spanBuffer.isNotEmpty) {
      _exportBatch(timer);
    }
  }

  void printSpans() async {
    final spans = await SpanFileStorage.getSpans();
    spans.forEach((span) {
      print(span);
    });
  }
}

class SpanFileStorage {
  static Logger _log = Logger('opentelemetry.SpanFileStorage');
  static final List<Map<String, dynamic>> _spanQueue = [];
  static bool _isIsolateRunning = false;

  static Future<Directory> _getDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final spansDirectory = Directory('${directory.path}/spans');
    if (!await spansDirectory.exists()) {
      await spansDirectory.create(recursive: true);
    }
    return spansDirectory;
  }

  static Future<void> saveSpan(Map<String, dynamic> span) async {
    _spanQueue.add(span);
    _processQueue();
  }

  static Future<void> saveSpans(List<Map<String, dynamic>> spans) async {
    _spanQueue.addAll(spans);
    _processQueue();
  }

  static void _processQueue() async {
    if (_isIsolateRunning || _spanQueue.isEmpty) {
      return;
    }

    _isIsolateRunning = true;
    final directory = await _getDirectory();
    final receivePort = ReceivePort();
    await Isolate.spawn(
      _writeToFile,
      [directory.path, _spanQueue, receivePort.sendPort],
    );
    await receivePort.first;
    _spanQueue.clear();
    _isIsolateRunning = false;
  }

  static void _writeToFile(List<dynamic> args) async {
    final directoryPath = args[0] as String;
    final spans = args[1] as List<Map<String, dynamic>>;
    final sendPort = args[2] as SendPort;

    for (var span in spans) {
      final fileName =
          "${toHexString(span['spanContext']['spanId']['id'])}.json";
      final file = File('$directoryPath/$fileName');
      await file.writeAsString(jsonEncode(span), mode: FileMode.write);
    }

    sendPort.send(null);
  }

  static String toHexString(List<int> bytes) {
    try {
      return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    } on Exception catch (e) {
      print('Name Formation Exception: $e');
      return DateTime.now().microsecondsSinceEpoch.toString();
    }
  }

  static Future<List<Map<String, dynamic>>> getSpans() async {
    final directory = await _getDirectory();
    final files = directory.listSync().whereType<File>();
    List<Map<String, dynamic>> spans = [];

    for (var file in files) {
      final content = await file.readAsString();
      if (content.isNotEmpty) {
        spans.add(jsonDecode(content));
      }
    }

    return spans;
  }

  static Future<void> deleteSpans() async {
    final directory = await _getDirectory();
    final files = directory.listSync().whereType<File>();

    for (var file in files) {
      await file.delete();
    }
  }

  static Future<int> getSpanFileCount() async {
    final directory = await _getDirectory();
    final files = directory.listSync().whereType<File>();
    return files.length;
  }

  static Future<List<Map<String, dynamic>>> getAndDeleteSpans(int count) async {
    final directory = await _getDirectory();
    final files = directory.listSync().whereType<File>().take(count).toList();
    List<Map<String, dynamic>> spans = [];

    for (var file in files) {
      final content = await file.readAsString();
      if (content.isNotEmpty) {
        spans.add(jsonDecode(content));
      }
      await file.delete();
    }

    return spans;
  }
}
