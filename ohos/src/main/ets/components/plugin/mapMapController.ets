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
 *
 * MapController - per-map MethodChannel handler.
 */

import { MethodChannel, MethodCall, MethodResult, MethodCallHandler } from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { map, mapCommon } from '@kit.MapKit';
import { image } from '@kit.ImageKit';
import { geoLocationManager } from '@kit.LocationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { Method } from './constants/Method';
import { Param } from './constants/Param';
import { Convert } from './utils/Convert';
import { ToJson } from './utils/ToJson';
import { HmsMap } from './HmsMap';
import { MapUtils, AssetPathResolver } from './mapMapUtils';
import { MapListenerHandler } from './mapMapListenerHandler';
import { AnimationConvert } from './animationAnimationConvert';

const TAG: string = '[MapController]';

export class MapController implements MethodCallHandler {
  private readonly id: number;
  private context: common.UIAbilityContext;
  private mapController: map.MapComponentController;
  private hmsMap: HmsMap;
  private methodChannel: MethodChannel | null = null;
  private assetResolver: AssetPathResolver;

  private trackCameraPosition: boolean = false;
  private disposed: boolean = false;

  private mapUtils: MapUtils;
  private mapListenerHandler: MapListenerHandler | null = null;

  constructor(
    id: number,
    context: common.UIAbilityContext,
    mapCtrl: map.MapComponentController,
    hmsMap: HmsMap,
    assetResolver: AssetPathResolver
  ) {
    this.id = id;
    this.context = context;
    this.mapController = mapCtrl;
    this.hmsMap = hmsMap;
    this.assetResolver = assetResolver;
    this.mapUtils = new MapUtils();
    this.mapUtils.setContext(context);
    this.mapUtils.setAssetResolver(assetResolver);
    hilog.info(0x0000, TAG, `MapController created with id=${id}`);
  }

  setMethodChannel(channel: MethodChannel): void {
    hilog.info(0x0000, TAG, `setMethodChannel start id=${this.id}`);
    this.methodChannel = channel;
    this.mapUtils.setMethodChannel(channel);
    this.mapUtils.setMapController(this.mapController);
    this.mapListenerHandler = new MapListenerHandler(this.id, this.mapUtils, channel);
    const eventManager = this.mapController.getEventManager();
    if (eventManager) {
      hilog.info(0x0000, TAG, `eventManager ready id=${this.id}; initializing listeners`);
      this.mapListenerHandler.init(eventManager);
    } else {
      hilog.warn(0x0000, TAG, `eventManager is null id=${this.id}`);
    }
    hilog.info(0x0000, TAG, `setMethodChannel complete id=${this.id}`);
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    hilog.info(0x0000, TAG, `onMethodCall id=${this.id} method=${call.method}`);
    if (this.disposed) {
      result.error('DISPOSED', 'MapController has been disposed', null);
      return;
    }

    switch (call.method) {
      case Method.MAP_WAIT_FOR_MAP:
        hilog.info(0x0000, TAG, `MAP_WAIT_FOR_MAP success id=${this.id}`);
        result.success(null);
        break;

      case Method.MAP_UPDATE: {
        const args = (call.args ?? {}) as Record<string, Object>;
        const options = (args[Param.OPTIONS] as Record<string, Object>) ?? {};
        Convert.processMapOptions(options, this);
        try {
          const pos = this.mapController.getCameraPosition();
          result.success(ToJson.cameraPosition(pos));
        } catch (e) {
          result.success(null);
        }
        break;
      }

      case Method.MAP_GET_VISIBLE_REGION: {
        try {
          const proj = this.mapController.getProjection();
          const region = proj.getVisibleRegion();
          result.success(ToJson.visibleRegion(region));
        } catch (e) {
          result.error('ERROR', `getVisibleRegion failed: ${e}`, null);
        }
        break;
      }

      case Method.MAP_GET_SCREEN_COORDINATE: {
        try {
          const latLng = Convert.toLatLng(call.args);
          const proj = this.mapController.getProjection();
          const point = proj.toScreenLocation(latLng);
          result.success(ToJson.point(point));
        } catch (e) {
          result.error('ERROR', `getScreenCoordinate failed: ${e}`, null);
        }
        break;
      }

      case Method.MAP_GET_LAT_LNG: {
        try {
          const pt = Convert.toPoint(call.args);
          const proj = this.mapController.getProjection();
          const latLng = proj.fromScreenLocation(pt);
          result.success(ToJson.latLng(latLng));
        } catch (e) {
          result.error('ERROR', `getLatLng failed: ${e}`, null);
        }
        break;
      }

      case Method.CAMERA_MOVE: {
        try {
          const args = (call.args ?? {}) as Record<string, Object>;
          const cameraUpdate = AnimationConvert.toCameraUpdate(args[Param.CAMERA_UPDATE]);
          this.mapController.moveCamera(cameraUpdate);
          result.success(null);
        } catch (e) {
          result.error('ERROR', `moveCamera failed: ${e}`, null);
        }
        break;
      }

      case Method.CAMERA_ANIMATE: {
        try {
          const args = (call.args ?? {}) as Record<string, Object>;
          const cameraUpdate = AnimationConvert.toCameraUpdate(args[Param.CAMERA_UPDATE]);
          this.mapController.animateCamera(cameraUpdate);
          result.success(null);
        } catch (e) {
          result.error('ERROR', `animateCamera failed: ${e}`, null);
        }
        break;
      }

      case Method.STOP_ANIMATION: {
        try { this.mapController.stopAnimation(); } catch (e) { /* ignore */ }
        result.success(null);
        break;
      }

      case Method.MAP_TAKE_SNAPSHOT: {
        this.handleSnapshot(result);
        break;
      }

      case Method.SET_LOCATION_SOURCE:
      case Method.DEACTIVATE_LOC_SOURCE: {
        // HarmonyOS MapKit has no equivalent for setLocationSource /
        // deactivateLocationSource — the platform owns the location source
        // implicitly. Acknowledge so the Dart Future resolves.
        result.success(null);
        break;
      }

      case Method.SET_LOCATION: {
        try {
          const latLng = Convert.toLatLng(call.args);
          // mapController.setMyLocation expects a geoLocationManager.Location
          // with all fields populated (none are optional). We synthesize
          // sensible defaults for fields Flutter doesn't provide.
          const now = Date.now();
          const loc: geoLocationManager.Location = {
            latitude: latLng.latitude,
            longitude: latLng.longitude,
            altitude: 0,
            accuracy: 0,
            speed: 0,
            timeStamp: now,
            direction: 0,
            timeSinceBoot: now
          };
          this.mapController.setMyLocation(loc);
          result.success(null);
        } catch (e) {
          hilog.warn(0x0000, TAG, `setLocation failed: ${e}`);
          result.error('ERROR', `setLocation failed: ${e}`, null);
        }
        break;
      }

      case Method.MAP_GET_SCALEPERPIXEL: {
        try {
          const scale = this.mapController.getScalePerPixel();
          result.success(scale);
        } catch (e) {
          result.error('ERROR', `getScalePerPixel failed: ${e}`, null);
        }
        break;
      }

      case Method.MAP_GET_ZOOM_LEVEL: {
        try {
          const pos = this.mapController.getCameraPosition();
          result.success(pos.zoom);
        } catch (e) {
          result.error('ERROR', `getZoomLevel failed: ${e}`, null);
        }
        break;
      }

      case Method.MAP_SET_STYLE: {
        // HarmonyOS MapKit's `setStyle(string)` is not available on
        // MapComponentController. Acknowledge so Dart's await resolves.
        hilog.info(0x0000, TAG, 'setStyle(string) ignored on HarmonyOS — use styleId');
        result.success(null);
        break;
      }

      default:
        this.mapUtils.onMethodCall(call, result);
        break;
    }
  }

