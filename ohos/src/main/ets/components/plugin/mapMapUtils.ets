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

import { MethodChannel, MethodCall, MethodResult, MethodCallHandler } from '@ohos/flutter_ohos';
import { map, mapCommon } from '@kit.MapKit';
import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { Method } from './constants/Method';
import { Param } from './constants/Param';
import { Convert } from './utils/Convert';
import {
  MarkerController,
  PolylineController,
  PolygonController,
  CircleController,
  GroundOverlayController,
  TileOverlayController,
  HeatMapController
} from './overlayControllers';

const TAG: string = '[MapUtils]';

interface MassPointGroup {
  screenRadius: number;
  color: number;
  items: Array<mapCommon.MassPointItem>;
}

/** Looks up a Flutter asset's path inside the host hap. */
export type AssetPathResolver = (assetName: string, packageName?: string) => string;

function describeIcon(iconData: Object | undefined | null): string {
  if (iconData === undefined || iconData === null) return 'none';
  if (!Array.isArray(iconData)) return typeof iconData;
  const arr = iconData as Array<Object>;
  const type = String(arr[0] ?? 'unknown');
  if (type === Param.FROM_BYTES) {
    const bytes = arr[1];
    if (bytes instanceof Uint8Array) return `${type}(length=${bytes.byteLength})`;
    if (bytes instanceof ArrayBuffer) return `${type}(length=${bytes.byteLength})`;
    return `${type}(bytesType=${typeof bytes})`;
  }
  if (type === Param.FROM_ASSET || type === Param.FROM_ASSET_IMAGE) {
    return `${type}(asset=${String(arr[1] ?? '')})`;
  }
  return type;
}

function describeMarker(data: Record<string, Object>): string {
  return `id=${String(data[Param.MARKER_ID] ?? '')} ` +
    `position=${JSON.stringify(data[Param.POSITION] ?? data[Param.LAT_LNG])} ` +
    `clusterable=${String(data[Param.CLUSTERABLE] ?? false)} ` +
    `visible=${String(data[Param.VISIBLE] ?? true)} ` +
    `icon=${describeIcon(data[Param.ICON])}`;
}

function describeTileProvider(provider: Object | undefined | null): string {
  if (provider === undefined || provider === null) return 'none';
  if (Array.isArray(provider)) return `List<Tile>(count=${(provider as Array<Object>).length})`;
  if (typeof provider !== 'object') return typeof provider;
  const rec = provider as Record<string, Object>;
  if (rec[Param.URI] !== undefined) return `UrlTile(uri=${String(rec[Param.URI])})`;
  if (rec[Param.IMAGE_DATA] !== undefined && rec[Param.ZOOM] !== undefined) return 'RepetitiveTile';
  return `Object(keys=${Object.keys(rec).join(',')})`;
}

function describeTileOverlay(data: Record<string, Object>): string {
  return `id=${String(data[Param.TILE_OVERLAY_ID] ?? '')} ` +
    `provider=${describeTileProvider(data[Param.TILE_PROVIDER])} ` +
    `fadeIn=${String(data[Param.FADE_IN] ?? '')} ` +
    `visible=${String(data[Param.VISIBLE] ?? '')} ` +
    `zIndex=${String(data[Param.Z_INDEX] ?? '')} ` +
    `transparency=${String(data[Param.TRANSPARENCY] ?? '')}`;
}

export class MapUtils implements MethodCallHandler {
  private methodChannel: MethodChannel | null = null;

  private markerControllers: Map<string, MarkerController> = new Map();
  private polylineControllers: Map<string, PolylineController> = new Map();
  private polygonControllers: Map<string, PolygonController> = new Map();
  private circleControllers: Map<string, CircleController> = new Map();
  private groundOverlayControllers: Map<string, GroundOverlayController> = new Map();
  private tileOverlayControllers: Map<string, TileOverlayController> = new Map();
  private heatMapControllers: Map<string, HeatMapController> = new Map();

  /** native marker/polyline/etc id  ->  dart id */
  private nativeToDartId: Map<string, string> = new Map();
  /** dart marker id  ->  whether the marker is clusterable */
  private clusterableMarkers: Map<string, mapCommon.LatLng> = new Map();
  private clusteringEnabled: boolean = false;
  private clusterOverlay: map.ClusterOverlay | null = null;
  private clusterRebuildPending: boolean = false;
  private massPointOverlays: Array<map.MassPointOverlay> = [];
  private massPointIcons: Map<string, image.PixelMap> = new Map();
  private massPointOverlaySequence: number = 0;
  private massPointItemSequence: number = 0;
  private massPointAddQueue: Promise<void> = Promise.resolve();

  private mapController: map.MapComponentController | null = null;
  private context: common.UIAbilityContext | null = null;
  private assetResolver: AssetPathResolver | null = null;

  constructor() {}

  setMethodChannel(channel: MethodChannel): void { this.methodChannel = channel; }
  setMapController(ctrl: map.MapComponentController): void { this.mapController = ctrl; }
  setContext(ctx: common.UIAbilityContext): void { this.context = ctx; }
  setAssetResolver(resolver: AssetPathResolver): void { this.assetResolver = resolver; }

