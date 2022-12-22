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

class TappablePolylineLayer extends PolylineLayer {
  /// The list of [TaggedPolyline] which could be tapped
  @override
  final List<TaggedPolyline> polylines;

  /// The tolerated distance between pointer and user tap to trigger the [onTap] callback
  final double pointerDistanceTolerance;

  /// The callback to call when a polyline was hit by the tap
  final void Function(List<TaggedPolyline>, TapUpDetails tapPosition)? onTap;

  /// The optional callback to call when no polyline was hit by the tap
  final void Function(TapUpDetails tapPosition)? onMiss;

  /// The ability to render only polylines in current view bounds
  @override
  final bool polylineCulling;

  TappablePolylineLayer(
      {this.polylines = const [],
        this.onTap,
        this.onMiss,
        this.pointerDistanceTolerance = 15,
        this.polylineCulling = false,
        Key? key})
      : super(polylineCulling: polylineCulling, key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints bc) {
        final size = Size(bc.maxWidth, bc.maxHeight);
        return _build(context, size);
      },
    );
  }

  Widget _build(
      BuildContext context, Size size) {
    FlutterMapState mapState = FlutterMapState.maybeOf(context)!;

    for (var polyline in polylines) {
      polyline.offsets.clear();

      if (polylineCulling &&
          !polyline.boundingBox.isOverlapping(mapState.bounds)) {
        // Skip this polyline as it is not within the current map bounds (i.e not visible on screen)
        continue;
      }

      var i = 0;
      for (var point in polyline.points) {
        var pos = mapState.project(point);
        pos = pos.multiplyBy(mapState.getZoomScale(mapState.zoom, mapState.zoom)) -
            mapState.pixelOrigin;
        polyline.offsets.add(Offset(pos.x.toDouble(), pos.y.toDouble()));
        if (i > 0 && i < polyline.points.length) {
          polyline.offsets
              .add(Offset(pos.x.toDouble(), pos.y.toDouble()));
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
            _zoomMap(details, context, mapState);
          },
          onTapUp: (TapUpDetails details) {
            _forwardCallToMapOptions(details, context, mapState);
            _handlePolylineTap(details, onTap, onMiss);
          },
          child: Stack(
            children: [
              for (final polyline in polylines)
                CustomPaint(
                  painter: PolylinePainter(polyline, false, mapState),
                  size: size,
                ),
            ],
          )),
    );
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

  void _forwardCallToMapOptions(TapUpDetails details, BuildContext context, FlutterMapState mapState) {
    final latlng = _offsetToLatLng(
        details.localPosition, context.size!.width, context.size!.height, mapState);

    final tapPosition =
        TapPosition(details.globalPosition, details.localPosition);

    // Forward the onTap call to map.options so that we won't break onTap
    if (mapState.options.onTap != null) {
      mapState.options.onTap!(tapPosition, latlng);
    }
  }

  // Todo: Remove this method is v2
  @Deprecated('Distance method should no longer be part of public API')
  double distance(Offset point1, Offset point2) {
    return _distance(point1, point2);
  }

  double _distance(Offset point1, Offset point2) {
    var distancex = (point1.dx - point2.dx).abs();
    var distancey = (point1.dy - point2.dy).abs();

    var distance = sqrt((distancex * distancex) + (distancey * distancey));

    return distance;
  }

  void _zoomMap(TapDownDetails details, BuildContext context, FlutterMapState mapState) {
    var newCenter = _offsetToLatLng(
        details.localPosition, context.size!.width, context.size!.height, mapState);
    mapState.move(newCenter, mapState.zoom + 0.5, source: MapEventSource.doubleTap);
  }

  LatLng _offsetToLatLng(Offset offset, double width, double height, FlutterMapState mapState) {
    var localPoint = CustomPoint(offset.dx, offset.dy);
    var localPointCenterDistance =
        CustomPoint((width / 2) - localPoint.x, (height / 2) - localPoint.y);
    var mapCenter = mapState.project(mapState.center);
    var point = mapCenter - localPointCenterDistance;
    return mapState.unproject(point);
  }
}
