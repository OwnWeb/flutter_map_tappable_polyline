library flutter_map_tappable_polyline;

import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// A polyline with a tag
class TaggedPolyline extends Polyline {
  /// The name of the polyline
  final String? tag;

  final List<Offset> _offsets = [];

  TaggedPolyline({
    required super.points,
    super.strokeWidth = 1.0,
    super.color = const Color(0xFF00FF00),
    super.borderStrokeWidth = 0.0,
    super.borderColor = const Color(0xFFFFFF00),
    super.gradientColors,
    super.colorsStop,
    super.isDotted = false,
    this.tag,
  });
}

/// Definition of a callback when a polyline was tapped. It provides the
/// render-box tap position, the lat-long position and the list of
/// polylines that were hit.
typedef TapPolylinesCallback = void Function(TapPosition position, LatLng latLng, List<TaggedPolyline>);

class TappablePolylineLayer extends PolylineLayer {
  /// The list of [TaggedPolyline] which could be tapped
  @override
  final List<TaggedPolyline> polylines;

  /// The tolerated distance between pointer and user tap to trigger the [onTap] callback
  final double pointerDistanceTolerance;

  /// The callback to call when a polyline was hit by the tap.
  final TapPolylinesCallback? onTap;

  /// The callback to call when a polyline was hit by the long press.
  final TapPolylinesCallback? onLongPress;

  /// The optional callback to call when no polyline was hit by the tap
  final void Function(TapPosition position, LatLng latLng)? onMiss;

  /// Whether to forward the hit gesture events to the parent map.
  final bool forwardGestures;

  TappablePolylineLayer({
    this.polylines = const [],
    this.onTap,
    this.onLongPress,
    this.onMiss,
    this.pointerDistanceTolerance = 15,
    this.forwardGestures = true,
    super.polylineCulling = false,
    key,
  }) : super(key: key, polylines: polylines);

  @override
  Widget build(BuildContext context) {
    final mapCamera = MapCamera.of(context);

    return _build(
      context,
      Size(mapCamera.size.x, mapCamera.size.y),
      polylineCulling
          ? polylines
              .where(
                  (p) => p.boundingBox.isOverlapping(mapCamera.visibleBounds))
              .toList()
          : polylines,
    );
  }

  Widget _build(BuildContext context, Size size, List<TaggedPolyline> lines) {
    final MapCamera mapCamera = MapCamera.of(context);

    for (TaggedPolyline polyline in lines) {
      polyline._offsets.clear();
      var i = 0;
      for (var point in polyline.points) {
        var pos = mapCamera.project(point);
        pos = (pos * mapCamera.getZoomScale(mapCamera.zoom, mapCamera.zoom)) - 
            mapCamera.pixelOrigin.toDoublePoint();
        polyline._offsets.add(Offset(pos.x.toDouble(), pos.y.toDouble()));
        if (i > 0 && i < polyline.points.length) {
          polyline._offsets.add(Offset(pos.x.toDouble(), pos.y.toDouble()));
        }
        i++;
      }
    }

    return Container(
      child: GestureDetector(
        onDoubleTap: () {
          // For some strange reason i have to add this callback for the onDoubleTapDown callback to be called.
        },
        onDoubleTapDown: (TapDownDetails details) {
          _zoomMap(details, context);
        },
        onTapUp: (TapUpDetails details) {
          _handleGesture(
            context,
            TapPosition(details.globalPosition, details.localPosition),
            onTap,
            MapOptions.of(context).onTap,
          );
        },
        onLongPressStart: (LongPressStartDetails details) {
          _handleGesture(
            context,
            TapPosition(details.globalPosition, details.localPosition),
            onLongPress,
            MapOptions.of(context).onLongPress,
          );
        },
        child: Stack(
          children: [
            CustomPaint(
              painter: PolylinePainter(lines, mapCamera),
              size: size,
            ),
          ],
        ),
      ),
    );
  }

