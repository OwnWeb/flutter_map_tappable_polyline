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

  TappablePolylineLayer({
    this.polylines = const [],
    this.onTap,
    this.onMiss,
    this.pointerDistanceTolerance = 15,
    polylineCulling = false,
    key,
  }) : super(key: key, polylines: polylines, polylineCulling: polylineCulling);

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
    final mapState = MapCamera.of(context);

    for (TaggedPolyline polyline in lines) {
      polyline._offsets.clear();
      var i = 0;
      for (var point in polyline.points) {
        var pos = mapState.project(point);
        pos = (pos * mapState.getZoomScale(mapState.zoom, mapState.zoom)) -
            mapState.pixelOrigin.toDoublePoint();
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
          _forwardCallToMapOptions(details, context);
          _handlePolylineTap(details, onTap, onMiss);
        },
        child: Stack(
          children: [
            CustomPaint(
              painter: PolylinePainter(lines, mapState),
              size: size,
            ),
          ],
        ),
      ),
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
    for (TaggedPolyline currentPolyline in polylines) {
      for (var j = 0; j < currentPolyline._offsets.length - 1; j++) {
        // We consider the points point1, point2 and tap points in a triangle
        var point1 = currentPolyline._offsets[j];
        var point2 = currentPolyline._offsets[j + 1];
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
          candidates[minimum]!.add(currentPolyline);
        }
      }
    }

    if (candidates.isEmpty) return onMiss?.call(details);

    // We look up in the map of distances to the tap, and choose the shortest one.
    var closestToTapKey = candidates.keys.reduce(min);
    onTap!(candidates[closestToTapKey], details);
  }

  void _forwardCallToMapOptions(TapUpDetails details, BuildContext context) {
    final latlng = _offsetToLatLng(details.localPosition, context.size!.width,
        context.size!.height, context);

    final mapOptions = MapOptions.of(context);

    final tapPosition =
        TapPosition(details.globalPosition, details.localPosition);

    // Forward the onTap call to map.options so that we won't break onTap
    mapOptions.onTap?.call(tapPosition, latlng);
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

    var newCenter = _offsetToLatLng(details.localPosition, context.size!.width,
        context.size!.height, context);
    mapController.move(newCenter, mapCamera.zoom + 0.5);
  }

  LatLng _offsetToLatLng(
      Offset offset, double width, double height, BuildContext context) {
    final mapCamera = MapCamera.of(context);

    var localPoint = Point(offset.dx, offset.dy);
    var localPointCenterDistance =
        Point((width / 2) - localPoint.x, (height / 2) - localPoint.y);
    var mapCenter = mapCamera.project(mapCamera.center);
    var point = mapCenter - localPointCenterDistance;
    return mapCamera.unproject(point);
  }
}
