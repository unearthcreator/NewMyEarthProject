import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:map_mvp_project/services/error_handler.dart';
import 'package:map_mvp_project/src/earth_pages/utils/map_annotations_manager.dart';

class MapGestureHandler {
  final MapboxMap mapboxMap;
  final MapAnnotationsManager annotationsManager;

  Timer? _longPressTimer;
  Point? _longPressPoint;
  bool _isOnExistingAnnotation = false;
  PointAnnotation? _selectedAnnotation;

  MapGestureHandler({
    required this.mapboxMap,
    required this.annotationsManager,
  });

  Future<void> handleLongPress(ScreenCoordinate screenPoint) async {
    try {
      final features = await mapboxMap.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screenPoint),
        RenderedQueryOptions(layerIds: [annotationsManager.annotationLayerId]),
      );
      
      logger.i('Features found: ${features.length}');
      
      _longPressPoint = await mapboxMap.coordinateForPixel(screenPoint);
      _isOnExistingAnnotation = features.isNotEmpty;
      
      logger.i('Is on existing annotation: $_isOnExistingAnnotation');

      if (!_isOnExistingAnnotation && _longPressPoint != null) {
        logger.i('No annotation at tap location. Adding new annotation.');
        await annotationsManager.addAnnotation(_longPressPoint!);
      } else if (_isOnExistingAnnotation && _longPressPoint != null) {
        // Find the annotation that was clicked
        _selectedAnnotation = await annotationsManager.findNearestAnnotation(_longPressPoint!);
        if (_selectedAnnotation != null) {
          logger.i('Found annotation to remove - starting timer');
          _startLongPressTimer();
        }
      }
    } catch (e) {
      logger.e('Error during feature query: $e');
    }
  }

  void _startLongPressTimer() {
    _longPressTimer?.cancel();
    logger.i('Starting long press timer for removal');
    
    _longPressTimer = Timer(const Duration(seconds: 1), () async {
      logger.i('Timer completed');
      if (_selectedAnnotation != null) {
        logger.i('Removing selected annotation');
        await annotationsManager.removeAnnotation(_selectedAnnotation!);
        _selectedAnnotation = null;
      }
    });
  }

  void cancelTimer() {
    logger.i('Cancelling timer');
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _longPressPoint = null;
    _selectedAnnotation = null;
    _isOnExistingAnnotation = false;
  }

  void dispose() {
    cancelTimer();
  }
}