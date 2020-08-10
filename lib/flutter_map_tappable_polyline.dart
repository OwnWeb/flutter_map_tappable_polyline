library flutter_map_tappable_polyline;

import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';

class TappablePolylineMapPlugin extends MapPlugin {
  @override
  bool supportsLayer(LayerOptions options) =>
      options is TappablePolylineLayerOptions;

  @override
  Widget createLayer(
      LayerOptions options, MapState mapState, Stream<Null> stream) {
    return TappablePolylineLayer(options, mapState, stream);
  }
}

/// The options allowing tappable polyline tweaks
class TappablePolylineLayerOptions extends PolylineLayerOptions {
  /// The list of [TaggedPolyline] which could be tapped
  @override
  final List<TaggedPolyline> polylines;

  /// The tolerated distance between pointer and user tap to trigger the [onTap] callback
  final double pointerDistanceTolerance;

  /// The callback to call when tapping the polyline
  Function onTap = (TaggedPolyline polyline) {};

  /// The ability to render only polylines in current view bounds
  @override
  final bool polylineCulling;

  TappablePolylineLayerOptions(
      {this.polylines = const [],
      rebuild,
      this.onTap,
      this.pointerDistanceTolerance = 15,
      this.polylineCulling = false})
      : super(rebuild: rebuild, polylineCulling: polylineCulling);
}

/// A polyline with a tag
class TaggedPolyline extends Polyline {
  /// The name of the polyline
  final String tag;

  TaggedPolyline(
      {points,
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
  /// The options allowing tappable polyline tweaks
  final TappablePolylineLayerOptions polylineOpts;

  /// The flutter_map [MapState]
  final MapState map;

  /// The Stream used by flutter_map to notify us when a redraw is required
  final Stream<Null> stream;

  TappablePolylineLayer(this.polylineOpts, this.map, this.stream);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints bc) {
        final size = Size(bc.maxWidth, bc.maxHeight);
        return _build(context, size, polylineOpts.onTap);
      },
    );
  }

  Widget _build(BuildContext context, Size size, Function onTap) {
    return StreamBuilder<void>(
      stream: stream, // a Stream<void> or null
      builder: (BuildContext context, _) {
        for (var polylineOpt in polylineOpts.polylines) {
          polylineOpt.offsets.clear();

          if (polylineOpts.polylineCulling &&
              !polylineOpt.boundingBox.isOverlapping(map.bounds)) {
            // Skip this polyline as it is not within the current map bounds (i.e not visible on screen)
            continue;
          }

          var i = 0;
          for (var point in polylineOpt.points) {
            var pos = map.project(point);
            pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) -
                map.getPixelOrigin();
            polylineOpt.offsets.add(Offset(pos.x.toDouble(), pos.y.toDouble()));
            if (i > 0 && i < polylineOpt.points.length) {
              polylineOpt.offsets
                  .add(Offset(pos.x.toDouble(), pos.y.toDouble()));
            }
            i++;
          }
        }

        return Container(
          child: GestureDetector(
              onTapUp: (TapUpDetails details) {
                // Calculating taps in between points on the polyline. We
                // iterate over all the segments in the polyline to find any
                // matches with the tapped point within t he
                // pointerDistanceTolerance.
                polylineOpts.polylines.forEach((element) {
                  for (var j = 0; j < element.offsets.length - 1; j++) {
                    // We consider the points point1, point2 and tap points in a triangle
                    var point1 = element.offsets[j];
                    var point2 = element.offsets[j + 1];
                    var tap = details.localPosition;

                    // To determine if we have tapped in between two po ints, we
                    // calculate the length from the tapped point to the line
                    // created by point1, point2. If this distance is shorter
                    // than the specified threshold, we have detected a tap
                    // between two points.
                    //
                    // We start by calculating the length of all the sides using pythagoras.
                    var a = distance(point1, point2);
                    var b = distance(point1, tap);
                    var c = distance(point2, tap);

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
                    var newTriangleBase =
                        sqrt((hypotenus * hypotenus) - (height * height));
                    var lengthDToOriginalSegment = newTriangleBase - a;

                    if (height < polylineOpts.pointerDistanceTolerance &&
                        lengthDToOriginalSegment <
                            polylineOpts.pointerDistanceTolerance) {
                      onTap(element);
                      return;
                    }
                  }
                });
              },
              child: Stack(
                children: [
                  for (final polylineOpt in polylineOpts.polylines)
                    CustomPaint(
                      painter: PolylinePainter(polylineOpt),
                      size: size,
                    ),
                ],
              )),
        );
      },
    );
  }

  double distance(Offset point1, Offset point2) {
    var distancex = (point1.dx - point2.dx).abs();
    var distancey = (point1.dy - point2.dy).abs();

    var distance = sqrt((distancex * distancex) + (distancey * distancey));

    return distance;
  }
}
