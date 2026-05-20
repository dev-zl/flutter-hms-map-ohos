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
 * MapListenerHandler - bridges native MapEventManager events to Dart
 * via the per-map MethodChannel.
 *
 * Dart side (lib/src/channel/huawei_map_method_channel.dart) expects:
 *   args is a Map<String, dynamic> (not a positional list) for most events.
 *   exception: '[Map]onMyLocationButtonClick' sends a raw bool directly.
 */

import { MethodChannel } from '@ohos/flutter_ohos';
import { map, mapCommon } from '@kit.MapKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { Method } from './constants/Method';
import { Param } from './constants/Param';
import { ToJson } from './utils/ToJson';
import { MapUtils } from './mapMapUtils';

const TAG: string = '[MapListener]';

type VoidEventName = 'cameraMove' | 'cameraIdle' | 'cameraMoveCancel' | 'myLocationButtonClick';
type MarkerEventName = 'markerClick' | 'markerDragStart' | 'markerDrag' | 'markerDragEnd' | 'infoWindowClick' | 'infoWindowClose';
type LatLngEventName = 'mapClick' | 'mapLongClick' | 'myLocationClick';

export class MapListenerHandler {
  private readonly mapId: number;
  private readonly mapUtils: MapUtils;
  private readonly channel: MethodChannel;
  private trackCameraPosition: boolean = false;
  private eventManager: map.MapEventManager | null = null;

  // Keep references to the listener callbacks so we can off() them on dispose.
  private listeners: Array<EventBinding> = [];

  constructor(mapId: number, mapUtils: MapUtils, channel: MethodChannel) {
    this.mapId = mapId;
    this.mapUtils = mapUtils;
    this.channel = channel;
  }

