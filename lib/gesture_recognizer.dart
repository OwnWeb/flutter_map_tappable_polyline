import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

class SingleTapGestureRecognizer extends OneSequenceGestureRecognizer {
  final Function onTapUp;
  final Function validatePointerLocation;

  SingleTapGestureRecognizer(
      {@required this.onTapUp, @required this.validatePointerLocation});

  @override
  String get debugDescription => 'flutter_map_tappable_polyline';

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  void handleEvent(PointerEvent event) {
    if (event is! PointerUpEvent) {
      onTapUp(event);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void addPointer(PointerDownEvent event) {
    if (validatePointerLocation(event)) {
      startTrackingPointer(event.pointer);
      resolve(GestureDisposition.accepted);
    } else {
      stopTrackingPointer(event.pointer);
    }
  }
}