  setClusteringEnabled(enabled: boolean): void {
    this.clusteringEnabled = enabled;
    this.scheduleClusterRebuild();
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (!this.mapController) {
      result.error('ERROR', 'MapUtils not initialized', null);
      return;
    }

    switch (call.method) {
      case Method.MARKERS_UPDATE:
        this.handleMarkerUpdate(call, result);
        break;
      case Method.POLYLINES_UPDATE:
        this.handlePolylineUpdate(call, result);
        break;
      case Method.POLYGONS_UPDATE:
        this.handlePolygonUpdate(call, result);
        break;
      case Method.CIRCLES_UPDATE:
        this.handleCircleUpdate(call, result);
        break;
      case Method.MASS_POINTS_ADD:
        this.handleMassPointsAdd(call, result);
        break;
      case Method.GROUND_OVERLAYS_UPDATE:
        this.handleGroundOverlayUpdate(call, result);
        break;
      case Method.TILE_OVERLAYS_UPDATE:
        this.handleTileOverlayUpdate(call, result);
        break;
      case Method.HEAT_MAPS_UPDATE:
        this.handleHeatMapUpdate(call, result);
        break;
      case Method.MARKERS_SHOW_INFO_WINDOW:
      case Method.MARKERS_HIDE_INFO_WINDOW:
      case Method.MARKERS_IS_INFO_WINDOW_SHOWN:
        this.handleMarkerInfoWindow(call, result);
        break;
      case Method.MARKER_IS_CLUSTERABLE:
        this.handleMarkerIsClusterable(call, result);
        break;
      case Method.MARKER_START_ANIMATION:
        this.handleMarkerAnimation(call, result);
        break;
      case Method.CIRCLE_START_ANIMATION:
        // HarmonyOS MapCircle has no animation API. Silently accept the call.
        result.success(null);
        break;
      case Method.CLEAR_TILE_CACHE:
        // No public API. Acknowledge the call so Dart's Future resolves.
        this.handleClearTileCache(call, result);
        break;
      default:
        result.notImplemented();
    }
  }

  // ====================== Append-only mass points ======================

  private handleMassPointsAdd(call: MethodCall, result: MethodResult): void {
    const args = Convert.normalizeCodecValue(call.args) as Record<string, Object>;
    const rawPoints = args?.[Param.MASS_POINTS];
    if (!Array.isArray(rawPoints) || rawPoints.length === 0) {
      result.success(null);
      return;
    }

    const groupsByStyle: Map<string, MassPointGroup> = new Map();
    (rawPoints as Array<Object>).forEach((rawPoint: Object) => {
      const point = rawPoint as Record<string, Object>;
      const screenRadius = Number(point[Param.SCREEN_RADIUS]);
      const color = Number(point[Param.COLOR]);
      if (!Number.isFinite(screenRadius) || screenRadius <= 0 || !Number.isFinite(color)) {
        return;
      }

      const styleKey = `${screenRadius}:${color}`;
      let group = groupsByStyle.get(styleKey);
      if (!group) {
        group = {
          screenRadius: screenRadius,
          color: color,
          items: []
        };
        groupsByStyle.set(styleKey, group);
      }
      group.items.push({
        itemId: `flutter_mass_point_${this.massPointItemSequence++}`,
        position: Convert.toLatLng(point[Param.CENTER])
      });
    });

    const groups: Array<MassPointGroup> = [];
    groupsByStyle.forEach((group: MassPointGroup) => groups.push(group));
    this.massPointAddQueue = this.massPointAddQueue
      .catch(() => {})
      .then(() => this.addMassPointGroups(groups));
    this.massPointAddQueue
      .then(() => result.success(null))
      .catch((error: Error) => {
        hilog.error(0x0000, TAG, `addMassPoints failed: ${error.message}`);
        result.error('MASS_POINTS_ADD_ERROR', error.message, null);
      });
  }

  private async addMassPointGroups(groups: Array<MassPointGroup>): Promise<void> {
    const controller = this.mapController;
    if (!controller) {
      throw new Error('MapUtils not initialized');
    }

    for (const group of groups) {
      if (group.items.length === 0) {
        continue;
      }
      const icon = await this.getMassPointIcon(group.screenRadius, group.color);
      const overlay = await controller.addMassPointOverlay({
        id: `flutter_mass_overlay_${this.massPointOverlaySequence++}`,
        items: group.items,
        icon: icon,
        anchorU: 0.5,
        anchorV: 0.5
      });
      this.massPointOverlays.push(overlay);
    }
  }