  init(eventManager: map.MapEventManager): void {
    this.eventManager = eventManager;
    hilog.info(0x0000, TAG, `Initializing event listeners for map ${this.mapId}`);

    // ---------- Camera ----------
    this.bindCb('cameraMoveStart', (reason: number) => {
      const args: Record<string, Object> = {};
      args[Param.REASON] = reason;
      this.invokeMethod(Method.CAMERA_ON_MOVE_STARTED, args);
    });

    this.bindVoid('cameraMove', () => {
      if (!this.trackCameraPosition) return;
      try {
        const cp = this.mapUtils.getCameraPosition();
        if (cp) {
          const args: Record<string, Object> = {};
          args[Param.POSITION] = ToJson.cameraPosition(cp);
          this.invokeMethod(Method.CAMERA_ON_MOVE, args);
        }
      } catch (e) {
        hilog.warn(0x0000, TAG, `cameraMove getCameraPosition failed: ${e}`);
      }
    });

    this.bindVoid('cameraIdle', () => {
      this.invokeMethod(Method.CAMERA_ON_IDLE, null);
    });

    this.bindVoid('cameraMoveCancel', () => {
      this.invokeMethod(Method.CAMERA_ON_MOVE_CANCELED, null);
    });

    // ---------- Marker ----------
    this.bindMarker('markerClick', (marker: map.Marker) => {
      const args: Record<string, Object> = {};
      args[Param.MARKER_ID] = this.mapUtils.findDartIdByMarkerRef(marker);
      this.invokeMethod(Method.MARKER_CLICK, args);
    });

    this.bindMarker('markerDragStart', (marker: map.Marker) => {
      const args: Record<string, Object> = {};
      args[Param.MARKER_ID] = this.mapUtils.findDartIdByMarkerRef(marker);
      args[Param.POSITION] = ToJson.latLng(marker.getPosition());
      this.invokeMethod(Method.MARKER_ON_DRAG_START, args);
    });

    this.bindMarker('markerDrag', (marker: map.Marker) => {
      const args: Record<string, Object> = {};
      args[Param.MARKER_ID] = this.mapUtils.findDartIdByMarkerRef(marker);
      args[Param.POSITION] = ToJson.latLng(marker.getPosition());
      this.invokeMethod(Method.MARKER_ON_DRAG, args);
    });

    this.bindMarker('markerDragEnd', (marker: map.Marker) => {
      const args: Record<string, Object> = {};
      args[Param.MARKER_ID] = this.mapUtils.findDartIdByMarkerRef(marker);
      args[Param.POSITION] = ToJson.latLng(marker.getPosition());
      this.invokeMethod(Method.MARKER_ON_DRAG_END, args);
    });

    // ---------- InfoWindow ----------
    this.bindMarker('infoWindowClick', (marker: map.Marker) => {
      const args: Record<string, Object> = {};
      args[Param.MARKER_ID] = this.mapUtils.findDartIdByMarkerRef(marker);
      this.invokeMethod(Method.INFO_WINDOW_CLICK, args);
    });

    this.bindMarker('infoWindowClose', (marker: map.Marker) => {
      const args: Record<string, Object> = {};
      args[Param.MARKER_ID] = this.mapUtils.findDartIdByMarkerRef(marker);
      this.invokeMethod(Method.INFO_WINDOW_CLOSE, args);
    });

    // NOTE: HarmonyOS MapKit (see @hms.core.map.map.d.ts) only exposes
    // `infoWindowClick` and `infoWindowClose` event types. There is no
    // `infoWindowLongClick`, so Dart's onInfoWindowLongClick stream will
    // simply never fire on OHOS — there is nothing to bind here.

    // ---------- Overlay clicks ----------
    this.bindPolyline('polylineClick', (polyline: map.MapPolyline) => {
      const args: Record<string, Object> = {};
      args[Param.POLYLINE_ID] = this.mapUtils.findDartIdByPolylineRef(polyline);
      this.invokeMethod(Method.POLYLINE_CLICK, args);
    });

    this.bindPolygon('polygonClick', (polygon: map.MapPolygon) => {
      const args: Record<string, Object> = {};
      args[Param.POLYGON_ID] = this.mapUtils.findDartIdByPolygonRef(polygon);
      this.invokeMethod(Method.POLYGON_CLICK, args);
    });

    this.bindCircle('circleClick', (circle: map.MapCircle) => {
      const args: Record<string, Object> = {};
      args[Param.CIRCLE_ID] = this.mapUtils.findDartIdByCircleRef(circle);
      this.invokeMethod(Method.CIRCLE_CLICK, args);
    });

    this.bindImageOverlay('imageOverlayClick', (overlay: map.ImageOverlay) => {
      const args: Record<string, Object> = {};
      args[Param.GROUND_OVERLAY_ID] = this.mapUtils.findDartIdByImageOverlayRef(overlay);
      this.invokeMethod(Method.GROUND_OVERLAY_CLICK, args);
    });

    // ---------- Map clicks / POI / location ----------
    this.bindLatLng('mapClick', (latLng: mapCommon.LatLng) => {
      const args: Record<string, Object> = {};
      args[Param.POSITION] = ToJson.latLng(latLng);
      this.invokeMethod(Method.MAP_CLICK, args);
    });

    this.bindLatLng('mapLongClick', (latLng: mapCommon.LatLng) => {
      const args: Record<string, Object> = {};
      args[Param.POSITION] = ToJson.latLng(latLng);
      this.invokeMethod(Method.MAP_ON_LONG_PRESS, args);
    });

    this.bindPoi('poiClick', (poi: mapCommon.Poi) => {
      const poiData: Record<string, Object> = {};
      poiData[Param.NAME] = poi.name ?? '';
      poiData[Param.PLACE_ID] = poi.id ?? '';
      poiData[Param.LAT_LNG] = ToJson.latLng(poi.position ?? { latitude: 0, longitude: 0 });
      const args: Record<string, Object> = {};
      args[Param.POI] = poiData;
      this.invokeMethod(Method.MAP_ON_POI_CLICK, args);
    });

    this.bindLatLng('myLocationClick', (latLng: mapCommon.LatLng) => {
      const locationData: Record<string, Object> = {};
      locationData[Param.LATITUDE] = latLng.latitude;
      locationData[Param.LONGITUDE] = latLng.longitude;
      const args: Record<string, Object> = {};
      args[Param.LOCATION] = locationData;
      this.invokeMethod(Method.MAP_ON_MY_LOCATION_CLICK, args);
    });

    this.bindVoid('myLocationButtonClick', () => {
      // Dart side passes call.arguments directly to LocationButtonClickEvent as
      // the bool flag (huawei_map_method_channel.dart:357), so send true.
      this.invokeMethodRaw(Method.MAP_ON_MY_LOCATION_BUTTON_CLICK, true);
    });

    hilog.info(0x0000, TAG, `Listeners registered for map ${this.mapId}`);
  }

  setTrackCameraPosition(track: boolean): void {
    this.trackCameraPosition = track;
  }

