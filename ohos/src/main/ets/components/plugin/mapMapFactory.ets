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
 * MapFactory - HarmonyOS PlatformViewFactory implementation.
 *
 * Flutter's PlatformViewsController calls create(context, viewId, args) when
 * Dart-side widget mounts. We:
 *   1. Build a HmsMap PlatformView (renders MapComponent under the hood).
 *   2. Once the MapComponentController is ready, wire it to a MapController
 *      which owns the per-map MethodChannel + listener handler + overlays.
 *   3. Apply initial camera position + initial markers/polylines/...
 */

import {
  MethodChannel,
  MethodCall,
  MethodResult,
  MethodCallHandler,
  BinaryMessenger,
  StandardMethodCodec,
  StandardMessageCodec,
  PlatformViewFactory,
  PlatformView
} from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { map } from '@kit.MapKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { Channel } from './constants/Channel';
import { Method } from './constants/Method';
import { Param } from './constants/Param';
import { Convert } from './utils/Convert';
import { HmsMap } from './HmsMap';
import { MapController } from './mapMapController';
import { AssetPathResolver } from './mapMapUtils';

const TAG: string = '[MapFactory]';

function normalizeCodecValue(value: Object | null | undefined): Object | null | undefined {
  if (value instanceof Map) {
    const record: Record<string, Object> = {};
    (value as Map<Object, Object>).forEach((mapValue: Object, mapKey: Object) => {
      record[String(mapKey)] = normalizeCodecValue(mapValue) as Object;
    });
    return record;
  }
  if (Array.isArray(value)) {
    return (value as Array<Object>).map((item: Object) => normalizeCodecValue(item) as Object);
  }
  return value;
}

class EarlyMapMethodCallHandler implements MethodCallHandler {
  private readonly viewId: number;
  private readonly onWaitForMap: (result: MethodResult) => void;

  constructor(viewId: number, onWaitForMap: (result: MethodResult) => void) {
    this.viewId = viewId;
    this.onWaitForMap = onWaitForMap;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    hilog.info(0x0000, TAG, `early MethodChannel call id=${this.viewId} method=${call.method}`);
    if (call.method === Method.MAP_WAIT_FOR_MAP) {
      this.onWaitForMap(result);
      return;
    }
    result.error('MAP_NOT_READY', `Map ${this.viewId} is not ready`, null);
  }
}

export class MapFactory extends PlatformViewFactory {
  private context: common.UIAbilityContext;
  private messenger: BinaryMessenger;
  private assetResolver: AssetPathResolver;
  private liveControllers: Map<number, MapController> = new Map();

  constructor(
    context: common.UIAbilityContext,
    messenger: BinaryMessenger,
    assetResolver: AssetPathResolver
  ) {
    super(StandardMessageCodec.INSTANCE);
    this.context = context;
    this.messenger = messenger;
    this.assetResolver = assetResolver;
  }

