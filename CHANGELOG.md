## 6.0.0 - 2023-10-31 🎃
- **[BREAKING]** Upgrade `flutter_map` to `^6.0.0`.

## 5.0.0 - 2023-06-05
- **[BREAKING]** Upgrade `flutter_map` to `^5.0.0`. *Thanks [@azaderdogan](https://github.com/azaderdogan) and [@JaffaKetchup](https://github.com/JaffaKetchup) 👏*

## 4.0.0+1 - 2023-04-13
- Fixed flutter_map version in README

## 4.0.0 - 2023-04-13
- **[BREAKING]** Upgrade `flutter_map` to 3.1.0. *Thanks [@jtthrillson](https://github.com/jtthrillson) 👏*
- Fixed example app android embedding. *Thanks [@k5924](https://github.com/k5924)*

## 3.2.0
- Upgrade `flutter_map` to 1.0.0

## 3.1.0
- Upgrade `flutter_map` to 0.14.0

## 3.0.0
- [BREAKING] Add support for overlapping lines (see [#31](https://github.com/OwnWeb/flutter_map_tappable_polyline/pull/31)), thanks [@FaFre](https://github.com/FaFre)
    - The `onTap` callback is now called with a list of `TaggedPolyline` instead of one
- [BREAKING] Add tap position to onTap and onMiss callbacks
    - The `onTap` and `onMiss` callbacks now receive the position of the tap that (`TapUpDetails`)
- Add LayerWidget (see [#31](https://github.com/OwnWeb/flutter_map_tappable_polyline/pull/31)), [@S-Man42](https://github.com/S-Man42)

## 2.0.0

- Null safety (see [#27](https://github.com/OwnWeb/flutter_map_tappable_polyline/pull/27/files), thanks [@sbu](https://github.com/sbu-WBT)!)
- Upgrade `flutter_map` to 0.13.1

## 1.3.1

- Upgrade flutter map

## 1.3.0+1

- Fix changelog deprecation notice about `TappablePolylineLayer.distance`

## 1.3.0

- Update `flutter_map` dependency to 1.11.0 (see issue [#23](https://github.com/OwnWeb/flutter_map_tappable_polyline/issues/23), thanks [@S-Man42](https://github.com/S-Man42))
- Fix null pointer error when no onMiss callback was passed (see issue [#20](https://github.com/OwnWeb/flutter_map_tappable_polyline/issues/20))

## 1.2.0

 - Trigger only one `onTap` event when multiple polylines are close to each other (#14, #18) @MKohm
 - *Deprecated*: `TappablePolylineLayer.distance` should no longer be part of public API and is now deprecated 

## 1.1.1

 - Add missing latlong dependency @tuarrep

## 1.1.0

 - Center the map on the tap location when zooming (#17) @Mkohm

## 1.0.0

 - Allow zooming underlying map with double tap (#12) @Mkohm
 - Add `onMiss` callback when tap missed polyline (#12) @Mkohm

## 0.5.0

 - Detect tapping between polyline points (#8) @Mkohm

## 0.4.0

 - Add support for Polyline culling (#5) @Mkohm

## 0.3.3

 - Upgrade flutter_map to ^0.10.1

 ## 0.3.2
 
 - Upgrade flutter_map to ^0.9.0

## 0.3.1

 - Add example
 - Format code

## 0.3.0

 - Fix onTap callback

## 0.2.0

 - Better gesture handling to allow double tap on underlying map

## 0.1.0

 - Initial release
