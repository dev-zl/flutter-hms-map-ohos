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
 * HmsMap - PlatformView wrapper that hosts a HarmonyOS MapComponent and waits
 * for the MapComponentController to become ready.
 *
 * The component is rendered inside Flutter's PlatformView hierarchy via the
 * WrappedBuilder returned from getView(). See mapMapFactory.ets for how this
 * is wired into the Flutter engine.
 */

import { MapComponent, map, mapCommon } from '@kit.MapKit';
import { AsyncCallback } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MethodChannel } from '@ohos/flutter_ohos';
import PlatformView, { Params } from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';
import { Method } from './constants/Method';
import { Param } from './constants/Param';
import { ToJson } from './utils/ToJson';

const TAG: string = '[HmsMap]';

export class HmsMap extends PlatformView {
  private mapOptions: mapCommon.MapOptions;
  private mapCallback: AsyncCallback<map.MapComponentController>;
  private mapController: map.MapComponentController | null = null;
  private readyResolver: ((controller: map.MapComponentController) => void) | null = null;
  private readyRejecter: ((error: Error) => void) | null = null;
  private readonly readyPromise: Promise<map.MapComponentController>;
  private methodChannel: MethodChannel | null = null;
  private drawingEnabled: boolean;
  private drawingPoints: Array<mapCommon.LatLng> = [];
  private lastDrawingPoint: mapCommon.MapPoint | null = null;
  private activeTouchId: number | null = null;

  constructor(mapOptions: mapCommon.MapOptions, drawingEnabled: boolean) {
    super();
    this.mapOptions = mapOptions;
    this.drawingEnabled = drawingEnabled;
    hilog.info(0x0000, TAG, `HmsMap constructor mapOptions=${JSON.stringify(mapOptions)}`);

    this.readyPromise = new Promise<map.MapComponentController>((resolve, reject) => {
      this.readyResolver = resolve;
      this.readyRejecter = reject;
      hilog.info(0x0000, TAG, 'readyPromise created; waiting for MapComponent callback');
    });

    this.mapCallback = (err, controller) => {
      hilog.info(
        0x0000,
        TAG,
        `MapComponent callback received hasError=${!!err} hasController=${!!controller}`
      );
      if (!err && controller) {
        this.mapController = controller;
        this.readyResolver?.(controller);
        this.readyResolver = null;
        this.readyRejecter = null;
        hilog.info(0x0000, TAG, 'MapComponent initialized successfully');
        return;
      }
      const errorText = err ? JSON.stringify(err) : 'unknown error';
      const error = new Error(`MapComponent init failed: ${errorText}`);
      this.readyRejecter?.(error);
      this.readyResolver = null;
      this.readyRejecter = null;
      hilog.error(0x0000, TAG, error.message);
    };
  }

  /** PlatformView contract — return the WrappedBuilder that renders MapComponent. */
  getView(): WrappedBuilder<[Params]> {
    hilog.info(0x0000, TAG, 'getView called; returning HmsMapBuilder');
    return wrapBuilder<[Params]>(HmsMapBuilder);
  }

  /** Used by the @Builder. */
  getMapOptions(): mapCommon.MapOptions { return this.mapOptions; }
  getMapCallback(): AsyncCallback<map.MapComponentController> { return this.mapCallback; }

  getMapController(): map.MapComponentController | null { return this.mapController; }

  setMethodChannel(channel: MethodChannel): void {
    this.methodChannel = channel;
  }

  setDrawingEnabled(enabled: boolean): void {
    if (this.drawingEnabled === enabled) return;
    if (!enabled && this.activeTouchId !== null) {
      this.finishDrawing();
    }
    this.drawingEnabled = enabled;
  }

  handleTouch(event: TouchEvent): void {
    if (!this.drawingEnabled) return;

    try { event.preventDefault(); } catch (e) { /* MapComponent may not expose a default action. */ }
    event.stopPropagation();

    if (event.type === TouchType.Down) {
      if (this.activeTouchId !== null || event.changedTouches.length === 0) {
        this.finishDrawing();
        return;
      }
      const touch = event.changedTouches[0];
      this.drawingPoints = [];
      this.lastDrawingPoint = null;
      this.activeTouchId = touch.id;
      this.appendDrawingPoint(touch, Method.MAP_ON_DRAW_START);
      return;
    }

    const touch = this.findActiveTouch(event);
    if (event.type === TouchType.Move) {
      if (touch) this.appendDrawingPoint(touch, Method.MAP_ON_DRAW_UPDATE);
      return;
    }
    if (event.type === TouchType.Up) {
      if (touch) this.appendDrawingPoint(touch, null);
      this.finishDrawing();
      return;
    }
    if (event.type === TouchType.Cancel) {
      this.finishDrawing();
    }
  }

