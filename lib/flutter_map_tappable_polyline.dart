library flutter_map_tappable_polyline;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';

class TappablePolylineMapPlugin extends MapPlugin {
  bool supportsLayer(LayerOptions options) =>
      options is TappablePolylineLayerOptions;

  Widget createLayer(
      LayerOptions options, MapState mapState, Stream<Null> stream) {
    return TappablePolylineLayer(options, mapState, stream);
  }
}

class TappablePolylineLayerOptions extends LayerOptions {
  final List<TaggedPolyline> polylines;
  final double pointerDistanceTolerance;
  Function onTap = (TaggedPolyline polyline) {};

  TappablePolylineLayerOptions(
      {this.polylines = const [],
      rebuild,
      this.onTap,
      this.pointerDistanceTolerance = 15})
      : super(rebuild: rebuild);
}

class TaggedPolyline extends Polyline {
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
  final TappablePolylineLayerOptions polylineOpts;
  final MapState map;
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
                TaggedPolyline polyline = polylineOpts.polylines.firstWhere(
                    (TaggedPolyline polylineOpt) => polylineOpt.offsets.firstWhere(
                        (Offset offset) =>
                            (offset.dx / polylineOpts.pointerDistanceTolerance)
                                        .round()
                                        .toDouble() *
                                    polylineOpts.pointerDistanceTolerance ==
                                (details.localPosition.dx / polylineOpts.pointerDistanceTolerance)
                                        .round() *
                                    polylineOpts.pointerDistanceTolerance &&
                            (offset.dy / polylineOpts.pointerDistanceTolerance)
                                        .round()
                                        .toDouble() *
                                    polylineOpts.pointerDistanceTolerance ==
                                (details.localPosition.dy /
                                            polylineOpts.pointerDistanceTolerance)
                                        .round() *
                                    polylineOpts.pointerDistanceTolerance,
                        orElse: () => null) is Offset,
                    orElse: () => null);

                if (polyline is TaggedPolyline) onTap(polyline);
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
}