  private async getMassPointIcon(screenRadius: number, color: number): Promise<image.PixelMap> {
    const styleKey = `${screenRadius}:${color}`;
    const cached = this.massPointIcons.get(styleKey);
    if (cached) {
      return cached;
    }

    const pixelRadius = vp2px(screenRadius);
    const diameter = Math.max(1, Math.ceil(pixelRadius * 2));
    const center = (diameter - 1) / 2;
    const pixels = new Uint8Array(diameter * diameter * 4);
    const alpha = (color >>> 24) & 0xFF;
    const red = (color >>> 16) & 0xFF;
    const green = (color >>> 8) & 0xFF;
    const blue = color & 0xFF;

    for (let y = 0; y < diameter; y++) {
      for (let x = 0; x < diameter; x++) {
        const distance = Math.sqrt((x - center) * (x - center) + (y - center) * (y - center));
        const coverage = Math.max(0, Math.min(1, pixelRadius + 0.5 - distance));
        const offset = (y * diameter + x) * 4;
        pixels[offset] = red;
        pixels[offset + 1] = green;
        pixels[offset + 2] = blue;
        pixels[offset + 3] = Math.round(alpha * coverage);
      }
    }

    const icon = await image.createPixelMap(pixels.buffer as ArrayBuffer, {
      size: { width: diameter, height: diameter },
      srcPixelFormat: image.PixelMapFormat.RGBA_8888,
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      alphaType: image.AlphaType.UNPREMUL,
      editable: false
    });
    this.massPointIcons.set(styleKey, icon);
    return icon;
  }

  private handleClearTileCache(call: MethodCall, result: MethodResult): void {
    const args = Convert.normalizeCodecValue(call.args) as Record<string, string>;
    const tileOverlayId = args?.[Param.TILE_OVERLAY_ID] ?? '';
    hilog.warn(
      0x0000,
      TAG,
      `clearTileCache ignored: HarmonyOS MapKit has no public clearTileCache API tileOverlayId=${tileOverlayId}`
    );
    result.success(null);
  }

  // ====================== Marker update ======================

  private handleMarkerUpdate(call: MethodCall, result: MethodResult): void {
    hilog.info(
      0x0000,
      TAG,
      `handleMarkerUpdate rawArgsType=${call.args instanceof Map ? 'Map' : typeof call.args}`
    );
    const args = Convert.normalizeCodecValue(call.args) as Record<string, Object>;
    if (!args) { result.success(null); return; }

    const toInsert = args[Param.MARKERS_TO_INSERT] as Array<Record<string, Object>>;
    const toUpdate = args[Param.MARKERS_TO_UPDATE] as Array<Record<string, Object>>;
    const toDelete = args[Param.MARKERS_TO_DELETE] as Array<string>;
    hilog.info(
      0x0000,
      TAG,
      `handleMarkerUpdate normalizedKeys=${Object.keys(args).join(',')} ` +
      `insert=${Array.isArray(toInsert) ? toInsert.length : 0} ` +
      `update=${Array.isArray(toUpdate) ? toUpdate.length : 0} ` +
      `delete=${Array.isArray(toDelete) ? toDelete.length : 0}`
    );

    const tasks: Array<Promise<void>> = [];
    if (Array.isArray(toInsert)) {
      for (const item of toInsert) {
        hilog.info(0x0000, TAG, `marker insert payload ${describeMarker(item)}`);
        tasks.push(this.addMarker(item));
      }
    }
    if (Array.isArray(toUpdate)) {
      for (const item of toUpdate) {
        const dartId = item[Param.MARKER_ID] as string ?? '';
        hilog.info(0x0000, TAG, `marker update payload ${describeMarker(item)}`);
        const ctrl = this.markerControllers.get(dartId);
        if (ctrl) {
          ctrl.update(item);
          if (item[Param.CLUSTERABLE] !== undefined) {
            const clusterable = item[Param.CLUSTERABLE] as boolean;
            if (clusterable) {
              this.clusterableMarkers.set(dartId, ctrl.getPosition());
            } else {
              this.clusterableMarkers.delete(dartId);
            }
            this.scheduleClusterRebuild();
          } else if (item[Param.POSITION] !== undefined && this.clusterableMarkers.has(dartId)) {
            this.clusterableMarkers.set(dartId, ctrl.getPosition());
            this.scheduleClusterRebuild();
          }
        } else {
          hilog.warn(0x0000, TAG, `marker update ignored: controller not found for dartId=${dartId}`);
        }
      }
    }
    if (Array.isArray(toDelete)) {
      for (const dartId of toDelete) {
        const ctrl = this.markerControllers.get(dartId);
        if (ctrl) {
          const nativeId = ctrl.getNativeId();
          ctrl.delete();
          this.markerControllers.delete(dartId);
          if (nativeId) this.nativeToDartId.delete(nativeId);
          if (this.clusterableMarkers.delete(dartId)) {
            this.scheduleClusterRebuild();
          }
          hilog.info(0x0000, TAG, `marker deleted dartId=${dartId} nativeId=${nativeId}`);
        } else {
          hilog.warn(0x0000, TAG, `marker delete ignored: controller not found for dartId=${dartId}`);
        }
      }
    }
    Promise.all(tasks).then(() => {
      hilog.info(0x0000, TAG, `handleMarkerUpdate completed insertTasks=${tasks.length}`);
      result.success(null);
    }).catch((e: Error) => {
      hilog.warn(0x0000, TAG, `${call.method} batch failed: ${e.message}`);
      result.success(null);
    });
  }

  // ====================== Polyline update ======================

