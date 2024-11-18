import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:map_mvp_project/src/earth_pages/utils/map_config.dart';
import 'package:map_mvp_project/services/error_handler.dart';

class EarthMapPage extends StatefulWidget {
  const EarthMapPage({super.key});
  @override
  EarthMapPageState createState() => EarthMapPageState();
}

class EarthMapPageState extends State<EarthMapPage> {
  late MapboxMap _mapboxMap;
  bool _isMapReady = false;
  late PointAnnotationManager _annotationManager;
  Timer? _longPressTimer;
  Point? _longPressPoint;
  List<PointAnnotation> _annotations = [];
  bool _isOnExistingAnnotation = false;
  PointAnnotation? _selectedAnnotation;

  @override
  void initState() {
    super.initState();
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    logger.i('Map created.');
    _annotationManager = await mapboxMap.annotations.createPointAnnotationManager();
    setState(() {
      _isMapReady = true;
    });
  }

  Future<void> _handleLongPress(ScreenCoordinate screenPoint) async {
    try {
      final features = await _mapboxMap.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screenPoint),
        RenderedQueryOptions(layerIds: [_annotationManager.id]),
      );
      
      logger.i('Features found: ${features.length}');
      
      _longPressPoint = await _mapboxMap.coordinateForPixel(screenPoint);
      _isOnExistingAnnotation = features.isNotEmpty;
      
      logger.i('Is on existing annotation: $_isOnExistingAnnotation');

      if (!_isOnExistingAnnotation && _longPressPoint != null) {
        logger.i('No annotation at tap location. Adding new annotation.');
        PointAnnotation newAnnotation = await _addAnnotation(_longPressPoint!);
        _annotations.add(newAnnotation);
        logger.i('Current annotations count: ${_annotations.length}');
      } else if (_isOnExistingAnnotation && _longPressPoint != null) {
        // Find the annotation that was clicked
        _selectedAnnotation = await _findNearestAnnotation(_longPressPoint!);
        if (_selectedAnnotation != null) {
          logger.i('Found annotation to remove - starting timer');
          _startLongPressTimer();
        }
      }
    } catch (e) {
      logger.e('Error during feature query: $e');
    }
  }

  Future<PointAnnotation?> _findNearestAnnotation(Point tapPoint) async {
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
    return latDiff + lngDiff; // Manhattan distance, simpler than Haversine
  }

  Future<PointAnnotation> _addAnnotation(Point mapPoint) async {
    logger.i('Adding annotation at: ${mapPoint.coordinates.lat}, ${mapPoint.coordinates.lng}');
    final annotationOptions = PointAnnotationOptions(
      geometry: mapPoint,
      iconSize: 1.0,
      iconImage: "mapbox-check",
    );
    return await _annotationManager.create(annotationOptions);
  }

  void _startLongPressTimer() {
    _longPressTimer?.cancel();
    logger.i('Starting long press timer for removal');
    
    _longPressTimer = Timer(const Duration(seconds: 1), () async {
      logger.i('Timer completed');
      if (_selectedAnnotation != null) {
        logger.i('Removing selected annotation');
        await _annotationManager.delete(_selectedAnnotation!);
        _annotations.remove(_selectedAnnotation);
        _selectedAnnotation = null;
      }
    });
  }

  void _cancelLongPressTimer() {
    logger.i('Cancelling timer');
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _longPressPoint = null;
    _selectedAnnotation = null;
    _isOnExistingAnnotation = false;
  }

  @override
  void dispose() {
    _cancelLongPressTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (LongPressStartDetails details) {
        logger.i('Long press started');
        final screenPoint = ScreenCoordinate(
          x: details.localPosition.dx,
          y: details.localPosition.dy,
        );
        _handleLongPress(screenPoint);
      },
      onLongPressEnd: (LongPressEndDetails details) {
        logger.i('Long press ended');
        _cancelLongPressTimer();
      },
      onLongPressCancel: () {
        logger.i('Long press cancelled');
        _cancelLongPressTimer();
      },
      child: Scaffold(
        body: Stack(
          children: [
            MapWidget(
              cameraOptions: MapConfig.defaultCameraOptions,
              styleUri: MapConfig.styleUri,
              onMapCreated: _onMapCreated,
            ),
            if (_isMapReady)
              Positioned(
                top: 40,
                left: 10,
                child: BackButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}