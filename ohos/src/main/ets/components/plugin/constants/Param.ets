/*
 * Copyright 2020-2024. Huawei Technologies Co., Ltd. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License")
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// Must match _Param constants in lib/src/constants/param.dart exactly (Dart side)
export class Param {
  static readonly OPTIONS: string = 'options';
  static readonly INITIAL_CAMERA_POSITION: string = 'initialCameraPosition';
  static readonly CAMERA_UPDATE: string = 'cameraUpdate';
  static readonly   NEW_CAMERA_POSITION = "newCameraPosition";

  // Marker params
  static readonly MARKERS_TO_INSERT: string = 'markersToAdd';
  static readonly MARKERS_TO_UPDATE: string = 'markersToChange';
  static readonly MARKERS_TO_DELETE: string = 'markerIdsToRemove';
  static readonly MARKER_ID: string = 'markerId';
  static readonly ALPHA: string = 'alpha';
  static readonly ANCHOR: string = 'anchor';
  static readonly CLICKABLE: string = 'clickable';
  static readonly DRAGGABLE: string = 'draggable';
  static readonly FLAT: string = 'flat';
  static readonly ICON: string = 'icon';
  static readonly INFO_WINDOW: string = 'infoWindow';
  static readonly ROTATION: string = 'rotation';
  static readonly VISIBLE: string = 'visible';
  static readonly Z_INDEX: string = 'zIndex';
  static readonly TITLE: string = 'title';
  static readonly SNIPPET: string = 'snippet';

  // Polyline params
  static readonly POLYLINES_TO_INSERT: string = 'polylinesToAdd';
  static readonly POLYLINES_TO_UPDATE: string = 'polylinesToChange';
  static readonly POLYLINES_TO_DELETE: string = 'polylineIdsToRemove';
  static readonly POLYLINE_ID: string = 'polylineId';
  static readonly COLOR: string = 'color';
  static readonly WIDTH: string = 'width';
  static readonly POINTS: string = 'points';
  static readonly END_CAP: string = 'endCap';
  static readonly START_CAP: string = 'startCap';
  static readonly JOINT_TYPE: string = 'jointType';
  static readonly PATTERN: string = 'pattern';
  static readonly GEODESIC: string = 'geodesic';

  // Polygon params
  static readonly POLYGONS_TO_INSERT: string = 'polygonsToAdd';
  static readonly POLYGONS_TO_UPDATE: string = 'polygonsToChange';
  static readonly POLYGONS_TO_DELETE: string = 'polygonIdsToRemove';
  static readonly POLYGON_ID: string = 'polygonId';
  static readonly FILL_COLOR: string = 'fillColor';
  static readonly STROKE_COLOR: string = 'strokeColor';
  static readonly STROKE_WIDTH: string = 'strokeWidth';
  static readonly HOLES: string = 'holes';
  static readonly STROKE_JOINT_TYPE: string = 'strokeJointType';
  static readonly STROKE_PATTERN: string = 'strokePattern';

  // Circle params
  static readonly CIRCLES_TO_INSERT: string = 'circlesToAdd';
  static readonly CIRCLES_TO_UPDATE: string = 'circlesToChange';
  static readonly CIRCLES_TO_DELETE: string = 'circleIdsToRemove';
  static readonly CIRCLE_ID: string = 'circleId';
  static readonly CENTER: string = 'center';
  static readonly RADIUS: string = 'radius';
  static readonly MASS_POINTS: string = 'massPoints';
  static readonly SCREEN_RADIUS: string = 'screenRadius';

  // GroundOverlay params
  static readonly GROUND_OVERLAYS_TO_INSERT: string = 'groundOverlaysToAdd';
  static readonly GROUND_OVERLAYS_TO_UPDATE: string = 'groundOverlaysToChange';
  static readonly GROUND_OVERLAYS_TO_DELETE: string = 'groundOverlayIdsToRemove';
  static readonly GROUND_OVERLAY_ID: string = 'groundOverlayId';
  static readonly HEIGHT: string = 'height';
  static readonly IMAGE_DESCRIPTOR: string = 'imageDescriptor';
  static readonly BOUNDS: string = 'bounds';
  static readonly TRANSPARENCY: string = 'transparency';


  // TileOverlay params
  static readonly TILE_OVERLAYS_TO_INSERT: string = 'tileOverlaysToAdd';
  static readonly TILE_OVERLAYS_TO_UPDATE: string = 'tileOverlaysToChange';
  static readonly TILE_OVERLAYS_TO_DELETE: string = 'tileOverlayIdsToRemove';
  static readonly TILE_OVERLAY_ID: string = 'tileOverlayId';
  static readonly FADE_IN: string = 'fadeIn';
  static readonly TILE_PROVIDER: string = 'tileProvider';
  static readonly URI: string = 'uri';

  // HeatMap params
  static readonly HEAT_MAPS_TO_INSERT: string = 'heatMapsToAdd';
  static readonly HEAT_MAPS_TO_UPDATE: string = 'heatMapsToChange';
  static readonly HEAT_MAPS_TO_DELETE: string = 'heatMapIdsToRemove';
  static readonly HEAT_MAP_ID: string = 'heatMapId';
  static readonly RESOURCE_ID: string = 'resourceId';
  static readonly JSON_DATA: string = 'jsonData';
  static readonly INTENSITY: string = 'intensity';
  static readonly OPACITY: string = 'opacity';
  static readonly RADIUS_UNIT: string = 'radiusUnit';

  // Camera / Map options
  static readonly POSITION: string = 'position';
  static readonly REASON: string = 'reason';
  static readonly COMPASS_ENABLED: string = 'compassEnabled';
  static readonly IS_DARK: string = 'isDark';
  static readonly MAP_TOOLBAR_ENABLED: string = 'mapToolbarEnabled';
  static readonly CAMERA_TARGET_BOUNDS: string = 'cameraTargetBounds';
  static readonly MAP_TYPE: string = 'mapType';
  static readonly MIN_MAX_ZOOM_PREFERENCE: string = 'minMaxZoomPreference';
  static readonly ROTATE_GESTURES_ENABLED: string = 'rotateGesturesEnabled';
  static readonly SCROLL_GESTURES_ENABLED: string = 'scrollGesturesEnabled';
  static readonly TILT_GESTURES_ENABLED: string = 'tiltGesturesEnabled';
  static readonly ZOOM_CONTROLS_ENABLED: string = 'zoomControlsEnabled';
  static readonly ZOOM_GESTURES_ENABLED: string = 'zoomGesturesEnabled';
  static readonly ALL_GESTURES_ENABLED: string = 'allGesturesEnabled';
  static readonly TRACK_CAMERA_POSITION: string = 'trackCameraPosition';
  static readonly MY_LOCATION_ENABLED: string = 'myLocationEnabled';
  static readonly MY_LOCATION_BUTTON_ENABLED: string = 'myLocationButtonEnabled';
  static readonly PADDING: string = 'padding';
  static readonly TRAFFIC_ENABLED: string = 'trafficEnabled';
  static readonly BUILDINGS_ENABLED: string = 'buildingsEnabled';
  static readonly POINT_TO_CENTER: string = 'pointToCenter';
  static readonly LOGO_POSITION: string = 'logoPosition';
  static readonly LOGO_PADDING: string = 'logoPadding';
  static readonly STYLE_ID: string = 'styleId';
  static readonly MY_LOCATION_STYLE: string = 'myLocationStyle';
  static readonly MARKERS_CLUSTERING_ENABLED: string = 'markersClusteringEnabled';

  // CameraPosition fields
  static readonly TARGET: string = 'target';
  static readonly ZOOM: string = 'zoom';
  static readonly TILT: string = 'tilt';
  static readonly BEARING: string = 'bearing';

  // CameraUpdate factory types

  static readonly NEW_LAT_LNG: string = 'newLatLng';
  static readonly NEW_LAT_LNG_BOUNDS: string = 'newLatLngBounds';
  static readonly NEW_LAT_LNG_ZOOM: string = 'newLatLngZoom';
  static readonly SCROLL_BY: string = 'scrollBy';
  static readonly ZOOM_BY: string = 'zoomBy';
  static readonly ZOOM_IN: string = 'zoomIn';
  static readonly ZOOM_OUT: string = 'zoomOut';
  static readonly ZOOM_TO: string = 'zoomTo';

  // LatLng / Bounds
  static readonly NORTHEAST: string = 'northeast';
  static readonly SOUTHWEST: string = 'southwest';
  static readonly LAT_LNG: string = 'latLng';
  static readonly LATITUDE: string = 'latitude';
  static readonly LONGITUDE: string = 'longitude';

  // Screen coordinate
  static readonly X: string = 'x';
  static readonly Y: string = 'y';

  // Pattern items
  static readonly DOT: string = 'dot';
  static readonly DASH: string = 'dash';
  static readonly GAP: string = 'gap';

  // POI
  static readonly POI: string = 'pointOfInterest';
  static readonly NAME: string = 'name';
  static readonly PLACE_ID: string = 'placeId';

  // Animation
  static readonly ANIMATION_ID: string = 'animationId';
  static readonly ANIMATION: string = 'animation';
  static readonly DURATION: string = 'duration';
  static readonly FILL_MODE: string = 'fillMode';
  static readonly REPEAT_COUNT: string = 'repeatCount';
  static readonly REPEAT_MODE: string = 'repeatMode';
  static readonly ANIMATION_TYPE: string = 'animationType';
  static readonly FROM_ALPHA: string = 'fromAlpha';
  static readonly TO_ALPHA: string = 'toAlpha';
  static readonly FROM_DEGREE: string = 'fromDegree';
  static readonly TO_DEGREE: string = 'toDegree';
  static readonly FROM_X: string = 'fromX';
  static readonly FROM_Y: string = 'fromY';
  static readonly TO_X: string = 'toX';
  static readonly TO_Y: string = 'toY';
  static readonly INTERPOLATOR: string = 'interpolator';

  // Overlay common
  static readonly GRADIENT: string = 'gradient';
  static readonly COLOR_VALUES: string = 'colorValues';
  static readonly CLUSTERABLE: string = 'clusterable';
  static readonly IMAGE_DATA: string = 'imageData';
  static readonly WEIGHT: string = 'weight';

  // HeatMap extended
  static readonly INTENSITY_MAP: string = 'intensityMap';
  static readonly OPACITY_MAP: string = 'opacityMap';
  static readonly RADIUS_MAP: string = 'radiusMap';

  // Location
  static readonly LOCATION: string = 'location';
  static readonly ALTITUDE: string = 'altitude';
  static readonly SPEED: string = 'speed';
  static readonly ACCURACY: string = 'accuracy';
  static readonly RADIUS_FILL_COLOR: string = 'radiusFillColor';

  // BitmapDescriptor types (must match Dart _Param)
  static readonly DEFAULT_MARKER: string = 'defaultMarker';
  static readonly FROM_BYTES: string = 'fromBytes';
  static readonly FROM_ASSET: string = 'fromAsset';
  static readonly FROM_ASSET_IMAGE: string = 'fromAssetImage';

  // Map options extra (sent by HuaweiMapOptions.toMap but not yet handled)
  static readonly IS_SCROLL_GESTURES_ENABLED_DURING_ROTATE_OR_ZOOM: string = 'isScrollGesturesEnabledDuringRotateOrZoom';
  static readonly GESTURE_SCALE_BY_MAP_CENTER: string = 'gestureScaleByMapCenter';

  // Cluster styling
  static readonly CLUSTER_MARKER_COLOR: string = 'clusterMarkerColor';
  static readonly CLUSTER_MARKER_TEXT_COLOR: string = 'clusterMarkerTextColor';
  static readonly CLUSTER_MARKER_ICON: string = 'clusterMarkerIcon';
  static readonly PREVIEW_ID: string = 'previewId';
  static readonly LITE_MODE: string = 'liteMode';

  // Clusterable flag inside a single marker
  static readonly DARK: string = 'isDark';

  // Pattern item primitive type names (sent verbatim from Dart)
  static readonly PATTERN_DOT: string = 'dot';
  static readonly PATTERN_DASH: string = 'dash';
  static readonly PATTERN_GAP: string = 'gap';

  // Cap names (sent verbatim from Dart)
  static readonly CAP_BUTT: string = 'buttCap';
  static readonly CAP_ROUND: string = 'roundCap';
  static readonly CAP_SQUARE: string = 'squareCap';
  static readonly CAP_CUSTOM: string = 'customCap';

  // Error
  static readonly ERROR: string = 'error';
}