  private handlePolylineUpdate(call: MethodCall, result: MethodResult): void {
    const args = Convert.normalizeCodecValue(call.args) as Record<string, Object>;
    if (!args) { result.success(null); return; }

    const toInsert = args[Param.POLYLINES_TO_INSERT] as Array<Record<string, Object>>;
    const toUpdate = args[Param.POLYLINES_TO_UPDATE] as Array<Record<string, Object>>;
    const toDelete = args[Param.POLYLINES_TO_DELETE] as Array<string>;

    const tasks: Array<Promise<void>> = [];
    if (Array.isArray(toInsert)) {
      for (const item of toInsert) tasks.push(this.addPolyline(item));
    }
    if (Array.isArray(toUpdate)) {
      for (const item of toUpdate) {
        const ctrl = this.polylineControllers.get(item[Param.POLYLINE_ID] as string ?? '');
        if (ctrl) ctrl.update(item);
      }
    }
    if (Array.isArray(toDelete)) {
      for (const id of toDelete) {
        const c = this.polylineControllers.get(id);
        if (c) {
          const nativeId = c.getNativeId();
          c.delete();
          this.polylineControllers.delete(id);
          if (nativeId) this.nativeToDartId.delete(nativeId);
        }
      }
    }
    Promise.all(tasks).then(() => result.success(null)).catch((e: Error) => {
      hilog.warn(0x0000, TAG, `${call.method} batch failed: ${e.message}`);
      result.success(null);
    });
  }

  // ====================== Polygon update ======================

  private handlePolygonUpdate(call: MethodCall, result: MethodResult): void {
    const args = Convert.normalizeCodecValue(call.args) as Record<string, Object>;
    if (!args) { result.success(null); return; }

    const toInsert = args[Param.POLYGONS_TO_INSERT] as Array<Record<string, Object>>;
    const toUpdate = args[Param.POLYGONS_TO_UPDATE] as Array<Record<string, Object>>;
    const toDelete = args[Param.POLYGONS_TO_DELETE] as Array<string>;

    const tasks: Array<Promise<void>> = [];
    if (Array.isArray(toInsert)) {
      for (const item of toInsert) tasks.push(this.addPolygon(item));
    }
    if (Array.isArray(toUpdate)) {
      for (const item of toUpdate) {
        const ctrl = this.polygonControllers.get(item[Param.POLYGON_ID] as string ?? '');
        if (ctrl) ctrl.update(item);
      }
    }
    if (Array.isArray(toDelete)) {
      for (const id of toDelete) {
        const c = this.polygonControllers.get(id);
        if (c) {
          const nativeId = c.getNativeId();
          c.delete();
          this.polygonControllers.delete(id);
          if (nativeId) this.nativeToDartId.delete(nativeId);
        }
      }
    }
    Promise.all(tasks).then(() => result.success(null)).catch((e: Error) => {
      hilog.warn(0x0000, TAG, `${call.method} batch failed: ${e.message}`);
      result.success(null);
    });
  }

  // ====================== Circle update ======================

  private handleCircleUpdate(call: MethodCall, result: MethodResult): void {
    const args = Convert.normalizeCodecValue(call.args) as Record<string, Object>;
    if (!args) { result.success(null); return; }

    const toInsert = args[Param.CIRCLES_TO_INSERT] as Array<Record<string, Object>>;
    const toUpdate = args[Param.CIRCLES_TO_UPDATE] as Array<Record<string, Object>>;
    const toDelete = args[Param.CIRCLES_TO_DELETE] as Array<string>;

    const tasks: Array<Promise<void>> = [];
    if (Array.isArray(toInsert)) {
      for (const item of toInsert) tasks.push(this.addCircle(item));
    }
    if (Array.isArray(toUpdate)) {
      for (const item of toUpdate) {
        const ctrl = this.circleControllers.get(item[Param.CIRCLE_ID] as string ?? '');
        if (ctrl) ctrl.update(item);
      }
    }
    if (Array.isArray(toDelete)) {
      for (const id of toDelete) {
        const c = this.circleControllers.get(id);
        if (c) {
          const nativeId = c.getNativeId();
          c.delete();
          this.circleControllers.delete(id);
          if (nativeId) this.nativeToDartId.delete(nativeId);
        }
      }
    }
    Promise.all(tasks).then(() => result.success(null)).catch((e: Error) => {
      hilog.warn(0x0000, TAG, `${call.method} batch failed: ${e.message}`);
      result.success(null);
    });
  }

  // ====================== GroundOverlay update ======================

  private handleGroundOverlayUpdate(call: MethodCall, result: MethodResult): void {
    const args = Convert.normalizeCodecValue(call.args) as Record<string, Object>;
    if (!args) { result.success(null); return; }

    const toInsert = args[Param.GROUND_OVERLAYS_TO_INSERT] as Array<Record<string, Object>>;
    const toUpdate = args[Param.GROUND_OVERLAYS_TO_UPDATE] as Array<Record<string, Object>>;
    const toDelete = args[Param.GROUND_OVERLAYS_TO_DELETE] as Array<string>;

    const tasks: Array<Promise<void>> = [];
    if (Array.isArray(toInsert)) {
      for (const item of toInsert) tasks.push(this.addGroundOverlay(item));
    }
    if (Array.isArray(toUpdate)) {
      for (const item of toUpdate) {
        const ctrl = this.groundOverlayControllers.get(item[Param.GROUND_OVERLAY_ID] as string ?? '');
        if (ctrl) ctrl.update(item);
      }
    }
    if (Array.isArray(toDelete)) {
      for (const id of toDelete) {
        const c = this.groundOverlayControllers.get(id);
        if (c) {
          const nativeId = c.getNativeId();
          c.delete();
          this.groundOverlayControllers.delete(id);
          if (nativeId) this.nativeToDartId.delete(nativeId);
        }
      }
    }
    Promise.all(tasks).then(() => result.success(null)).catch((e: Error) => {
      hilog.warn(0x0000, TAG, `${call.method} batch failed: ${e.message}`);
      result.success(null);
    });
  }

