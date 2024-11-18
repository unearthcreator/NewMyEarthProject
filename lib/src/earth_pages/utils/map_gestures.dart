// map_gestures.dart
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Applies general gesture settings to the provided MapboxMap instance.
void applyMapGestures(MapboxMap mapboxMap) {
  mapboxMap.gestures.updateSettings(
    GesturesSettings(
      pinchToZoomEnabled: true,
      quickZoomEnabled: true,
      scrollEnabled: true,
    ),
  );
}

/// Converts screen coordinates to map coordinates and triggers an action for adding an annotation.
Future<void> handleLongPress({
  required MapboxMap mapboxMap,
  required Function(Point mapPoint) onLongPressCallback,
  required LongPressStartDetails details,
}) async {
  final screenPoint = ScreenCoordinate(
    x: details.localPosition.dx,
    y: details.localPosition.dy,
  );
  final mapPoint = await mapboxMap.coordinateForPixel(screenPoint);
  onLongPressCallback(mapPoint);
}