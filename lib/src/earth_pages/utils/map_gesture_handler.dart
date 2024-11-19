import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:map_mvp_project/services/error_handler.dart';
import 'package:map_mvp_project/src/earth_pages/utils/map_dialog_handler.dart';
import 'package:map_mvp_project/src/earth_pages/utils/map_annotations_manager.dart';

class MapGestureHandler {
  final MapboxMap mapboxMap;
  final MapAnnotationsManager annotationsManager;
  final BuildContext context;

  Timer? _longPressTimer;
  Timer? _placementDialogTimer;
  Point? _longPressPoint;
  bool _isOnExistingAnnotation = false;
  PointAnnotation? _selectedAnnotation;
  PointAnnotation? _lastPlacedAnnotation;

  MapGestureHandler({
    required this.mapboxMap,
    required this.annotationsManager,
    required this.context,
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
        final newAnnotation = await annotationsManager.addAnnotation(_longPressPoint!);
        logger.i('New annotation created at: ${newAnnotation.geometry.coordinates.lat}, ${newAnnotation.geometry.coordinates.lng}');
        _lastPlacedAnnotation = newAnnotation;
        _startPlacementDialogTimer();
      } else if (_isOnExistingAnnotation && _longPressPoint != null) {
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

  Future<void> _removeAnnotation(PointAnnotation annotation) async {
    logger.i('Starting annotation removal process');
    try {
      logger.i('Attempting to remove annotation at: ${annotation.geometry.coordinates.lat}, ${annotation.geometry.coordinates.lng}');
      await annotationsManager.removeAnnotation(annotation);
      logger.i('Annotation removal successful');
    } catch (e) {
      logger.e('Failed to remove annotation: $e');
      throw e;
    }
  }

  void _startPlacementDialogTimer() {
    _placementDialogTimer?.cancel();
    logger.i('Starting placement dialog timer');
    
    _placementDialogTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        logger.i('Placement timer triggered');
        final currentAnnotation = _lastPlacedAnnotation;
        
        if (currentAnnotation == null) {
          logger.w('No annotation found to confirm');
          return;
        }

        logger.i('Current annotation coordinates: ${currentAnnotation.geometry.coordinates.lat}, ${currentAnnotation.geometry.coordinates.lng}');
        final shouldKeepAnnotation = await MapDialogHandler.showNewAnnotationDialog(context);
        logger.i('Dialog result - should keep annotation: $shouldKeepAnnotation');

        if (!shouldKeepAnnotation) {
          logger.i('User chose not to keep annotation - initiating removal');
          await _removeAnnotation(currentAnnotation);
        } else {
          logger.i('Annotation will be kept');
        }
      } catch (e) {
        logger.e('Error in placement dialog timer: $e');
      } finally {
        _lastPlacedAnnotation = null;
      }
    });
  }

  void _startLongPressTimer() {
    _longPressTimer?.cancel();
    logger.i('Starting long press timer for removal');
    
    _longPressTimer = Timer(const Duration(seconds: 1), () async {
      logger.i('Timer completed');
      final annotationToRemove = _selectedAnnotation;
      if (annotationToRemove != null) {
        logger.i('Showing removal confirmation dialog');
        final shouldRemove = await MapDialogHandler.showRemoveAnnotationDialog(context);
        
        if (shouldRemove) {
          logger.i('User confirmed removal - initiating removal process');
          await _removeAnnotation(annotationToRemove);
        } else {
          logger.i('User cancelled removal');
        }
      }
      _selectedAnnotation = null;
    });
  }

  void cancelTimer() {
    logger.i('Cancelling timers');
    _longPressTimer?.cancel();
    _placementDialogTimer?.cancel();
    _longPressTimer = null;
    _placementDialogTimer = null;
    _longPressPoint = null;
    _selectedAnnotation = null;
    _lastPlacedAnnotation = null;
    _isOnExistingAnnotation = false;
  }

  void dispose() {
    cancelTimer();
  }
}