  private findActiveTouch(event: TouchEvent): TouchObject | null {
    if (this.activeTouchId === null) return null;
    for (let i = 0; i < event.changedTouches.length; i++) {
      if (event.changedTouches[i].id === this.activeTouchId) {
        return event.changedTouches[i];
      }
    }
    for (let i = 0; i < event.touches.length; i++) {
      if (event.touches[i].id === this.activeTouchId) {
        return event.touches[i];
      }
    }
    return null;
  }

  private appendDrawingPoint(touch: TouchObject, eventMethod: string | null): void {
    if (!this.mapController) return;
    const point: mapCommon.MapPoint = {
      positionX: Math.round(vp2px(touch.x)),
      positionY: Math.round(vp2px(touch.y))
    };
    if (this.lastDrawingPoint
      && point.positionX === this.lastDrawingPoint.positionX
      && point.positionY === this.lastDrawingPoint.positionY) {
      return;
    }

    const latLng = this.mapController.getProjection().fromScreenLocation(point);
    if (Number.isNaN(latLng.latitude) || Number.isNaN(latLng.longitude)) return;
    this.drawingPoints.push(latLng);
    this.lastDrawingPoint = point;
    if (eventMethod) {
      const args: Record<string, Object> = {};
      args[Param.POSITION] = ToJson.latLng(latLng);
      this.invokeMethod(eventMethod, args);
    }
  }

  private finishDrawing(): void {
    if (this.drawingPoints.length > 0) {
      const args: Record<string, Object> = {};
      args[Param.POINTS] = ToJson.latLngList(this.drawingPoints);
      this.invokeMethod(Method.MAP_ON_DRAW_END, args);
    }
    this.drawingPoints = [];
    this.lastDrawingPoint = null;
    this.activeTouchId = null;
  }

  private invokeMethod(method: string, args: Record<string, Object>): void {
    try {
      this.methodChannel?.invokeMethod(method, args);
    } catch (e) {
      hilog.warn(0x0000, TAG, `${method} failed: ${e}`);
    }
  }

  /** Resolve once the underlying MapComponent has finished initializing. */
  async waitForMapController(): Promise<map.MapComponentController> {
    if (this.mapController) {
      hilog.info(0x0000, TAG, 'waitForMapController resolved immediately');
      return this.mapController;
    }
    hilog.info(0x0000, TAG, 'waitForMapController waiting for readyPromise');
    return this.readyPromise;
  }

  /** PlatformView lifecycle — flutter_ohos calls dispose on view removal. */
  dispose(): void {
    if (this.readyRejecter) {
      try { this.readyRejecter(new Error('HmsMap disposed before controller was ready')); } catch (e) { /* ignore */ }
      this.readyResolver = null;
      this.readyRejecter = null;
    }
    this.mapController = null;
    this.methodChannel = null;
    this.drawingPoints = [];
    this.activeTouchId = null;
    hilog.info(0x0000, TAG, 'HmsMap disposed');
  }
}

function getHmsMapFromParams(params: Params): HmsMap {
  if (params.platformView instanceof HmsMap) {
    return params.platformView;
  }
  throw new Error('HmsMapBuilder received an unexpected PlatformView');
}

function getMapOptionsFromParams(params: Params): mapCommon.MapOptions {
  return getHmsMapFromParams(params).getMapOptions();
}

function getMapCallbackFromParams(params: Params): AsyncCallback<map.MapComponentController> {
  return getHmsMapFromParams(params).getMapCallback();
}

@Builder
function HmsMapBuilder(params: Params) {
  MapComponent({
    mapOptions: getMapOptionsFromParams(params),
    mapCallback: getMapCallbackFromParams(params)
  })
    .width('100%')
    .height('100%')
    .zIndex(99)
    .onAppear(() => {
      hilog.info(0x0000, TAG, 'MapComponent onAppear');
    })
    .onTouch((event: TouchEvent) => {
      getHmsMapFromParams(params).handleTouch(event);
    })
}
