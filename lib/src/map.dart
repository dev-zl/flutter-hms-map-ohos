/*
    Copyright 2020-2024. Huawei Technologies Co., Ltd. All rights reserved.

    Licensed under the Apache License, Version 2.0 (the "License")
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        https://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

part of '../huawei_map_ohos.dart';

class HuaweiMapController {
  final int mapId;

  HuaweiMapController._(
    CameraPosition initialCameraPosition,
    this._huaweiMapState, {
    required this.mapId,
  }) {
    _connectStreams(mapId);
  }

  static Future<HuaweiMapController> init(
    int id,
    CameraPosition initialCameraPosition,
    _HuaweiMapState huaweiMapState,
  ) async {
    await _HuaweiMapMethodChannel.init(id);
    return HuaweiMapController._(
      initialCameraPosition,
      huaweiMapState,
      mapId: id,
    );
  }

  final _HuaweiMapState _huaweiMapState;

  final Map<MarkerId, Marker> _commandMarkers = <MarkerId, Marker>{};
  final Map<PolylineId, Polyline> _commandPolylines = <PolylineId, Polyline>{};
  final Map<PolygonId, Polygon> _commandPolygons = <PolygonId, Polygon>{};
  final Map<CircleId, Circle> _commandCircles = <CircleId, Circle>{};
  final Map<GroundOverlayId, GroundOverlay> _commandGroundOverlays =
      <GroundOverlayId, GroundOverlay>{};

  void _connectStreams(int mapId) {
    _HuaweiMapMethodChannel.onMarkerClick(mapId: mapId).listen(
      (MarkerClickEvent e) {
        _commandMarkers[e.value]?.onClick?.call();
      },
    );
    _HuaweiMapMethodChannel.onMarkerDragEnd(mapId: mapId).listen(
      (MarkerDragEndEvent e) {
        _commandMarkers[e.value]?.onDragEnd?.call(e.position);
      },
    );
    _HuaweiMapMethodChannel.onMarkerDragStart(mapId: mapId).listen(
      (MarkerDragStartEvent e) {
        _commandMarkers[e.value]?.onDragStart?.call(e.position);
      },
    );
    _HuaweiMapMethodChannel.onMarkerDrag(mapId: mapId).listen(
      (MarkerDragEvent e) {
        _commandMarkers[e.value]?.onDrag?.call(e.position);
      },
    );
    _HuaweiMapMethodChannel.onInfoWindowClick(mapId: mapId).listen(
      (InfoWindowClickEvent e) {
        _commandMarkers[e.value]?.infoWindow.onClick?.call();
      },
    );
    _HuaweiMapMethodChannel.onInfoWindowLongClick(mapId: mapId).listen(
      (InfoWindowLongClickEvent e) {
        _commandMarkers[e.value]?.infoWindow.onLongClick?.call();
      },
    );
    _HuaweiMapMethodChannel.onInfoWindowClose(mapId: mapId).listen(
      (InfoWindowCloseEvent e) {
        _commandMarkers[e.value]?.infoWindow.onClose?.call();
      },
    );
    _HuaweiMapMethodChannel.onPolylineClick(mapId: mapId).listen(
      (PolylineClickEvent e) {
        _commandPolylines[e.value]?.onClick?.call();
      },
    );
    _HuaweiMapMethodChannel.onPolygonClick(mapId: mapId).listen(
      (PolygonClickEvent e) {
        _commandPolygons[e.value]?.onClick?.call();
      },
    );
    _HuaweiMapMethodChannel.onCircleClick(mapId: mapId).listen(
      (CircleClickEvent e) {
        _commandCircles[e.value]?.onClick?.call();
      },
    );
    _HuaweiMapMethodChannel.onClick(mapId: mapId)
        .listen((MapClickEvent e) => _huaweiMapState.onClick(e.position));
    _HuaweiMapMethodChannel.onLongPress(mapId: mapId).listen(
      (MapLongPressEvent e) => _huaweiMapState.onLongPress(e.position),
    );
    _HuaweiMapMethodChannel.onDrawStart(mapId: mapId).listen(
      (MapDrawStartEvent e) => _huaweiMapState.onDrawStart(e.position),
    );
    _HuaweiMapMethodChannel.onDrawUpdate(mapId: mapId).listen(
      (MapDrawUpdateEvent e) => _huaweiMapState.onDrawUpdate(e.position),
    );
    _HuaweiMapMethodChannel.onDrawEnd(mapId: mapId).listen(
      (MapDrawEndEvent e) => _huaweiMapState.onDrawEnd(e.value!),
    );
    _HuaweiMapMethodChannel.onPoiClick(mapId: mapId).listen(
      (PoiClickEvent e) => _huaweiMapState.onPoiClick(e.pointOfInterest),
    );
    _HuaweiMapMethodChannel.onMyLocationClick(mapId: mapId).listen(
      (LocationClickEvent e) => _huaweiMapState.onMyLocationClick(e.location),
    );
    _HuaweiMapMethodChannel.onMyLocationButtonClick(mapId: mapId).listen(
      (LocationButtonClickEvent e) =>
          _huaweiMapState.onMyLocationButtonClick(e.onMyLocationButtonClicked),
    );
    _HuaweiMapMethodChannel.onGroundOverlayClick(mapId: mapId).listen(
      (GroundOverlayClickEvent e) {
        _commandGroundOverlays[e.value]?.onClick?.call();
      },
    );
    if (_huaweiMapState.widget.onCameraMoveStarted != null) {
      _HuaweiMapMethodChannel.onCameraMoveStarted(mapId: mapId).listen(
        (CameraMoveStartedEvent e) =>
            _huaweiMapState.widget.onCameraMoveStarted!(e.value!),
      );
    }
    if (_huaweiMapState.widget.onCameraMove != null) {
      _HuaweiMapMethodChannel.onCameraMove(mapId: mapId).listen(
        (CameraMoveEvent e) => _huaweiMapState.widget.onCameraMove!(e.value!),
      );
    }
    if (_huaweiMapState.widget.onCameraIdle != null) {
      _HuaweiMapMethodChannel.onCameraIdle(mapId: mapId)
          .listen((_) => _huaweiMapState.widget.onCameraIdle!());
    }
    if (_huaweiMapState.widget.onCameraMoveCanceled != null) {
      _HuaweiMapMethodChannel.onCameraMoveCanceled(mapId: mapId)
          .listen((_) => _huaweiMapState.widget.onCameraMoveCanceled!());
    }
  }

  Future<void> _updateMapOptions(Map<String, dynamic> optionsUpdate) {
    return _HuaweiMapMethodChannel.updateMapOptions(
      optionsUpdate,
      mapId: mapId,
    );
  }

  Future<void> _updateMarkers(MarkerUpdates markerUpdates) {
    return _HuaweiMapMethodChannel.updateMarkers(markerUpdates, mapId: mapId);
  }

  Future<void> _updatePolygons(PolygonUpdates polygonUpdates) {
    return _HuaweiMapMethodChannel.updatePolygons(polygonUpdates, mapId: mapId);
  }

  Future<void> _updatePolylines(PolylineUpdates polylineUpdates) {
    return _HuaweiMapMethodChannel.updatePolylines(
      polylineUpdates,
      mapId: mapId,
    );
  }

  Future<void> _updateCircles(CircleUpdates circleUpdates) {
    return _HuaweiMapMethodChannel.updateCircles(circleUpdates, mapId: mapId);
  }

  Future<void> _updateGroundOverlays(
    GroundOverlayUpdates groundOverlayUpdates,
  ) {
    return _HuaweiMapMethodChannel.updateGroundOverlays(
      groundOverlayUpdates,
      mapId: mapId,
    );
  }

  Future<void> _updateTileOverlays(TileOverlayUpdates tileOverlayUpdates) {
    return _HuaweiMapMethodChannel.updateTileOverlays(
      tileOverlayUpdates,
      mapId: mapId,
    );
  }

  Future<void> _updateHeatMaps(HeatMapUpdates heatMapUpdates) {
    return _HuaweiMapMethodChannel.updateHeatMaps(heatMapUpdates, mapId: mapId);
  }

  /// Appends lightweight, non-interactive points without rebuilding [HuaweiMap].
  ///
  /// HarmonyOS uses Map Kit's native MassPointOverlay. Android keeps a bounded
  /// pool of native, fixed-size green markers for points in the current viewport.
  /// A positive [verticalOffset] moves every added point down by that many
  /// logical screen pixels.
  Future<void> addMassPoints(
    Iterable<MassPoint> massPoints, {
    double verticalOffset = 0,
  }) {
    assert(verticalOffset >= 0);
    final List<MassPoint> values = massPoints.toList(growable: false);
    if (values.isEmpty) {
      return Future<void>.value();
    }
    return _HuaweiMapMethodChannel.addMassPoints(
      values,
      mapId: mapId,
      verticalOffset: verticalOffset,
    );
  }

  /// Adds a marker without rebuilding [HuaweiMap].
  Future<void> addMarker(Marker marker) => addMarkers(<Marker>[marker]);

  /// Adds markers in one platform-channel call.
  Future<void> addMarkers(Iterable<Marker> markers) async {
    final Set<Marker> values = markers.toSet();
    if (values.isEmpty) {
      return;
    }
    await _updateMarkers(MarkerUpdates._command(inserts: values));
    for (final Marker marker in values) {
      _commandMarkers[marker.markerId] = marker;
    }
  }

  /// Updates a marker without rebuilding [HuaweiMap].
  Future<void> updateMarker(Marker marker) => updateMarkers(<Marker>[marker]);

  /// Updates markers in one platform-channel call.
  Future<void> updateMarkers(Iterable<Marker> markers) async {
    final Set<Marker> values = markers.toSet();
    if (values.isEmpty) {
      return;
    }
    await _updateMarkers(MarkerUpdates._command(updates: values));
    for (final Marker marker in values) {
      _commandMarkers[marker.markerId] = marker;
    }
  }

  /// Removes a marker without rebuilding [HuaweiMap].
  Future<void> removeMarker(MarkerId markerId) =>
      removeMarkers(<MarkerId>[markerId]);

  /// Removes markers in one platform-channel call.
  Future<void> removeMarkers(Iterable<MarkerId> markerIds) async {
    final Set<MarkerId> values = markerIds.toSet();
    if (values.isEmpty) {
      return;
    }
    await _updateMarkers(MarkerUpdates._command(deletes: values));
    for (final MarkerId markerId in values) {
      _commandMarkers.remove(markerId);
    }
  }

  /// Adds a polyline without rebuilding [HuaweiMap].
  Future<void> addPolyline(Polyline polyline) =>
      addPolylines(<Polyline>[polyline]);

  /// Adds polylines in one platform-channel call.
  Future<void> addPolylines(Iterable<Polyline> polylines) async {
    final Set<Polyline> values = polylines.toSet();
    if (values.isEmpty) {
      return;
    }
    await _updatePolylines(PolylineUpdates._command(inserts: values));
    for (final Polyline polyline in values) {
      _commandPolylines[polyline.polylineId] = polyline;
    }
  }

  /// Updates a polyline without rebuilding [HuaweiMap].
  Future<void> updatePolyline(Polyline polyline) =>
      updatePolylines(<Polyline>[polyline]);

  /// Updates polylines in one platform-channel call.
  Future<void> updatePolylines(Iterable<Polyline> polylines) async {
    final Set<Polyline> values = polylines.toSet();
    if (values.isEmpty) {
      return;
    }
    await _updatePolylines(PolylineUpdates._command(updates: values));
    for (final Polyline polyline in values) {
      _commandPolylines[polyline.polylineId] = polyline;
    }
  }

  /// Removes a polyline without rebuilding [HuaweiMap].
  Future<void> removePolyline(PolylineId polylineId) =>
      removePolylines(<PolylineId>[polylineId]);

  /// Removes polylines in one platform-channel call.
  Future<void> removePolylines(Iterable<PolylineId> polylineIds) async {
    final Set<PolylineId> values = polylineIds.toSet();
    if (values.isEmpty) {
      return;
    }
    await _updatePolylines(PolylineUpdates._command(deletes: values));
    for (final PolylineId polylineId in values) {
      _commandPolylines.remove(polylineId);
    }
  }

  /// Adds a polygon without rebuilding [HuaweiMap].
  Future<void> addPolygon(Polygon polygon) => addPolygons(<Polygon>[polygon]);

  /// Adds polygons in one platform-channel call.
  Future<void> addPolygons(Iterable<Polygon> polygons) async {
    final Set<Polygon> values = polygons.toSet();
    if (values.isEmpty) {
      return;
    }
    await _updatePolygons(PolygonUpdates._command(inserts: values));
    for (final Polygon polygon in values) {
      _commandPolygons[polygon.polygonId] = polygon;
    }
  }

  /// Updates a polygon without rebuilding [HuaweiMap].
  Future<void> updatePolygon(Polygon polygon) =>
      updatePolygons(<Polygon>[polygon]);

  /// Updates polygons in one platform-channel call.
  Future<void> updatePolygons(Iterable<Polygon> polygons) async {
    final Set<Polygon> values = polygons.toSet();
    if (values.isEmpty) {
      return;
    }
    await _updatePolygons(PolygonUpdates._command(updates: values));
    for (final Polygon polygon in values) {
      _commandPolygons[polygon.polygonId] = polygon;
    }
  }

  /// Removes a polygon without rebuilding [HuaweiMap].
  Future<void> removePolygon(PolygonId polygonId) =>
      removePolygons(<PolygonId>[polygonId]);

  /// Removes polygons in one platform-channel call.
  Future<void> removePolygons(Iterable<PolygonId> polygonIds) async {
    final Set<PolygonId> values = polygonIds.toSet();
    if (values.isEmpty) {
      return;
    }
    await _updatePolygons(PolygonUpdates._command(deletes: values));
    for (final PolygonId polygonId in values) {
      _commandPolygons.remove(polygonId);
    }
  }

  /// Adds a circle without rebuilding [HuaweiMap].
  Future<void> addCircle(Circle circle) => addCircles(<Circle>[circle]);

  /// Adds circles in one platform-channel call.
  Future<void> addCircles(Iterable<Circle> circles) async {
    final Set<Circle> values = circles.toSet();
    if (values.isEmpty) {
      return;
    }
    await _updateCircles(CircleUpdates._command(inserts: values));
    for (final Circle circle in values) {
      _commandCircles[circle.circleId] = circle;
    }
  }

  /// Updates a circle without rebuilding [HuaweiMap].
  Future<void> updateCircle(Circle circle) => updateCircles(<Circle>[circle]);

  /// Updates circles in one platform-channel call.
  Future<void> updateCircles(Iterable<Circle> circles) async {
    final Set<Circle> values = circles.toSet();
    if (values.isEmpty) {
      return;
    }
    await _updateCircles(CircleUpdates._command(updates: values));
    for (final Circle circle in values) {
      _commandCircles[circle.circleId] = circle;
    }
  }

  /// Removes a circle without rebuilding [HuaweiMap].
  Future<void> removeCircle(CircleId circleId) =>
      removeCircles(<CircleId>[circleId]);

  /// Removes circles in one platform-channel call.
  Future<void> removeCircles(Iterable<CircleId> circleIds) async {
    final Set<CircleId> values = circleIds.toSet();
    if (values.isEmpty) {
      return;
    }
    await _updateCircles(CircleUpdates._command(deletes: values));
    for (final CircleId circleId in values) {
      _commandCircles.remove(circleId);
    }
  }

  /// Adds a ground overlay without rebuilding [HuaweiMap].
  Future<void> addGroundOverlay(GroundOverlay groundOverlay) =>
      addGroundOverlays(<GroundOverlay>[groundOverlay]);

  /// Adds ground overlays in one platform-channel call.
  Future<void> addGroundOverlays(
    Iterable<GroundOverlay> groundOverlays,
  ) async {
    final Set<GroundOverlay> values = groundOverlays.toSet();
    if (values.isEmpty) {
      return;
    }
    await _updateGroundOverlays(
      GroundOverlayUpdates._command(inserts: values),
    );
    for (final GroundOverlay groundOverlay in values) {
      _commandGroundOverlays[groundOverlay.groundOverlayId] = groundOverlay;
    }
  }

  /// Updates a ground overlay without rebuilding [HuaweiMap].
  Future<void> updateGroundOverlay(GroundOverlay groundOverlay) =>
      updateGroundOverlays(<GroundOverlay>[groundOverlay]);

  /// Updates ground overlays in one platform-channel call.
  Future<void> updateGroundOverlays(
    Iterable<GroundOverlay> groundOverlays,
  ) async {
    final Set<GroundOverlay> values = groundOverlays.toSet();
    if (values.isEmpty) {
      return;
    }
    await _updateGroundOverlays(
      GroundOverlayUpdates._command(updates: values),
    );
    for (final GroundOverlay groundOverlay in values) {
      _commandGroundOverlays[groundOverlay.groundOverlayId] = groundOverlay;
    }
  }

  /// Removes a ground overlay without rebuilding [HuaweiMap].
  Future<void> removeGroundOverlay(GroundOverlayId groundOverlayId) =>
      removeGroundOverlays(<GroundOverlayId>[groundOverlayId]);

  /// Removes ground overlays in one platform-channel call.
  Future<void> removeGroundOverlays(
    Iterable<GroundOverlayId> groundOverlayIds,
  ) async {
    final Set<GroundOverlayId> values = groundOverlayIds.toSet();
    if (values.isEmpty) {
      return;
    }
    await _updateGroundOverlays(
      GroundOverlayUpdates._command(deletes: values),
    );
    for (final GroundOverlayId groundOverlayId in values) {
      _commandGroundOverlays.remove(groundOverlayId);
    }
  }

  /// Adds a tile overlay without rebuilding [HuaweiMap].
  Future<void> addTileOverlay(TileOverlay tileOverlay) =>
      addTileOverlays(<TileOverlay>[tileOverlay]);

  /// Adds tile overlays in one platform-channel call.
  Future<void> addTileOverlays(Iterable<TileOverlay> tileOverlays) {
    final Set<TileOverlay> values = tileOverlays.toSet();
    if (values.isEmpty) {
      return Future<void>.value();
    }
    return _updateTileOverlays(TileOverlayUpdates._command(inserts: values));
  }

  /// Updates a tile overlay without rebuilding [HuaweiMap].
  Future<void> updateTileOverlay(TileOverlay tileOverlay) =>
      updateTileOverlays(<TileOverlay>[tileOverlay]);

  /// Updates tile overlays in one platform-channel call.
  Future<void> updateTileOverlays(Iterable<TileOverlay> tileOverlays) {
    final Set<TileOverlay> values = tileOverlays.toSet();
    if (values.isEmpty) {
      return Future<void>.value();
    }
    return _updateTileOverlays(TileOverlayUpdates._command(updates: values));
  }

  /// Removes a tile overlay without rebuilding [HuaweiMap].
  Future<void> removeTileOverlay(TileOverlayId tileOverlayId) =>
      removeTileOverlays(<TileOverlayId>[tileOverlayId]);

  /// Removes tile overlays in one platform-channel call.
  Future<void> removeTileOverlays(Iterable<TileOverlayId> tileOverlayIds) {
    final Set<TileOverlayId> values = tileOverlayIds.toSet();
    if (values.isEmpty) {
      return Future<void>.value();
    }
    return _updateTileOverlays(TileOverlayUpdates._command(deletes: values));
  }

  /// Adds a heatmap without rebuilding [HuaweiMap].
  Future<void> addHeatMap(HeatMap heatMap) => addHeatMaps(<HeatMap>[heatMap]);

  /// Adds heatmaps in one platform-channel call.
  Future<void> addHeatMaps(Iterable<HeatMap> heatMaps) {
    final Set<HeatMap> values = heatMaps.toSet();
    if (values.isEmpty) {
      return Future<void>.value();
    }
    return _updateHeatMaps(HeatMapUpdates._command(inserts: values));
  }

  /// Updates a heatmap without rebuilding [HuaweiMap].
  Future<void> updateHeatMap(HeatMap heatMap) =>
      updateHeatMaps(<HeatMap>[heatMap]);

  /// Updates heatmaps in one platform-channel call.
  Future<void> updateHeatMaps(Iterable<HeatMap> heatMaps) {
    final Set<HeatMap> values = heatMaps.toSet();
    if (values.isEmpty) {
      return Future<void>.value();
    }
    return _updateHeatMaps(HeatMapUpdates._command(updates: values));
  }

  /// Removes a heatmap without rebuilding [HuaweiMap].
  Future<void> removeHeatMap(HeatMapId heatMapId) =>
      removeHeatMaps(<HeatMapId>[heatMapId]);

  /// Removes heatmaps in one platform-channel call.
  Future<void> removeHeatMaps(Iterable<HeatMapId> heatMapIds) {
    final Set<HeatMapId> values = heatMapIds.toSet();
    if (values.isEmpty) {
      return Future<void>.value();
    }
    return _updateHeatMaps(HeatMapUpdates._command(deletes: values));
  }

  /// Clears the cache of a tile overlay.
  Future<void> clearTileCache(TileOverlay tileOverlay) {
    return _HuaweiMapMethodChannel.clearTileCache(
      tileOverlay.tileOverlayId,
      mapId: mapId,
    );
  }

  /// Starts the animation of a marker.
  Future<void> startAnimationOnMarker(Marker marker) {
    return _HuaweiMapMethodChannel.startAnimationOnMarker(
      marker.markerId,
      mapId: mapId,
    );
  }

  /// Starts the animation of a circle.
  Future<void> startAnimationOnCircle(Circle circle) {
    return _HuaweiMapMethodChannel.startAnimationOnCircle(
      circle.circleId,
      mapId: mapId,
    );
  }

  /// Updates the camera position in animation mode.
  Future<void> animateCamera(CameraUpdate cameraUpdate) {
    return _HuaweiMapMethodChannel.animateCamera(cameraUpdate, mapId: mapId);
  }

  /// Stops the current animation of the camera.
  ///
  /// When this method is called, the camera stops moving immediately and remains in that position.
  Future<void> stopAnimation() {
    return _HuaweiMapMethodChannel.stopAnimation(mapId: mapId);
  }

  /// Updates the camera position.
  ///
  /// The movement is instantaneous.
  Future<void> moveCamera(CameraUpdate cameraUpdate) {
    return _HuaweiMapMethodChannel.moveCamera(cameraUpdate, mapId: mapId);
  }

  /// Sets the map style.
  Future<void> setMapStyle(String mapStyle) {
    return _HuaweiMapMethodChannel.setMapStyle(mapStyle, mapId: mapId);
  }

  /// Sets location for location source.
  Future<void> setLocation(LatLng latLng) {
    return _HuaweiMapMethodChannel.setLocation(latLng, mapId: mapId);
  }

  /// Sets the location source for the my-location layer.
  Future<void> setLocationSource() {
    return _HuaweiMapMethodChannel.setLocationSource(mapId: mapId);
  }

  /// Deactivates location source.
  Future<void> deactivateLocationSource() {
    return _HuaweiMapMethodChannel.deactivateLocationSource(mapId: mapId);
  }

  /// Obtains the visible region after conversion between the screen coordinates and longitude/latitude coordinates.
  Future<LatLngBounds> getVisibleRegion() {
    return _HuaweiMapMethodChannel.getVisibleRegion(mapId: mapId);
  }

  /// Obtains a location on the screen corresponding to the specified longitude/latitude coordinates.
  ///
  /// The location on the screen is specified in screen pixels (instead of display pixels) relative to the top left corner of the map (instead of the top left corner of the screen).
  Future<ScreenCoordinate> getScreenCoordinate(LatLng latLng) {
    return _HuaweiMapMethodChannel.getScreenCoordinate(latLng, mapId: mapId);
  }

  /// Obtains the longitude and latitude of a location on the screen.
  ///
  /// The location on the screen is specified in screen pixels (instead of display pixels) relative to the top left corner of the map (instead of the top left corner of the screen).
  Future<LatLng> getLatLng(ScreenCoordinate screenCoordinate) {
    return _HuaweiMapMethodChannel.getLatLng(screenCoordinate, mapId: mapId);
  }

  /// Converts a Flutter touch position into longitude and latitude.
  ///
  /// [localPosition] must be a logical-pixel position relative to the map's
  /// top-left corner, such as [PointerEvent.localPosition]. The plugin converts
  /// it to the physical screen pixels required by the native map projection.
  Future<LatLng> getLatLngFromTouch(Offset localPosition) {
    if (!localPosition.dx.isFinite || !localPosition.dy.isFinite) {
      throw ArgumentError.value(
        localPosition,
        'localPosition',
        'Touch coordinates must be finite.',
      );
    }

    return _HuaweiMapMethodChannel.getLatLngFromTouch(
      localPosition,
      mapId: mapId,
    );
  }

  /// Displays an information window for a marker.
  Future<void> showMarkerInfoWindow(MarkerId markerId) {
    return _HuaweiMapMethodChannel.showMarkerInfoWindow(markerId, mapId: mapId);
  }

  /// Hides the information window that is displayed for a marker.
  ///
  /// This method is invalid for invisible markers.
  Future<void> hideMarkerInfoWindow(MarkerId markerId) {
    return _HuaweiMapMethodChannel.hideMarkerInfoWindow(markerId, mapId: mapId);
  }

  /// Checks whether an information window is currently displayed for a marker.
  ///
  /// This method will not consider whether the information window is actually visible on the screen.
  Future<bool?> isMarkerInfoWindowShown(MarkerId markerId) {
    return _HuaweiMapMethodChannel.isMarkerInfoWindowShown(
      markerId,
      mapId: mapId,
    );
  }

  /// Checks whether a marker can be clustered.
  Future<bool?> isMarkerClusterable(MarkerId markerId) {
    return _HuaweiMapMethodChannel.isMarkerClusterable(markerId, mapId: mapId);
  }

  /// Obtains zoom level of a map.
  Future<double?> getZoomLevel() {
    return _HuaweiMapMethodChannel.getZoomLevel(mapId: mapId);
  }

  /// Obtains the current camera position of a map.
  Future<CameraPosition?> getCameraPosition() {
    return _HuaweiMapMethodChannel.getCameraPosition(mapId: mapId);
  }

  /// Takes a snapshot of a map.
  Future<Uint8List?> takeSnapshot() {
    return _HuaweiMapMethodChannel.takeSnapshot(mapId: mapId);
  }

  /// Obtains the length of one pixel point on the map at the current zoom level, in meters.
  Future<double?> getScalePerPixel() {
    return _HuaweiMapMethodChannel.getScalePerPixel(mapId: mapId);
  }
}

class HuaweiMap extends StatefulWidget {
  /// Non-gesture animation started in response to a user operation.
  static const int REASON_API_ANIMATON = 2;

  /// An animation started by the developer.
  static const int REASON_DEVELOPER_ANIMATION = 3;

  /// An animation started in response to user gestures on a map.
  static const int REASON_GESTURE = 1;

  /// Lower left logo and copyright position.
  static const int LOWER_LEFT = 8388691;

  /// Lower right logo and copyright position.
  static const int LOWER_RIGHT = 8388693;

  /// Upper left logo and copyright position.
  static const int UPPER_LEFT = 8388659;

  /// Lower right logo and copyright position.
  static const int UPPER_RIGHT = 8388661;

  /// Initial camera position for a map.
  final CameraPosition initialCameraPosition;

  /// Indicates whether to the compass is enabled for a map.
  final bool compassEnabled;

  /// Indicates whether to enable the dark mode.
  ///
  /// After the dark mode is enabled, popups displayed after the map logo is tapped, indoor map controls, and privacy agreement popups will be displayed in dark mode.
  final bool isDark;

  /// Indicates whether the toolbar is enabled for a map.
  final bool mapToolbarEnabled;

  /// [LatLngBounds] object to constrain the camera target so that the camera target does not move outside the bounds when a user scrolls the map.
  final CameraTargetBounds cameraTargetBounds;

  /// Map type.
  final MapType mapType;

  /// Preferred minimum and maximum zoom levels of the camera.
  final MinMaxZoomPreference minMaxZoomPreference;

  /// Indicates whether rotate gestures are enabled for a map.
  final bool rotateGesturesEnabled;

  /// Indicates whether scroll gestures are enabled for a map.
  final bool scrollGesturesEnabled;

  /// Indicates whether the zoom function is enabled for the camera.
  final bool zoomControlsEnabled;

  /// Indicates whether zoom gestures are enabled for a map.
  final bool zoomGesturesEnabled;

  /// Indicates whether tilt gestures are enabled for a map.
  final bool tiltGesturesEnabled;

  /// Padding on a map.
  final EdgeInsets padding;

  /// Indicates whether the my-location layer is enabled.
  ///
  /// If the my-location layer is enabled and the location is available, the layer constantly draws the user's current location and bearing and displays the UI controls for the user to interact with their location.
  ///
  /// To use the my-location layer function, you must apply for the `ACCESS_COARSE_LOCATION` or `ACCESS_FINE_LOCATION` permissions.
  final bool myLocationEnabled;

  /// Indicates whether the my-location icon is enabled for a map.
  final bool myLocationButtonEnabled;

  /// Indicates whether the traffic status layer is enabled.
  final bool trafficEnabled;

  /// Indicates whether the 3D building layer is enabled.
  final bool buildingsEnabled;

  /// Indicates whether a marker can be clustered.
  final bool markersClusteringEnabled;

  /// Indicates whether to enable all gestures for a map.
  final bool? allGesturesEnabled;

  /// Whether single-finger drawing on the map is enabled.
  ///
  /// While enabled, drawing gestures are consumed by the map and do not move
  /// or zoom the camera.
  final bool drawingEnabled;

  /// Indicates whether scroll gestures are enabled during rotation or zooming.
  final bool isScrollGesturesEnabledDuringRotateOrZoom;

  /// Sets whether a fixed screen center can be passed for zooming.
  ///
  /// - If so, the map will be zoomed based on the passed fixed screen center.
  /// - If not, the map will be zoomed based on the tap point on the screen. You can call the `pointToCenter` field to set the screen center coordinates.
  final bool gestureScaleByMapCenter;

  /// Sets a fixed screen center for zooming.
  final ScreenCoordinate? pointToCenter;

  /// Sets the color of the default cluster marker.
  final Color? clusterMarkerColor;

  /// Sets the text color of the custom cluster marker.
  final Color? clusterMarkerTextColor;

  /// Sets the icon of the custom cluster marker.
  final BitmapDescriptor? clusterIconDescriptor;

  /// Sets the position of the Petal Maps logo.
  final int logoPosition;

  /// Sets the padding between the map camera region edges and the logo.
  final EdgeInsets logoPadding;

  /// Sets a style ID.
  ///
  /// A style ID uniquely identifies a style. After creating a map, you can call this method to change the map style to a custom style.
  final String? styleId;

  /// Sets a preview ID.
  ///
  /// The preview ID is regenerated for a custom style when the style is edited. You can call this method to check the custom style effect after creating a map.
  final String? previewId;

  /// Indicates whether the lite mode is enabled for a map.
  final bool liteMode;

  /// Sets the my-location icon style.
  final MyLocationStyle? myLocationStyle;

  /// Function to be called when a map is created.
  final void Function(HuaweiMapController controller)? onMapCreated;

  /// Function to be called when a camera move started.
  final ArgumentCallback<int>? onCameraMoveStarted;

  /// Function to be called when a camera moved.
  final CameraPositionCallback? onCameraMove;

  /// Function to be called when a camera is idle.
  final VoidCallback? onCameraIdle;

  /// A listener to listen for the stop of camera movement or the interruption of camera movement due to a new animation.
  final VoidCallback? onCameraMoveCanceled;

  /// Function to be called when map is clicked.
  final ArgumentCallback<LatLng>? onClick;

  /// Function to be called when a map is long clicked.
  final ArgumentCallback<LatLng>? onLongPress;

  /// Function to be called when a map drawing gesture starts.
  final ArgumentCallback<LatLng>? onDrawStart;

  /// Function to be called when the current map drawing gesture moves.
  final ArgumentCallback<LatLng>? onDrawUpdate;

  /// Function to be called with the complete geographic path when drawing ends.
  final ArgumentCallback<List<LatLng>>? onDrawEnd;

  /// Function to be called when a POI is tapped.
  final ArgumentCallback<PointOfInterest>? onPoiClick;

  /// Function to be called when my-location dot is tapped.
  final ArgumentCallback<Location>? onMyLocationClick;

  /// Function to be called when my-location icon is tapped.
  final ArgumentCallback<bool>? onMyLocationButtonClick;

  const HuaweiMap({
    Key? key,
    required this.initialCameraPosition,
    this.mapType = MapType.normal,
    this.gestureRecognizers,
    this.compassEnabled = true,
    this.isDark = false,
    this.mapToolbarEnabled = true,
    this.cameraTargetBounds = CameraTargetBounds.unbounded,
    this.minMaxZoomPreference = MinMaxZoomPreference.unbounded,
    this.rotateGesturesEnabled = true,
    this.scrollGesturesEnabled = true,
    this.zoomControlsEnabled = true,
    this.zoomGesturesEnabled = true,
    this.tiltGesturesEnabled = true,
    this.myLocationEnabled = false,
    this.myLocationButtonEnabled = true,
    this.padding = EdgeInsets.zero,
    this.trafficEnabled = false,
    this.markersClusteringEnabled = false,
    this.buildingsEnabled = true,
    this.allGesturesEnabled,
    this.drawingEnabled = false,
    this.isScrollGesturesEnabledDuringRotateOrZoom = true,
    this.gestureScaleByMapCenter = false,
    this.pointToCenter,
    this.onMapCreated,
    this.onCameraMoveStarted,
    this.onCameraMove,
    this.onCameraIdle,
    this.onCameraMoveCanceled,
    this.onClick,
    this.onLongPress,
    this.onDrawStart,
    this.onDrawUpdate,
    this.onDrawEnd,
    this.onPoiClick,
    this.onMyLocationClick,
    this.onMyLocationButtonClick,
    this.clusterMarkerColor,
    this.clusterMarkerTextColor,
    this.clusterIconDescriptor,
    this.logoPosition = LOWER_LEFT,
    this.logoPadding = EdgeInsets.zero,
    this.styleId,
    this.previewId,
    this.liteMode = false,
    this.myLocationStyle,
  }) : super(key: key);

  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;

  @override
  State createState() => _HuaweiMapState();
}

class _HuaweiMapState extends State<HuaweiMap> {
  late HuaweiMapOptions _huaweiMapOptions;

  final Completer<HuaweiMapController> _controller =
      Completer<HuaweiMapController>();

  @override
  void initState() {
    super.initState();
    _huaweiMapOptions = HuaweiMapOptions.fromWidget(widget);
  }

  Future<void> onPlatformViewCreated(int id) async {
    debugPrint('HuaweiMap init: onPlatformViewCreated id=$id');
    final HuaweiMapController controller = await HuaweiMapController.init(
      id,
      widget.initialCameraPosition,
      this,
    );
    debugPrint('HuaweiMap init: HuaweiMapController.init completed id=$id');
    _controller.complete(controller);
    if (widget.onMapCreated != null) {
      debugPrint('HuaweiMap init: calling onMapCreated id=$id');
      widget.onMapCreated!(controller);
    }
  }

  void _updateOptions() async {
    final HuaweiMapOptions newOptions = HuaweiMapOptions.fromWidget(widget);
    final Map<String, dynamic> updates =
        _huaweiMapOptions.updatesMap(newOptions);
    if (updates.isEmpty) {
      return;
    }
    final HuaweiMapController controller = await _controller.future;
    controller._updateMapOptions(updates);
    _huaweiMapOptions = newOptions;
  }

  @override
  void didUpdateWidget(HuaweiMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateOptions();
  }

  void onClick(LatLng position) {
    widget.onClick?.call(position);
  }

  void onLongPress(LatLng position) {
    widget.onLongPress?.call(position);
  }

  void onDrawStart(LatLng position) {
    widget.onDrawStart?.call(position);
  }

  void onDrawUpdate(LatLng position) {
    widget.onDrawUpdate?.call(position);
  }

  void onDrawEnd(List<LatLng> points) {
    widget.onDrawEnd?.call(points);
  }

  void onPoiClick(PointOfInterest pointOfInterest) {
    widget.onPoiClick?.call(pointOfInterest);
  }

  void onMyLocationClick(Location location) {
    widget.onMyLocationClick?.call(location);
  }

  void onMyLocationButtonClick(bool onMyLocationButtonClicked) {
    widget.onMyLocationButtonClick?.call(onMyLocationButtonClicked);
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> creationParams = <String, dynamic>{
      _Param.initialCameraPosition: widget.initialCameraPosition.toMap(),
      _Param.options: _huaweiMapOptions.toMap(),
    };
    debugPrint(
      'HuaweiMap init: build widget '
      'initialCamera=${widget.initialCameraPosition.toMap()}',
    );
    return _HuaweiMapMethodChannel.buildView(
      creationParams,
      widget.gestureRecognizers,
      onPlatformViewCreated,
    );
  }
}