  /**
   * Called by flutter_ohos when Dart instantiates the platform view. The
   * returned PlatformView must already be self-renderable via getView().
   *
   * We DO NOT block on the MapComponentController here — instead, we return
   * the HmsMap immediately and wire the MethodChannel asynchronously once
   * the controller becomes available. The Dart side calls `[Map]waitForMap`
   * over the channel before doing anything else (see MapMethodChannel.init).
   */
  create(context: common.Context, viewId: number, args: Object): PlatformView {
    hilog.info(0x0000, TAG, `Creating platform view id=${viewId}`);
    const params = (normalizeCodecValue(args) ?? {}) as Record<string, Object>;
    hilog.info(0x0000, TAG, `create args keys=${Object.keys(params).join(',')}`);

    const options = (params[Param.OPTIONS] as Record<string, Object>) ?? {};
    const initialCameraPosition = params[Param.INITIAL_CAMERA_POSITION];
    const initMarkers = params[Param.MARKERS_TO_INSERT] as Array<Record<string, Object>>;
    const initPolylines = params[Param.POLYLINES_TO_INSERT] as Array<Record<string, Object>>;
    const initPolygons = params[Param.POLYGONS_TO_INSERT] as Array<Record<string, Object>>;
    const initCircles = params[Param.CIRCLES_TO_INSERT] as Array<Record<string, Object>>;
    const initGroundOverlays = params[Param.GROUND_OVERLAYS_TO_INSERT] as Array<Record<string, Object>>;
    const initTileOverlays = params[Param.TILE_OVERLAYS_TO_INSERT] as Array<Record<string, Object>>;
    const initHeatMaps = params[Param.HEAT_MAPS_TO_INSERT] as Array<Record<string, Object>>;
    hilog.info(
      0x0000,
      TAG,
      `initial payload id=${viewId} options=${JSON.stringify(options)} camera=${JSON.stringify(initialCameraPosition)} ` +
      `markers=${Array.isArray(initMarkers) ? initMarkers.length : 0} ` +
      `polylines=${Array.isArray(initPolylines) ? initPolylines.length : 0} ` +
      `polygons=${Array.isArray(initPolygons) ? initPolygons.length : 0} ` +
      `circles=${Array.isArray(initCircles) ? initCircles.length : 0}`
    );

    // Build the initial mapOptions including initialCameraPosition (if provided).
    const mapOptions = Convert.toMapOptions(options);
    if (initialCameraPosition) {
      mapOptions.position = Convert.toCameraPosition(initialCameraPosition);
    }
    hilog.info(0x0000, TAG, `converted mapOptions id=${viewId}: ${JSON.stringify(mapOptions)}`);

    const hmsMap = new HmsMap(mapOptions, options[Param.DRAWING_ENABLED] === true);
    hilog.info(0x0000, TAG, `HmsMap instance created id=${viewId}`);
    const channelName = `${Channel.CHANNEL}_${viewId}`;
    const channel = new MethodChannel(this.messenger, channelName, StandardMethodCodec.INSTANCE);
    let pendingWaitForMapResult: MethodResult | null = null;
    channel.setMethodCallHandler(new EarlyMapMethodCallHandler(viewId, (result: MethodResult) => {
      pendingWaitForMapResult = result;
      hilog.info(0x0000, TAG, `queued MAP_WAIT_FOR_MAP until MapComponent is ready id=${viewId}`);
    }));
    hilog.info(0x0000, TAG, `early MethodChannel handler attached ${channelName}`);

    // Wire up the MethodChannel + controller as soon as the MapComponent
    // controller becomes available. We don't await here so the PlatformView
    // can be returned to flutter_ohos immediately.
    hmsMap.waitForMapController().then((nativeCtrl: map.MapComponentController) => {
      hilog.info(0x0000, TAG, `native MapComponentController ready id=${viewId}`);

      const controller = new MapController(viewId, this.context, nativeCtrl, hmsMap, this.assetResolver);
      channel.setMethodCallHandler(controller);
      controller.setMethodChannel(channel);
      hilog.info(0x0000, TAG, `MethodChannel handler attached id=${viewId}`);
      if (pendingWaitForMapResult) {
        pendingWaitForMapResult.success(null);
        pendingWaitForMapResult = null;
        hilog.info(0x0000, TAG, `flushed queued MAP_WAIT_FOR_MAP id=${viewId}`);
      }

      this.liveControllers.set(viewId, controller);

      // Apply any initial overlays. These run in background; the Dart side has
      // a [Map]waitForMap round-trip but does NOT wait for these.
      if (Array.isArray(initMarkers) && initMarkers.length > 0) controller.initMarkers(initMarkers);
      if (Array.isArray(initPolylines) && initPolylines.length > 0) controller.initPolylines(initPolylines);
      if (Array.isArray(initPolygons) && initPolygons.length > 0) controller.initPolygons(initPolygons);
      if (Array.isArray(initCircles) && initCircles.length > 0) controller.initCircles(initCircles);
      if (Array.isArray(initGroundOverlays) && initGroundOverlays.length > 0) controller.initGroundOverlays(initGroundOverlays);
      if (Array.isArray(initTileOverlays) && initTileOverlays.length > 0) controller.initTileOverlays(initTileOverlays);
      if (Array.isArray(initHeatMaps) && initHeatMaps.length > 0) controller.initHeatMaps(initHeatMaps);

      hilog.info(0x0000, TAG, `MapController ${viewId} wired to channel ${channelName}`);
    }).catch((e: Error) => {
      hilog.error(0x0000, TAG, `Failed to wire MapController ${viewId}: ${e.message}`);
    });

    hilog.info(0x0000, TAG, `Returning HmsMap platform view id=${viewId}`);
    return hmsMap;
  }

  /** Called when the plugin detaches from the engine. */
  disposeAll(): void {
    this.liveControllers.forEach((c, id) => {
      try { c.dispose(); } catch (e) { hilog.warn(0x0000, TAG, `dispose ${id} failed: ${e}`); }
    });
    this.liveControllers.clear();
  }

  disposeController(id: number): void {
    const c = this.liveControllers.get(id);
    if (c) {
      try { c.dispose(); } catch (e) { /* ignore */ }
      this.liveControllers.delete(id);
    }
  }
}
