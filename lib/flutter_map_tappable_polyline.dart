library flutter_map_tappable_polyline;

import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong2/latlong.dart';
import 'package:positioned_tap_detector_2/positioned_tap_detector_2.dart';

/// A polyline with a tag
class TaggedPolyline extends Polyline {
  /// The name of the polyline
  final String? tag;

  TaggedPolyline(
      {required points,
      strokeWidth = 1.0,
      color = const Color(0xFF00FF00),
      borderStrokeWidth = 0.0,
      borderColor = const Color(0xFFFFFF00),
      gradientColors,
      colorsStop,
      isDotted = false,
      this.tag})
      : super(
            points: points,
            strokeWidth: strokeWidth,
            color: color,
            borderStrokeWidth: borderStrokeWidth,
            borderColor: borderColor,
            gradientColors: gradientColors,
            colorsStop: colorsStop,
            isDotted: isDotted);
}

class TappablePolylineLayer extends StatelessWidget {
  /// The list of [TaggedPolyline] to draw which could be tapped
  final List<TaggedPolyline> polylines;

  /// The tolerated distance between pointer and user tap to trigger the [onTap] callback
  /// Default to 10.0
  final double pointerDistanceTolerance;

  /// The callback to call when a polyline was hit by the tap
  final void Function(List<TaggedPolyline>, TapUpDetails tapPosition)? onTap;

  /// The optional callback to call when no polyline was hit by the tap
  final void Function(TapUpDetails tapPosition)? onMiss;

  /// The ability to render only polylines in current view bounds
  final bool polylineCulling;

  /// {@macro newPolylinePainter.saveLayers}
  ///
  /// By default, this value is set to `false` to improve performance on
  /// layers containing a lot of polylines.
  ///
  /// You might want to set this to `true` if you get unwanted darker lines
  /// where they overlap but, keep in mind that this might reduce the
  /// performance of the layer.
  final bool saveLayers;

  TappablePolylineLayer({
    Key? key,
    this.polylines = const [],
    this.pointerDistanceTolerance = 10.0,
    this.onTap,
    this.onMiss,
    this.polylineCulling = false,
    this.saveLayers = false,
  }) : super(key: key) {
    if (polylineCulling) {
      for (final polyline in polylines) {
        polyline.boundingBox = LatLngBounds.fromPoints(polyline.points);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints bc) {
        final size = Size(bc.maxWidth, bc.maxHeight);
        return _build(context, size, onTap, onMiss);
      },
    );
  }

  Widget _build(
      BuildContext context, Size size, Function? onTap, Function? onMiss) {
    final map = FlutterMapState.maybeOf(context)!;
    for (final polyline in polylines) {
      polyline.offsets.clear();

      if (polylineCulling && !polyline.boundingBox.isOverlapping(map.bounds)) {
        // Skip this polyline as it is not within the current map bounds (i.e not visible on screen)
        continue;
      }

      var i = 0;
      for (final point in polyline.points) {
        var pos = map.project(point);
        pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) -
            map.pixelOrigin;
        polyline.offsets.add(Offset(pos.x.toDouble(), pos.y.toDouble()));
        if (i > 0 && i < polyline.points.length) {
          polyline.offsets.add(Offset(pos.x.toDouble(), pos.y.toDouble()));
        }
        i++;
      }
    }

    return GestureDetector(
        onDoubleTap: () {
          // For some strange reason i have to add this callback for the onDoubleTapDown callback to be called.
        },
        onDoubleTapDown: (TapDownDetails details) {
          _zoomMap(details, context);
        },
        onTapUp: (TapUpDetails details) {
          _forwardCallToMapOptions(details, context);
          _handlePolylineTap(details, onTap, onMiss);
        },
        child: Stack(
          children: [
            for (final polyline in polylines)
              CustomPaint(
                painter: PolylinePainter(polyline, false),
                size: size,
              ),
          ],
        ));
  }

  void _handlePolylineTap(
      TapUpDetails details, Function? onTap, Function? onMiss) {
    // We might hit close to multiple polylines. We will therefore keep a reference to these in this map.
    Map<double, List<TaggedPolyline>> candidates = {};

    // Calculating taps in between points on the polyline. We
    // iterate over all the segments in the polyline to find any
    // matches with the tapped point within the
    // pointerDistanceTolerance.
    for (Polyline currentPolyline in polylines) {
      for (var j = 0; j < currentPolyline.offsets.length - 1; j++) {
        // We consider the points point1, point2 and tap points in a triangle
        var point1 = currentPolyline.offsets[j];
        var point2 = currentPolyline.offsets[j + 1];
        var tap = details.localPosition;

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
          candidates[minimum]!.add(currentPolyline as TaggedPolyline);
        }
      }
    }

    if (candidates.isNotEmpty) {
      // We look up in the map of distances to the tap, and choose the shortest one.
      var closestToTapKey = candidates.keys.reduce(min);
      onTap!(candidates[closestToTapKey], details);
    } else {
      if (onMiss is Function) {
        onMiss(details);
      }
    }
  }

  void _forwardCallToMapOptions(TapUpDetails details, BuildContext context) {
    final map = FlutterMapState.maybeOf(context)!;

    final latlng = _offsetToLatLng(
      offset: details.localPosition,
      width: context.size!.width,
      height: context.size!.height,
      map: map,
    );

    final tapPosition =
        TapPosition(details.globalPosition, details.localPosition);

    // Forward the onTap call to map.options so that we won't break onTap
    if (map.options.onTap != null) {
      map.options.onTap!(tapPosition, latlng);
    }
  }

  double _distance(Offset point1, Offset point2) {
    var distancex = (point1.dx - point2.dx).abs();
    var distancey = (point1.dy - point2.dy).abs();

    var distance = sqrt((distancex * distancex) + (distancey * distancey));

    return distance;
  }

  void _zoomMap(TapDownDetails details, BuildContext context) {
    final map = FlutterMapState.maybeOf(context)!;
    var newCenter = _offsetToLatLng(
      offset: details.localPosition,
      width: context.size!.width,
      height: context.size!.height,
      map: map,
    );
    map.move(newCenter, map.zoom + 0.5, source: MapEventSource.doubleTap);
  }

  LatLng _offsetToLatLng({
    required Offset offset,
    required double width,
    required double height,
    required FlutterMapState map,
  }) {
    var localPoint = CustomPoint(offset.dx, offset.dy);
    var localPointCenterDistance =
        CustomPoint((width / 2) - localPoint.x, (height / 2) - localPoint.y);
    var mapCenter = map.project(map.center);
    var point = mapCenter - localPointCenterDistance;
    return map.unproject(point);
  }
}