  // ====================== TileOverlay update ======================

  private handleTileOverlayUpdate(call: MethodCall, result: MethodResult): void {
    const args = Convert.normalizeCodecValue(call.args) as Record<string, Object>;
    if (!args) { result.success(null); return; }

    const toInsert = args[Param.TILE_OVERLAYS_TO_INSERT] as Array<Record<string, Object>>;
    const toUpdate = args[Param.TILE_OVERLAYS_TO_UPDATE] as Array<Record<string, Object>>;
    const toDelete = args[Param.TILE_OVERLAYS_TO_DELETE] as Array<string>;
    hilog.info(
      0x0000,
      TAG,
      `handleTileOverlayUpdate insert=${Array.isArray(toInsert) ? toInsert.length : 0} ` +
      `update=${Array.isArray(toUpdate) ? toUpdate.length : 0} ` +
      `delete=${Array.isArray(toDelete) ? toDelete.length : 0}`
    );

    if (Array.isArray(toInsert)) {
      for (const item of toInsert) {
        hilog.info(0x0000, TAG, `tileOverlay insert payload ${describeTileOverlay(item)}`);
        this.addTileOverlay(item);
      }
    }
    if (Array.isArray(toUpdate)) {
      for (const item of toUpdate) {
        const id = item[Param.TILE_OVERLAY_ID] as string ?? '';
        hilog.info(0x0000, TAG, `tileOverlay update payload ${describeTileOverlay(item)}`);
        const ctrl = this.tileOverlayControllers.get(id);
        if (ctrl) {
          ctrl.update(item);
        } else {
          hilog.warn(0x0000, TAG, `tileOverlay update ignored: controller not found id=${id}`);
        }
      }
    }
    if (Array.isArray(toDelete)) {
      for (const id of toDelete) {
        const c = this.tileOverlayControllers.get(id);
        if (c) {
          const nativeId = c.getNativeId();
          c.delete();
          this.tileOverlayControllers.delete(id);
          if (nativeId) this.nativeToDartId.delete(nativeId);
          hilog.info(0x0000, TAG, `tileOverlay deleted id=${id} nativeId=${nativeId}`);
        } else {
          hilog.warn(0x0000, TAG, `tileOverlay delete ignored: controller not found id=${id}`);
        }
      }
    }
    result.success(null);
  }

  // ====================== HeatMap update ======================

  private handleHeatMapUpdate(call: MethodCall, result: MethodResult): void {
    const args = Convert.normalizeCodecValue(call.args) as Record<string, Object>;
    if (!args) { result.success(null); return; }

    const toInsert = args[Param.HEAT_MAPS_TO_INSERT] as Array<Record<string, Object>>;
    const toUpdate = args[Param.HEAT_MAPS_TO_UPDATE] as Array<Record<string, Object>>;
    const toDelete = args[Param.HEAT_MAPS_TO_DELETE] as Array<string>;

    const tasks: Array<Promise<void>> = [];
    if (Array.isArray(toInsert)) {
      for (const item of toInsert) tasks.push(this.addHeatMap(item));
    }
    if (Array.isArray(toUpdate)) {
      for (const item of toUpdate) {
        const ctrl = this.heatMapControllers.get(item[Param.HEAT_MAP_ID] as string ?? '');
        if (ctrl) ctrl.update(item);
      }
    }
    if (Array.isArray(toDelete)) {
      for (const id of toDelete) {
        const c = this.heatMapControllers.get(id);
        if (c) {
          c.delete();
          this.heatMapControllers.delete(id);
        }
      }
    }
    Promise.all(tasks).then(() => result.success(null)).catch((e: Error) => {
      hilog.warn(0x0000, TAG, `${call.method} batch failed: ${e.message}`);
      result.success(null);
    });
  }

  // ====================== Add helpers ======================

