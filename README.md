# Flutter Map Tappable Polyline

[![pub package](https://img.shields.io/pub/v/flutter_map_tappable_polyline.svg)](https://pub.dartlang.org/packages/flutter_map_tappable_polyline)

A Polyline with `onTap` event listener  
This is a plugin for [flutter_map](https://github.com/johnpryan/flutter_map) package

## Usage

Add [`flutter_map`](https://github.com/johnpryan/flutter_map) and `flutter_map_tappable_polyline` to your pubspec:

```yaml
dependencies:
  flutter_map: ^6.0.1
  flutter_map_tappable_polyline: any # take latest version on Pub
```

Add it in you FlutterMap and configure it using `TappablePolylineLayerOptions`.

```dart
  Widget build(BuildContext context) {
    return FlutterMap(
      options: new MapOptions(
        plugins: [
          TappablePolylineMapPlugin(),
        ],
      ),
      layers: [
        TileLayerOptions(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: ['a', 'b', 'c'],
        ),
        TappablePolylineLayerOptions(
          // Will only render visible polylines, increasing performance
          polylineCulling: true,
          polylines: [
            TaggedPolyline(
              tag: "My Polyline", // An optional tag to distinguish polylines in `onTap` callback
              // ...all other Polyline options
            ),
          ],
          onTap: (polylines, tapPosition) => print('Tapped: ' +
            polylines.map((polyline) => polyline.tag).join(',') +
            ' at ' +
            tapPosition.globalPosition.toString()),
          onMiss: (tapPosition) {
            print('No polyline was tapped at position ' +
                tapPosition.globalPosition.toString());
          }
        )
      ],
    );
  }
```