  private async handleSnapshot(result: MethodResult): Promise<void> {
    try {
      const pixelMap = await this.mapController.snapshot();
      const bytes = await this.pixelMapToUint8Array(pixelMap);
      result.success(bytes);
    } catch (e) {
      result.error('ERROR', `snapshot failed: ${e}`, null);
    }
  }

  // ========== MapOptions setters (called by Convert.processMapOptions) ==========

  setCompassControlsEnabled(enabled: boolean): void {
    try { this.mapController.setCompassControlsEnabled(enabled); } catch (e) { /* ignore */ }
  }
  setMapType(mapType: mapCommon.MapType): void {
    try { this.mapController.setMapType(mapType); } catch (e) { /* ignore */ }
  }
  setTrafficEnabled(enabled: boolean): void {
    try { this.mapController.setTrafficEnabled(enabled); } catch (e) { /* ignore */ }
  }
  setMarkersClustering(clustering: boolean): void {
    this.mapUtils.setClusteringEnabled(clustering);
  }
  setBuildingEnabled(enabled: boolean): void {
    try { this.mapController.setBuildingEnabled(enabled); } catch (e) { /* ignore */ }
  }
  setZoomGesturesEnabled(enabled: boolean): void {
    try { this.mapController.setZoomGesturesEnabled(enabled); } catch (e) { /* ignore */ }
  }
  setMyLocationEnabled(enabled: boolean): void {
    try { this.mapController.setMyLocationEnabled(enabled); } catch (e) { /* ignore */ }
  }
  setMyLocationControlsEnabled(enabled: boolean): void {
    try { this.mapController.setMyLocationControlsEnabled(enabled); } catch (e) { /* ignore */ }
  }
  setZoomControlsEnabled(enabled: boolean): void {
    try { this.mapController.setZoomControlsEnabled(enabled); } catch (e) { /* ignore */ }
  }
  setRotateGesturesEnabled(enabled: boolean): void {
    try { this.mapController.setRotateGesturesEnabled(enabled); } catch (e) { /* ignore */ }
  }
  setScrollGesturesEnabled(enabled: boolean): void {
    try { this.mapController.setScrollGesturesEnabled(enabled); } catch (e) { /* ignore */ }
  }
  setTiltGesturesEnabled(enabled: boolean): void {
    try { this.mapController.setTiltGesturesEnabled(enabled); } catch (e) { /* ignore */ }
  }
  setAllGesturesEnabled(enabled: boolean): void {
    try { this.mapController.setAllGesturesEnabled(enabled); } catch (e) { /* ignore */ }
  }
  setLatLngBounds(bounds: mapCommon.LatLngBounds): void {
    try { this.mapController.setLatLngBounds(bounds); } catch (e) { /* ignore */ }
  }
  setTrackCameraPosition(track: boolean): void {
    this.trackCameraPosition = track;
    this.mapListenerHandler?.setTrackCameraPosition(track);
  }
  setPadding(padding: mapCommon.Padding): void {
    try { this.mapController.setPadding(padding); } catch (e) { /* ignore */ }
  }
  setMinZoom(min: number): void {
    try { this.mapController.setMinZoom(min); } catch (e) { /* ignore */ }
  }
  setMaxZoom(max: number): void {
    try { this.mapController.setMaxZoom(max); } catch (e) { /* ignore */ }
  }
  setPointToCenter(pt: mapCommon.MapPoint): void {
    try { this.mapController.setPointToCenter(pt); } catch (e) { /* ignore */ }
  }
  setLogoAlignment(alignment: mapCommon.LogoAlignment): void {
    try { this.mapController.setLogoAlignment(alignment); } catch (e) {
      hilog.warn(0x0000, TAG, `setLogoAlignment failed: ${e}`);
    }
  }
  setStyleId(styleId: string): void {
    // OHOS MapComponentController has no setStyleId API exposed; logging only.
    hilog.info(0x0000, TAG, `setStyleId(${styleId}) ignored (no runtime API on HarmonyOS)`);
  }
  setMyLocationStyle(style: mapCommon.MyLocationStyle): Promise<void> {
    try {
      return this.mapController.setMyLocationStyle(style);
    } catch (e) {
      return Promise.resolve();
    }
  }
  /**
   * Cluster marker color/icon styling. Stored only; getCustomIcon() in the
   * cluster overlay params is the proper hook but requires an icon builder
   * which is out of scope here. Logged so we can wire it later if needed.
   */
  setClusterMarkerColor(color: number): void {
    hilog.info(0x0000, TAG, `clusterMarkerColor=${color} stored (no runtime API)`);
  }
  setClusterMarkerTextColor(color: number): void {
    hilog.info(0x0000, TAG, `clusterMarkerTextColor=${color} stored (no runtime API)`);
  }
  setClusterMarkerIcon(icon: Object): void {
    hilog.info(0x0000, TAG, `clusterMarkerIcon stored (no runtime API): ${JSON.stringify(icon)}`);
  }

