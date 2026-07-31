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

// Must match _Method constants in lib/src/constants/method.dart exactly (Dart side)
export class Method {
  static readonly CAMERA_ON_MOVE_STARTED: string = '[Camera]onMoveStarted';
  static readonly CAMERA_ON_MOVE: string = '[Camera]onMove';
  static readonly CAMERA_ON_IDLE: string = '[Camera]onIdle';
  static readonly CAMERA_ON_MOVE_CANCELED: string = '[Camera]onMoveCancelled';

  static readonly MARKER_CLICK: string = '[Marker]click';
  static readonly MARKER_ON_DRAG_END: string = '[Marker]onDragEnd';
  static readonly MARKER_ON_DRAG_START: string = '[Marker]onDragStart';
  static readonly MARKER_ON_DRAG: string = '[Marker]onDrag';

  static readonly INFO_WINDOW_CLICK: string = '[InfoWindow]click';
  static readonly INFO_WINDOW_LONG_CLICK: string = '[InfoWindow]longClick';
  static readonly INFO_WINDOW_CLOSE: string = '[InfoWindow]close';

  static readonly POLYLINE_CLICK: string = '[Polyline]click';
  static readonly POLYGON_CLICK: string = '[Polygon]click';
  static readonly CIRCLE_CLICK: string = '[Circle]click';

  static readonly MAP_CLICK: string = '[Map]click';
  static readonly MAP_ON_LONG_PRESS: string = '[Map]onLongPress';
  static readonly MAP_ON_DRAW_START: string = '[Map]onDrawStart';
  static readonly MAP_ON_DRAW_UPDATE: string = '[Map]onDrawUpdate';
  static readonly MAP_ON_DRAW_END: string = '[Map]onDrawEnd';
  static readonly MAP_WAIT_FOR_MAP: string = '[Map]waitForMap';
  static readonly MAP_ON_POI_CLICK: string = '[Map]onPoiClick';
  static readonly MAP_ON_MY_LOCATION_CLICK: string = '[Map]onMyLocationClick';
  static readonly MAP_ON_MY_LOCATION_BUTTON_CLICK: string = '[Map]onMyLocationButtonClick';

  static readonly MAP_UPDATE: string = '[Map]update';
  static readonly MAP_GET_VISIBLE_REGION: string = '[Map]getVisibleRegion';
  static readonly MAP_GET_SCREEN_COORDINATE: string = '[Map]getScreenCoordinate';
  static readonly MAP_GET_LAT_LNG: string = '[Map]getLatLng';
  static readonly MAP_TAKE_SNAPSHOT: string = '[Map]takeSnapshot';

  static readonly CAMERA_MOVE: string = '[Camera]move';
  static readonly CAMERA_ANIMATE: string = '[Camera]animate';
  static readonly STOP_ANIMATION: string = '[Map]stopAnimation';

  static readonly MARKERS_UPDATE: string = '[Markers]update';
  static readonly MARKERS_SHOW_INFO_WINDOW: string = '[Markers]showInfoWindow';
  static readonly MARKERS_HIDE_INFO_WINDOW: string = '[Markers]hideInfoWindow';
  static readonly MARKERS_IS_INFO_WINDOW_SHOWN: string = '[Markers]isInfoWindowShown';

  static readonly POLYGONS_UPDATE: string = '[Polygons]update';
  static readonly POLYLINES_UPDATE: string = '[Polylines]update';
  static readonly CIRCLES_UPDATE: string = '[Circles]update';
  static readonly MASS_POINTS_ADD: string = '[MassPoints]add';

  static readonly GROUND_OVERLAYS_UPDATE: string = '[GroundOverlays]update';
  static readonly GROUND_OVERLAY_CLICK: string = '[GroundOverlay]click';

  static readonly TILE_OVERLAYS_UPDATE: string = '[TileOverlays]update';
  static readonly CLEAR_TILE_CACHE: string = 'clearTileCache';

  static readonly HEAT_MAPS_UPDATE: string = '[HeatMap]update';

  static readonly MARKER_START_ANIMATION: string = 'MarkerStartAnimation';
  static readonly MARKER_IS_CLUSTERABLE: string = '[Markers]isMarkerClusterable';
  // HarmonyOS MapCircle has no animation API. Channel is still acknowledged
  // so Dart's controller.startAnimationOnCircle() does not throw
  // MissingPluginException.
  static readonly CIRCLE_START_ANIMATION: string = 'CircleStartAnimation';

  // MapUtil methods
  static readonly INITIALIZE_MAP: string = '[MapUtil]initializeMap';
  static readonly SET_API_KEY: string = '[MapUtil]setApiKey';
  static readonly SET_ACCESS_TOKEN: string = '[MapUtil]setAccessToken';
  static readonly DISTANCE_CALCULATOR: string = '[MapUtil]distanceCalculator';
  static readonly CONVERT_COORDINATE: string = '[MapUtil]convertCoordinate';
  static readonly CONVERT_COORDINATES: string = '[MapUtil]convertCoordinates';
  static readonly ENABLE_LOGGER: string = '[MapUtil]enableLogger';
  static readonly DISABLE_LOGGER: string = '[MapUtil]disableLogger';

  // Location methods
  static readonly SET_LOCATION_SOURCE: string = '[Map]setLocationSource';
  static readonly SET_LOCATION: string = '[Map]setLocation';
  static readonly DEACTIVATE_LOC_SOURCE: string = '[Map]deactivateLocationSource';

  static readonly MAP_GET_SCALEPERPIXEL: string = '[Map]getScalePerPixel';
  static readonly MAP_SET_STYLE: string = '[Map]setStyle';
  static readonly MAP_GET_ZOOM_LEVEL: string = '[Map]getZoomLevel';
  static readonly MAP_GET_CAMERA_POSITION: string = '[Map]getCameraPosition';
}