  dispose(): void {
    if (this.eventManager) {
      for (const b of this.listeners) {
        try { b.off(this.eventManager); } catch (e) { /* ignore */ }
      }
    }
    this.listeners = [];
    this.eventManager = null;
    hilog.info(0x0000, TAG, 'MapListenerHandler disposed');
  }

  // ====================== internal helpers ======================

  private invokeMethod(method: string, args: Record<string, Object> | null): void {
    try { this.channel.invokeMethod(method, args); } catch (e) {
      hilog.error(0x0000, TAG, `invokeMethod error for ${method}: ${e}`);
    }
  }

  private invokeMethodRaw(method: string, arg: Object | null | boolean | number): void {
    try { this.channel.invokeMethod(method, arg); } catch (e) {
      hilog.error(0x0000, TAG, `invokeMethod error for ${method}: ${e}`);
    }
  }

  // Per-event-shape binders (kept narrow so we can off() with the right type).

  private bindCb(eventName: 'cameraMoveStart', cb: (reason: number) => void): void {
    this.eventManager!.on('cameraMoveStart', cb);
    this.listeners.push(new CameraStartBinding(eventName, cb));
  }

  private bindVoid(
    eventName: VoidEventName,
    cb: () => void
  ): void {
    switch (eventName) {
      case 'cameraMove':
        this.eventManager!.on('cameraMove', cb);
        break;
      case 'cameraIdle':
        this.eventManager!.on('cameraIdle', cb);
        break;
      case 'cameraMoveCancel':
        this.eventManager!.on('cameraMoveCancel', cb);
        break;
      case 'myLocationButtonClick':
        this.eventManager!.on('myLocationButtonClick', cb);
        break;
    }
    this.listeners.push(new VoidBinding(eventName, cb));
  }

  private bindMarker(
    eventName: MarkerEventName,
    cb: (marker: map.Marker) => void
  ): void {
    switch (eventName) {
      case 'markerClick':
        this.eventManager!.on('markerClick', cb);
        break;
      case 'markerDragStart':
        this.eventManager!.on('markerDragStart', cb);
        break;
      case 'markerDrag':
        this.eventManager!.on('markerDrag', cb);
        break;
      case 'markerDragEnd':
        this.eventManager!.on('markerDragEnd', cb);
        break;
      case 'infoWindowClick':
        this.eventManager!.on('infoWindowClick', cb);
        break;
      case 'infoWindowClose':
        this.eventManager!.on('infoWindowClose', cb);
        break;
    }
    this.listeners.push(new MarkerBinding(eventName, cb));
  }

  private bindPolyline(eventName: 'polylineClick', cb: (p: map.MapPolyline) => void): void {
    this.eventManager!.on('polylineClick', cb);
    this.listeners.push(new PolylineBinding(eventName, cb));
  }

  private bindPolygon(eventName: 'polygonClick', cb: (p: map.MapPolygon) => void): void {
    this.eventManager!.on('polygonClick', cb);
    this.listeners.push(new PolygonBinding(eventName, cb));
  }

  private bindCircle(eventName: 'circleClick', cb: (c: map.MapCircle) => void): void {
    this.eventManager!.on('circleClick', cb);
    this.listeners.push(new CircleBinding(eventName, cb));
  }

  private bindImageOverlay(eventName: 'imageOverlayClick', cb: (o: map.ImageOverlay) => void): void {
    try {
      this.eventManager!.on('imageOverlayClick', cb);
      this.listeners.push(new ImageOverlayBinding(eventName, cb));
    } catch (e) {
      hilog.warn(0x0000, TAG, `bindImageOverlay failed (event not supported?): ${e}`);
    }
  }

  private bindLatLng(eventName: LatLngEventName, cb: (l: mapCommon.LatLng) => void): void {
    switch (eventName) {
      case 'mapClick':
        this.eventManager!.on('mapClick', cb);
        break;
      case 'mapLongClick':
        this.eventManager!.on('mapLongClick', cb);
        break;
      case 'myLocationClick':
        this.eventManager!.on('myLocationClick', cb);
        break;
    }
    this.listeners.push(new LatLngBinding(eventName, cb));
  }

  private bindPoi(eventName: 'poiClick', cb: (p: mapCommon.Poi) => void): void {
    this.eventManager!.on('poiClick', cb);
    this.listeners.push(new PoiBinding(eventName, cb));
  }
}

// ====================== binding wrappers (for dispose) ======================

