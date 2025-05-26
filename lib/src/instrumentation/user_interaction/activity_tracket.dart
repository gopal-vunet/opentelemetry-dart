import 'package:vutelemetry/api.dart';
import 'package:vutelemetry/src/instrumentation/global_attribute.dart';

class ActivityTracer{
  final Span _span;
  final String activityName;
  bool isActive = true;

  ActivityTracer(this.activityName, this._span);

  void end() async {
    if (!isActive) {
      return;
    }
    isActive = false;
    await addGlobalAttribute(_span);
    _span.end();
  }

  void setAttribute(Attribute attribute) {
    _span.setAttribute(attribute);
  }
  
  void setAttributes(List<Attribute> attributes) {
    for (var attribute in attributes) {
      _span.setAttribute(attribute);
    }
  }
}