  // ========== Initial inserts from creationParams ==========

  initMarkers(markers: Array<Record<string, Object>>): void { this.mapUtils.initMarkers(markers); }
  initPolylines(polylines: Array<Record<string, Object>>): void { this.mapUtils.initPolylines(polylines); }
  initPolygons(polygons: Array<Record<string, Object>>): void { this.mapUtils.initPolygons(polygons); }
  initCircles(circles: Array<Record<string, Object>>): void { this.mapUtils.initCircles(circles); }
  initGroundOverlays(overlays: Array<Record<string, Object>>): void { this.mapUtils.initGroundOverlays(overlays); }
  initTileOverlays(overlays: Array<Record<string, Object>>): void { this.mapUtils.initTileOverlays(overlays); }
  initHeatMaps(heatMaps: Array<Record<string, Object>>): void { this.mapUtils.initHeatMaps(heatMaps); }

  // ========== Lifecycle ==========

  dispose(): void {
    if (this.disposed) return;
    this.disposed = true;
    this.methodChannel?.setMethodCallHandler(null);
    this.mapListenerHandler?.dispose();
    this.mapListenerHandler = null;
    this.mapUtils.dispose();
    this.hmsMap.dispose();
    hilog.info(0x0000, TAG, `MapController ${this.id} disposed`);
  }

  getMapController(): map.MapComponentController { return this.mapController; }
  getId(): number { return this.id; }
  getContext(): common.UIAbilityContext { return this.context; }

  /** Encode a PixelMap as PNG bytes (Uint8Array) for Dart's takeSnapshot. */
  private async pixelMapToUint8Array(pixelMap: image.PixelMap): Promise<Uint8Array> {
    const packer = image.createImagePacker();
    const packingOpts: image.PackingOption = { format: 'image/png', quality: 100 };
    const buffer = await packer.packing(pixelMap, packingOpts);
    return new Uint8Array(buffer);
  }
}