  void _handleGesture(
    final BuildContext context,
    final TapPosition tapPosition,
    final TapPolylinesCallback? callback,
    final void Function(TapPosition tapPosition, LatLng point)? parentCallback,
  ) {
    // Get the current map camera and options.
    final MapCamera mapCamera = MapCamera.of(context);

    // Convert the tap offset-position to geographical coordinates.
    final LatLng latlng = mapCamera.offsetToCrs(tapPosition.relative!);

    if (callback == null && parentCallback == null) {
      // This layer shall be translucent to hits.
      parentCallback?.call(tapPosition, latlng);

      onMiss?.call(tapPosition, latlng);
    } else {
      final List<TaggedPolyline> polylines = _getHitPolylines(tapPosition);
      if (polylines.isEmpty) {
        // This layer shall be translucent to miss hits.
        parentCallback?.call(tapPosition, latlng);

        onMiss?.call(tapPosition, latlng);
      } else {
        // Forward the gesture to the parent map if requested.
        if (forwardGestures) parentCallback?.call(tapPosition, latlng);

        callback?.call(tapPosition, latlng, polylines);
      }
    }
  }

  List<TaggedPolyline> _getHitPolylines(TapPosition tapPosition) {
    // We might hit close to multiple polylines. We will therefore keep a reference to these in this map.
    Map<double, List<TaggedPolyline>> candidates = {};

    // Calculating taps in between points on the polyline. We
    // iterate over all the segments in the polyline to find any
    // matches with the tapped point within the
    // pointerDistanceTolerance.
    for (TaggedPolyline currentPolyline in polylines) {
      for (var j = 0; j < currentPolyline._offsets.length - 1; j++) {
        // We consider the points point1, point2 and tap points in a triangle
        var point1 = currentPolyline._offsets[j];
        var point2 = currentPolyline._offsets[j + 1];
        var tap = tapPosition.relative!;

        // To determine if we have tapped in between two po ints, we
        // calculate the length from the tapped point to the line
        // created by point1, point2. If this distance is shorter
        // than the specified threshold, we have detected a tap
        // between two points.
        //
        // We start by calculating the length of all the sides using pythagoras.
        var a = _distance(point1, point2);
        var b = _distance(point1, tap);
        var c = _distance(point2, tap);

        // To find the height when we only know the lengths of the sides, we can use Herons formula to get the Area.
        var semiPerimeter = (a + b + c) / 2.0;
        var triangleArea = sqrt(semiPerimeter *
            (semiPerimeter - a) *
            (semiPerimeter - b) *
            (semiPerimeter - c));

        // We can then finally calculate the length from the tapped point onto the line created by point1, point2.
        // Area of triangles is half the area of a rectangle
        // area = 1/2 base * height -> height = (2 * area) / base
        var height = (2 * triangleArea) / a;

        // We're not there yet - We need to satisfy the edge case
        // where the perpendicular line from the tapped point onto
        // the line created by point1, point2 (called point D) is
        // outside of the segment point1, point2. We need
        // to check if the length from D to the original segment
        // (point1, point2) is less than the threshold.

        var hypotenus = max(b, c);
        var newTriangleBase = sqrt((hypotenus * hypotenus) - (height * height));
        var lengthDToOriginalSegment = newTriangleBase - a;

        if (height < pointerDistanceTolerance &&
            lengthDToOriginalSegment < pointerDistanceTolerance) {
          var minimum = min(height, lengthDToOriginalSegment);

          candidates[minimum] ??= <TaggedPolyline>[];
          candidates[minimum]!.add(currentPolyline);
        }
      }
    }

    if (candidates.isEmpty) return [];

    // We look up in the map of distances to the tap, and choose the shortest one.
    var closestToTapKey = candidates.keys.reduce(min);
    return candidates[closestToTapKey]!;
  }

  double _distance(Offset point1, Offset point2) {
    var distancex = (point1.dx - point2.dx).abs();
    var distancey = (point1.dy - point2.dy).abs();

    var distance = sqrt((distancex * distancex) + (distancey * distancey));

    return distance;
  }

  void _zoomMap(TapDownDetails details, BuildContext context) {
    final mapCamera = MapCamera.of(context);
    final mapController = MapController.of(context);

    var newCenter = mapCamera.offsetToCrs(details.localPosition);
    mapController.move(newCenter, mapCamera.zoom + 0.5);
  }
}