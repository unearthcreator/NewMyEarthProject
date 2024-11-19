import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:map_mvp_project/services/error_handler.dart';

class MapAnnotationsManager {
  final PointAnnotationManager _annotationManager;
  final List<PointAnnotation> _annotations = [];
  
  MapAnnotationsManager(this._annotationManager);

  Future<PointAnnotation> addAnnotation(Point mapPoint) async {
    logger.i('Adding annotation at: ${mapPoint.coordinates.lat}, ${mapPoint.coordinates.lng}');
    final annotationOptions = PointAnnotationOptions(
      geometry: mapPoint,
      iconSize: 1.0,
      iconImage: "mapbox-check",
    );
    final annotation = await _annotationManager.create(annotationOptions);
    _annotations.add(annotation);
    return annotation;
  }

  Future<void> removeAnnotation(PointAnnotation annotation) async {
    await _annotationManager.delete(annotation);
    _annotations.remove(annotation);
  }

  Future<PointAnnotation?> findNearestAnnotation(Point tapPoint) async {
    double minDistance = double.infinity;
    PointAnnotation? nearest;
    
    for (var annotation in _annotations) {
      double distance = _calculateDistance(annotation.geometry, tapPoint);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = annotation;
      }
    }
    
    // Only return if we're within a reasonable distance
    return minDistance < 2.0 ? nearest : null;
  }

  double _calculateDistance(Point p1, Point p2) {
    double latDiff = (p1.coordinates.lat.toDouble() - p2.coordinates.lat.toDouble()).abs();
    double lngDiff = (p1.coordinates.lng.toDouble() - p2.coordinates.lng.toDouble()).abs();
    return latDiff + lngDiff;
  }

  String get annotationLayerId => _annotationManager.id;
  bool get hasAnnotations => _annotations.isNotEmpty;
  List<PointAnnotation> get annotations => List.unmodifiable(_annotations);
}