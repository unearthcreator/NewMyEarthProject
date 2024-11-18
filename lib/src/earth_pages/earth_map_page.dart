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

  Future<void> _onMapTap(ScreenCoordinate screenPoint) async {
    try {
      final features = await _mapboxMap.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screenPoint),
        RenderedQueryOptions(layerIds: [_annotationManager.id]),
      );
      
      _longPressPoint = await _mapboxMap.coordinateForPixel(screenPoint);
      _isOnExistingAnnotation = features.isNotEmpty;

      if (!_isOnExistingAnnotation && _longPressPoint != null) {
        // Only add new annotation if not on existing one
        logger.i('No annotation at tap location. Adding new annotation.');
        PointAnnotation newAnnotation = await _addAnnotation(_longPressPoint!);
        _annotations.add(newAnnotation);
      }
    } catch (e) {
      logger.e('Error during feature query: $e');
    }
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
    _longPressTimer?.cancel();  // Cancel any existing timer
    
    if (_isOnExistingAnnotation) {
      // Start 1-second timer for removal only if on existing annotation
      _longPressTimer = Timer(const Duration(seconds: 1), () async {
        if (_longPressPoint != null && _annotations.isNotEmpty) {
          for (var annotation in _annotations) {
            if (_isPointNearAnnotation(annotation.geometry, _longPressPoint!)) {
              logger.i('Removing annotation after long press');
              await _annotationManager.delete(annotation);
              _annotations.remove(annotation);
              break;
            }
          }
        }
      });
    }
  }

  bool _isPointNearAnnotation(Point annotationPoint, Point tapPoint) {
    const double threshold = 0.0001;
    return (annotationPoint.coordinates.lat - tapPoint.coordinates.lat).abs() < threshold &&
           (annotationPoint.coordinates.lng - tapPoint.coordinates.lng).abs() < threshold;
  }

  void _cancelLongPressTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _longPressPoint = null;
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
        final screenPoint = ScreenCoordinate(
          x: details.localPosition.dx,
          y: details.localPosition.dy,
        );
        _onMapTap(screenPoint);
        _startLongPressTimer();
      },
      onLongPressEnd: (LongPressEndDetails details) {
        _cancelLongPressTimer();
      },
      onLongPressCancel: () {
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