  private async addMarker(data: Record<string, Object>): Promise<void> {
    try {
      const dartId = (data[Param.MARKER_ID] as string) ?? '';
      hilog.info(0x0000, TAG, `addMarker start ${describeMarker(data)}`);
      const opts = Convert.toMarkerOptions(data);
      const iconData = data[Param.ICON];
      if (iconData !== undefined && iconData !== null) {
        if (Convert.isFromBytesIcon(iconData)) {
          hilog.info(0x0000, TAG, `addMarker resolving bytes icon dartId=${dartId} ${describeIcon(iconData)}`);
          const pixelMap = await Convert.fromBytesToPixelMap(iconData);
          if (pixelMap) {
            opts.icon = pixelMap;
            hilog.info(0x0000, TAG, `addMarker bytes icon resolved dartId=${dartId}`);
          } else {
            hilog.warn(0x0000, TAG, `addMarker bytes icon unresolved dartId=${dartId}`);
          }
        } else if (Convert.isFromAssetIcon(iconData) && this.context && this.assetResolver) {
          const ref = Convert.parseAssetIcon(iconData);
          if (ref) {
            const path = this.assetResolver(ref.assetName, ref.packageName);
            hilog.info(0x0000, TAG, `addMarker resolving asset icon dartId=${dartId} asset=${ref.assetName} path=${path}`);
            const pixelMap = await Convert.fromAssetToPixelMap(this.context, path);
            if (pixelMap) {
              opts.icon = pixelMap;
              hilog.info(0x0000, TAG, `addMarker asset icon resolved dartId=${dartId}`);
            } else {
              hilog.warn(0x0000, TAG, `addMarker asset icon unresolved dartId=${dartId} path=${path}`);
            }
          }
        } else {
          hilog.info(0x0000, TAG, `addMarker using default marker icon dartId=${dartId} ${describeIcon(iconData)}`);
        }
      }
      hilog.info(
        0x0000,
        TAG,
        `addMarker calling MapKit dartId=${dartId} position=${JSON.stringify(opts.position)} ` +
        `hasIcon=${opts.icon !== undefined} clickable=${String(opts.clickable)} visible=${String(opts.visible)}`
      );
      const marker = await this.mapController!.addMarker(opts);
      const id = dartId.length > 0 ? dartId : (marker.getId() ?? `m_${Date.now()}`);
      this.markerControllers.set(id, new MarkerController(marker, this.context, this.assetResolver));
      const nativeId = marker.getId() ?? '';
      if (nativeId) this.nativeToDartId.set(nativeId, id);
      hilog.info(
        0x0000,
        TAG,
        `addMarker success dartId=${id} nativeId=${nativeId} totalMarkers=${this.markerControllers.size}`
      );

      // Apply animation immediately after creation (Dart sends Param.ANIMATION inline).
      const animRaw = data[Param.ANIMATION];
      if (animRaw !== undefined && animRaw !== null) {
        // Reuse update() path so the JSON-string decode happens in one place.
        const animOnly: Record<string, Object> = {};
        animOnly[Param.ANIMATION] = animRaw;
        this.markerControllers.get(id)!.update(animOnly);
      }

      if ((data[Param.CLUSTERABLE] as boolean) === true) {
        this.clusterableMarkers.set(id, opts.position);
        hilog.info(0x0000, TAG, `addMarker clusterable registered dartId=${id} clusterableCount=${this.clusterableMarkers.size}`);
        this.scheduleClusterRebuild();
      }
    } catch (e) {
      hilog.error(0x0000, TAG, `addMarker error: ${e}`);
    }
  }

  private async addPolyline(data: Record<string, Object>): Promise<void> {
    try {
      const dartId = (data[Param.POLYLINE_ID] as string) ?? '';
      const opts = Convert.toPolylineOptions(data);
      const pl = await this.mapController!.addPolyline(opts);
      const id = dartId.length > 0 ? dartId : (pl.getId() ?? `pl_${Date.now()}`);
      this.polylineControllers.set(id, new PolylineController(pl));
      const nativeId = pl.getId() ?? '';
      if (nativeId) this.nativeToDartId.set(nativeId, id);
    } catch (e) {
      hilog.error(0x0000, TAG, `addPolyline error: ${e}`);
    }
  }

  private async addPolygon(data: Record<string, Object>): Promise<void> {
    try {
      const dartId = (data[Param.POLYGON_ID] as string) ?? '';
      const opts = Convert.toPolygonOptions(data);
      const pg = await this.mapController!.addPolygon(opts);
      const id = dartId.length > 0 ? dartId : (pg.getId() ?? `pg_${Date.now()}`);
      this.polygonControllers.set(id, new PolygonController(pg));
      const nativeId = pg.getId() ?? '';
      if (nativeId) this.nativeToDartId.set(nativeId, id);
    } catch (e) {
      hilog.error(0x0000, TAG, `addPolygon error: ${e}`);
    }
  }

  private async addCircle(data: Record<string, Object>): Promise<void> {
    try {
      const dartId = (data[Param.CIRCLE_ID] as string) ?? '';
      const opts = Convert.toCircleOptions(data);
      const circle = await this.mapController!.addCircle(opts);
      const id = dartId.length > 0 ? dartId : (circle.getId() ?? `c_${Date.now()}`);
      this.circleControllers.set(id, new CircleController(circle));
      const nativeId = circle.getId() ?? '';
      if (nativeId) this.nativeToDartId.set(nativeId, id);
    } catch (e) {
      hilog.error(0x0000, TAG, `addCircle error: ${e}`);
    }
  }

