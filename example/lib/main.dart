import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tappable_polyline/flutter_map_tappable_polyline.dart';
import 'package:latlong2/latlong.dart';

import 'data.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tappable Polyline Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Tappable Polyline Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String? title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title!),
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(45.1313258, 5.5171205),
          initialZoom: 11.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c'],
          ),
          TappablePolylineLayer(
              // Will only render visible polylines, increasing performance
              polylineCulling: true,
              pointerDistanceTolerance: 20,
              polylines: [
                TaggedPolyline(
                  tag: 'My Polyline',
                  // An optional tag to distinguish polylines in callback
                  points: getPoints(0),
                  color: Colors.red,
                  strokeWidth: 9.0,
                ),
                TaggedPolyline(
                  tag: 'My 2nd Polyline',
                  // An optional tag to distinguish polylines in callback
                  points: getPoints(1),
                  color: Colors.black,
                  strokeWidth: 3.0,
                ),
                TaggedPolyline(
                  tag: 'My 3rd Polyline',
                  // An optional tag to distinguish polylines in callback
                  points: getPoints(0),
                  color: Colors.blue,
                  strokeWidth: 3.0,
                ),
              ],
              onTap: (polylines, tapPosition) => print('Tapped: ' +
                  polylines.map((polyline) => polyline.tag).join(',') +
                  ' at ' +
                  tapPosition.globalPosition.toString()),
              onMiss: (tapPosition) {
                print('No polyline was tapped at position ' +
                    tapPosition.globalPosition.toString());
              })
        ],
      ),
    );
  }
}