abstract class EventBinding {
  abstract off(em: map.MapEventManager): void;
}

class CameraStartBinding extends EventBinding {
  private name: 'cameraMoveStart';
  private cb: (n: number) => void;
  constructor(name: 'cameraMoveStart', cb: (n: number) => void) {
    super();
    this.name = name;
    this.cb = cb;
  }
  off(em: map.MapEventManager): void { em.off('cameraMoveStart', this.cb); }
}
class VoidBinding extends EventBinding {
  private name: VoidEventName;
  private cb: () => void;
  constructor(name: VoidEventName, cb: () => void) {
    super();
    this.name = name;
    this.cb = cb;
  }
  off(em: map.MapEventManager): void {
    switch (this.name) {
      case 'cameraMove':
        em.off('cameraMove', this.cb);
        break;
      case 'cameraIdle':
        em.off('cameraIdle', this.cb);
        break;
      case 'cameraMoveCancel':
        em.off('cameraMoveCancel', this.cb);
        break;
      case 'myLocationButtonClick':
        em.off('myLocationButtonClick', this.cb);
        break;
    }
  }
}
class MarkerBinding extends EventBinding {
  private name: MarkerEventName;
  private cb: (m: map.Marker) => void;
  constructor(name: MarkerEventName, cb: (m: map.Marker) => void) {
    super();
    this.name = name;
    this.cb = cb;
  }
  off(em: map.MapEventManager): void {
    switch (this.name) {
      case 'markerClick':
        em.off('markerClick', this.cb);
        break;
      case 'markerDragStart':
        em.off('markerDragStart', this.cb);
        break;
      case 'markerDrag':
        em.off('markerDrag', this.cb);
        break;
      case 'markerDragEnd':
        em.off('markerDragEnd', this.cb);
        break;
      case 'infoWindowClick':
        em.off('infoWindowClick', this.cb);
        break;
      case 'infoWindowClose':
        em.off('infoWindowClose', this.cb);
        break;
    }
  }
}
class PolylineBinding extends EventBinding {
  private name: 'polylineClick';
  private cb: (p: map.MapPolyline) => void;
  constructor(name: 'polylineClick', cb: (p: map.MapPolyline) => void) {
    super();
    this.name = name;
    this.cb = cb;
  }
  off(em: map.MapEventManager): void { em.off('polylineClick', this.cb); }
}
class PolygonBinding extends EventBinding {
  private name: 'polygonClick';
  private cb: (p: map.MapPolygon) => void;
  constructor(name: 'polygonClick', cb: (p: map.MapPolygon) => void) {
    super();
    this.name = name;
    this.cb = cb;
  }
  off(em: map.MapEventManager): void { em.off('polygonClick', this.cb); }
}
class CircleBinding extends EventBinding {
  private name: 'circleClick';
  private cb: (c: map.MapCircle) => void;
  constructor(name: 'circleClick', cb: (c: map.MapCircle) => void) {
    super();
    this.name = name;
    this.cb = cb;
  }
  off(em: map.MapEventManager): void { em.off('circleClick', this.cb); }
}
class ImageOverlayBinding extends EventBinding {
  private name: 'imageOverlayClick';
  private cb: (o: map.ImageOverlay) => void;
  constructor(name: 'imageOverlayClick', cb: (o: map.ImageOverlay) => void) {
    super();
    this.name = name;
    this.cb = cb;
  }
  off(em: map.MapEventManager): void { em.off('imageOverlayClick', this.cb); }
}
class LatLngBinding extends EventBinding {
  private name: LatLngEventName;
  private cb: (l: mapCommon.LatLng) => void;
  constructor(name: LatLngEventName, cb: (l: mapCommon.LatLng) => void) {
    super();
    this.name = name;
    this.cb = cb;
  }
  off(em: map.MapEventManager): void {
    switch (this.name) {
      case 'mapClick':
        em.off('mapClick', this.cb);
        break;
      case 'mapLongClick':
        em.off('mapLongClick', this.cb);
        break;
      case 'myLocationClick':
        em.off('myLocationClick', this.cb);
        break;
    }
  }
}
class PoiBinding extends EventBinding {
  private name: 'poiClick';
  private cb: (p: mapCommon.Poi) => void;
  constructor(name: 'poiClick', cb: (p: mapCommon.Poi) => void) {
    super();
    this.name = name;
    this.cb = cb;
  }
  off(em: map.MapEventManager): void { em.off('poiClick', this.cb); }
}