  private async addGroundOverlay(data: Record<string, Object>): Promise<void> {
    try {
      const dartId = (data[Param.GROUND_OVERLAY_ID] as string) ?? '';
      const opts = Convert.toImageOverlayParams(data);

      // Resolve the image up-front so addImageOverlay has something usable.
      const iconData = data[Param.IMAGE_DESCRIPTOR];
      if (iconData !== undefined && iconData !== null) {
        if (Convert.isFromBytesIcon(iconData)) {
          const pixelMap = await Convert.fromBytesToPixelMap(iconData);
          if (pixelMap) opts.image = pixelMap;
        } else if (Convert.isFromAssetIcon(iconData) && this.context && this.assetResolver) {
          const ref = Convert.parseAssetIcon(iconData);
          if (ref) {
            const path = this.assetResolver(ref.assetName, ref.packageName);
            const pixelMap = await Convert.fromAssetToPixelMap(this.context, path);
            if (pixelMap) opts.image = pixelMap;
          }
        }
      }
      if (opts.image === '' || opts.image === undefined || opts.image === null) {
        hilog.warn(0x0000, TAG, `addGroundOverlay: image could not be resolved, skipping ${dartId}`);
        return;
      }
      const go = await this.mapController!.addImageOverlay(opts);
      const id = dartId.length > 0 ? dartId : `go_${Date.now()}`;
      this.groundOverlayControllers.set(id, new GroundOverlayController(go, this.context, this.assetResolver));
      const nativeId = go.getId() ?? '';
      if (nativeId) this.nativeToDartId.set(nativeId, id);
    } catch (e) {
      hilog.error(0x0000, TAG, `addGroundOverlay error: ${e}`);
    }
  }

  private addTileOverlay(data: Record<string, Object>): void {
    try {
      const dartId = (data[Param.TILE_OVERLAY_ID] as string) ?? '';
      hilog.info(0x0000, TAG, `addTileOverlay start ${describeTileOverlay(data)}`);
      const opts = Convert.toTileOverlayOptions(data);
      if (!opts.tileUrl || String(opts.tileUrl).length === 0) {
        hilog.warn(0x0000, TAG, `addTileOverlay skipped unsupported provider id=${dartId}`);
        return;
      }
      hilog.info(
        0x0000,
        TAG,
        `addTileOverlay calling MapKit id=${dartId} tileUrl=${String(opts.tileUrl ?? '')} ` +
        `visible=${String(opts.visible)} fadeIn=${String(opts.fadeIn)} zIndex=${String(opts.zIndex)}`
      );
      const to = this.mapController!.addTileOverlay(opts);
      const id = dartId.length > 0 ? dartId : `to_${Date.now()}`;
      this.tileOverlayControllers.set(id, new TileOverlayController(to));
      const nativeId = to.getId() ?? '';
      if (nativeId) this.nativeToDartId.set(nativeId, id);
      hilog.info(0x0000, TAG, `addTileOverlay success id=${id} nativeId=${nativeId} total=${this.tileOverlayControllers.size}`);
    } catch (e) {
      hilog.error(0x0000, TAG, `addTileOverlay error: ${e}`);
    }
  }

  private async addHeatMap(data: Record<string, Object>): Promise<void> {
    try {
      const dartId = (data[Param.HEAT_MAP_ID] as string) ?? '';
      const opts = Convert.toHeatMapOptions(data);
      const hm = await this.mapController!.addHeatmap(opts);
      const id = dartId.length > 0 ? dartId : `hm_${Date.now()}`;
      this.heatMapControllers.set(id, new HeatMapController(hm, id));
    } catch (e) {
      hilog.error(0x0000, TAG, `addHeatMap error: ${e}`);
    }
  }

  // ====================== Init from creationParams ======================

  async initMarkers(markers: Array<Record<string, Object>>): Promise<void> {
    for (const m of markers) await this.addMarker(m);
  }
  async initPolylines(polylines: Array<Record<string, Object>>): Promise<void> {
    for (const p of polylines) await this.addPolyline(p);
  }
  async initPolygons(polygons: Array<Record<string, Object>>): Promise<void> {
    for (const p of polygons) await this.addPolygon(p);
  }
  async initCircles(circles: Array<Record<string, Object>>): Promise<void> {
    for (const c of circles) await this.addCircle(c);
  }
  async initGroundOverlays(overlays: Array<Record<string, Object>>): Promise<void> {
    for (const o of overlays) await this.addGroundOverlay(o);
  }
  async initTileOverlays(overlays: Array<Record<string, Object>>): Promise<void> {
    for (const o of overlays) this.addTileOverlay(o);
  }
  async initHeatMaps(heatMaps: Array<Record<string, Object>>): Promise<void> {
    for (const h of heatMaps) await this.addHeatMap(h);
  }

  // ====================== InfoWindow / Animation handlers ======================

  private handleMarkerInfoWindow(call: MethodCall, result: MethodResult): void {
    const args = Convert.normalizeCodecValue(call.args) as Record<string, string>;
    const markerId = args?.[Param.MARKER_ID];
    if (!markerId) { result.error('ERROR', 'markerId required', null); return; }
    const ctrl = this.markerControllers.get(markerId);
    if (!ctrl) { result.error('NOT_FOUND', `Marker ${markerId} not found`, null); return; }
    switch (call.method) {
      case Method.MARKERS_SHOW_INFO_WINDOW: ctrl.showInfoWindow(); result.success(null); break;
      case Method.MARKERS_HIDE_INFO_WINDOW: ctrl.hideInfoWindow(); result.success(null); break;
      case Method.MARKERS_IS_INFO_WINDOW_SHOWN: result.success(ctrl.isInfoWindowShown()); break;
      default: result.notImplemented();
    }
  }

