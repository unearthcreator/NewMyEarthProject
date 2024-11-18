// map_annotation_manager.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'map_config.dart';

/// Custom listener for handling long-press on annotations.
class CustomPointAnnotationClickListener implements OnPointAnnotationClickListener {
  final AnnotationManager annotationManager;

  CustomPointAnnotationClickListener(this.annotationManager);

  @override
  bool onPointAnnotationClick(PointAnnotation annotation) {
    annotationManager.handleAnnotationLongPress(annotation);
    return true;
  }
}

/// Manages annotations on a Mapbox map, including adding, clearing, and removing them with a long press.
class AnnotationManager {
  late PointAnnotationManager _annotationManager;

  /// Initializes the PointAnnotationManager and sets up a click listener for annotations.
  Future<void> initializeAnnotationManager(MapboxMap mapboxMap) async {
    _annotationManager = await mapboxMap.annotations.createPointAnnotationManager();

    // Set up a listener for annotation clicks
    _annotationManager.addOnPointAnnotationClickListener(
      CustomPointAnnotationClickListener(this),
    );
  }

  /// Adds an annotation at the specified geometry and returns the created annotation.
  Future<PointAnnotation> addAnnotation(Point geometry) async {
    final annotation = await _annotationManager.create(
      MapConfig.getDefaultAnnotationOptions(geometry),
    );
    return annotation;
  }

  /// Handles a long press on an annotation and removes it after 1 second.
  void handleAnnotationLongPress(PointAnnotation annotation) {
    Timer(const Duration(seconds: 1), () {
      _annotationManager.delete(annotation);  // Directly removes the annotation
    });
  }

  /// Clears all annotations from the map.
  Future<void> clearAnnotations() async {
    await _annotationManager.deleteAll();
  }
}