  private handleMarkerIsClusterable(call: MethodCall, result: MethodResult): void {
    const args = Convert.normalizeCodecValue(call.args) as Record<string, string>;
    const markerId = args?.[Param.MARKER_ID] ?? '';
    result.success(this.clusterableMarkers.has(markerId));
  }

  private handleMarkerAnimation(call: MethodCall, result: MethodResult): void {
    const args = Convert.normalizeCodecValue(call.args) as Record<string, string>;
    const mid = args?.[Param.MARKER_ID];
    hilog.info(0x0000, TAG, `handleMarkerAnimation markerId=${String(mid ?? '')}`);
    if (mid && this.markerControllers.has(mid)) {
      this.markerControllers.get(mid)!.startAnimation();
    } else {
      hilog.warn(0x0000, TAG, `handleMarkerAnimation ignored: controller not found markerId=${String(mid ?? '')}`);
    }
    result.success(null);
  }

  // ====================== Clustering ======================

  /**
   * Debounce cluster overlay rebuilds so a batch of marker updates results in
   * a single addClusterOverlay call rather than one per marker.
   */
  private scheduleClusterRebuild(): void {
    if (this.clusterRebuildPending) return;
    this.clusterRebuildPending = true;
    Promise.resolve().then(() => {
      this.clusterRebuildPending = false;
      this.rebuildClusterOverlay();
    });
  }

  private rebuildClusterOverlay(): void {
    if (!this.mapController) return;
    // Remove any previous cluster overlay before re-adding.
    if (this.clusterOverlay) {
      try { this.clusterOverlay.remove(); } catch (e) { /* ignore */ }
      this.clusterOverlay = null;
    }
    if (!this.clusteringEnabled || this.clusterableMarkers.size === 0) return;

    const items: Array<mapCommon.ClusterItem> = [];
    this.clusterableMarkers.forEach((pos: mapCommon.LatLng) => {
      // ClusterItem is abstract; the API accepts any { position: LatLng } shape.
      const item = { position: pos } as mapCommon.ClusterItem;
      items.push(item);
    });

    const params: mapCommon.ClusterOverlayParams = {
      clusterItems: items,
      distance: 50
    };
    this.mapController.addClusterOverlay(params)
      .then((overlay: map.ClusterOverlay) => {
        this.clusterOverlay = overlay;
        hilog.info(0x0000, TAG, `ClusterOverlay rebuilt with ${items.length} items`);
      })
      .catch((e: Error) => {
        hilog.warn(0x0000, TAG, `addClusterOverlay failed: ${e.message}`);
      });
  }

  // ====================== Lookup helpers (used by listener handler) ======================

  findDartIdByMarkerRef(marker: map.Marker): string {
    const nativeId = marker.getId() ?? '';
    return this.nativeToDartId.get(nativeId) ?? nativeId;
  }

  findDartIdByPolylineRef(polyline: map.MapPolyline): string {
    const nativeId = polyline.getId() ?? '';
    return this.nativeToDartId.get(nativeId) ?? nativeId;
  }

  findDartIdByPolygonRef(polygon: map.MapPolygon): string {
    const nativeId = polygon.getId() ?? '';
    return this.nativeToDartId.get(nativeId) ?? nativeId;
  }

  findDartIdByCircleRef(circle: map.MapCircle): string {
    const nativeId = circle.getId() ?? '';
    return this.nativeToDartId.get(nativeId) ?? nativeId;
  }

  findDartIdByImageOverlayRef(overlay: map.ImageOverlay): string {
    const nativeId = overlay.getId() ?? '';
    return this.nativeToDartId.get(nativeId) ?? nativeId;
  }

  getCameraPosition(): mapCommon.CameraPosition | null {
    if (!this.mapController) return null;
    try { return this.mapController.getCameraPosition(); } catch (e) {
      hilog.error(0x0000, TAG, `getCameraPosition failed: ${e}`);
      return null;
    }
  }

  dispose(): void {
    this.massPointOverlays.forEach((overlay: map.MassPointOverlay) => {
      try { overlay.remove(); } catch (e) { /* ignore */ }
    });
    this.massPointOverlays = [];
    this.massPointIcons.forEach((icon: image.PixelMap) => {
      icon.release().catch(() => {});
    });
    this.massPointIcons.clear();

    if (this.clusterOverlay) {
      try { this.clusterOverlay.remove(); } catch (e) { /* ignore */ }
      this.clusterOverlay = null;
    }
    this.markerControllers.forEach(c => c.delete());
    this.polylineControllers.forEach(c => c.delete());
    this.polygonControllers.forEach(c => c.delete());
    this.circleControllers.forEach(c => c.delete());
    this.groundOverlayControllers.forEach(c => c.delete());
    this.tileOverlayControllers.forEach(c => c.delete());
    this.heatMapControllers.forEach(c => c.delete());

    this.markerControllers.clear();
    this.polylineControllers.clear();
    this.polygonControllers.clear();
    this.circleControllers.clear();
    this.groundOverlayControllers.clear();
    this.tileOverlayControllers.clear();
    this.heatMapControllers.clear();
    this.nativeToDartId.clear();
    this.clusterableMarkers.clear();

    this.mapController = null;
    this.methodChannel = null;
  }
}
