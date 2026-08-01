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

import { map, mapCommon } from '@kit.MapKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';

import { Param } from './constants/Param';
import { Convert } from './utils/Convert';
import { AnimationConvert } from './animationAnimationConvert';

const TAG: string = '[OverlayController]';

/**
 * Convenience to apply icon updates that may come in three shapes:
 *   ['defaultMarker'(, hue)]
 *   ['fromAsset' | 'fromAssetImage', name(, package|scale)]
 *   ['fromBytes', Uint8List]
 * Returns a Promise so the caller can ignore or await.
 */
async function resolveIcon(
  iconData: Object | undefined | null,
  ctx: common.UIAbilityContext | null,
  assetPathResolver: ((name: string, pkg?: string) => string) | null
): Promise<image.PixelMap | undefined> {
  if (!iconData) return undefined;
  if (Convert.isFromBytesIcon(iconData)) {
    return Convert.fromBytesToPixelMap(iconData);
  }
  if (Convert.isFromAssetIcon(iconData) && ctx && assetPathResolver) {
    const ref = Convert.parseAssetIcon(iconData);
    if (ref) {
      try {
        const path = assetPathResolver(ref.assetName, ref.packageName);
        return Convert.fromAssetToPixelMap(ctx, path);
      } catch (e) {
        hilog.warn(0x0000, TAG, `resolveIcon asset failed: ${e}`);
      }
    }
  }
  return undefined;
}

export class MarkerController {
  private marker: map.Marker;
  private ctx: common.UIAbilityContext | null;
  private assetPathResolver: ((name: string, pkg?: string) => string) | null;

  constructor(
    marker: map.Marker,
    ctx: common.UIAbilityContext | null,
    assetPathResolver: ((name: string, pkg?: string) => string) | null
  ) {
    this.marker = marker;
    this.ctx = ctx;
    this.assetPathResolver = assetPathResolver;
  }

  delete(): void {
    try { this.marker.remove(); } catch (e) { hilog.warn(0x0000, TAG, `marker.remove failed: ${e}`); }
  }

  update(data: Record<string, Object>): void {
    if (data[Param.ALPHA] !== undefined) this.marker.setAlpha(data[Param.ALPHA] as number);
    if (data[Param.ANCHOR] !== undefined) {
      const a = data[Param.ANCHOR] as Array<number>;
      if (Array.isArray(a)) this.marker.setMarkerAnchor(a[0], a[1]);
    }
    if (data[Param.CLICKABLE] !== undefined) this.marker.setClickable(data[Param.CLICKABLE] as boolean);
    if (data[Param.DRAGGABLE] !== undefined) this.marker.setDraggable(data[Param.DRAGGABLE] as boolean);
    if (data[Param.FLAT] !== undefined) this.marker.setFlat(data[Param.FLAT] as boolean);
    if (data[Param.ICON] !== undefined) {
      resolveIcon(data[Param.ICON], this.ctx, this.assetPathResolver).then((pixelMap) => {
        if (pixelMap) {
          this.marker.setIcon(pixelMap).catch((e: Error) => {
            hilog.warn(0x0000, TAG, `marker.setIcon failed: ${e.message}`);
          });
        }
      });
    }
    if (data[Param.POSITION] !== undefined) {
      this.marker.setPosition(Convert.toLatLng(data[Param.POSITION]));
    }
    if (data[Param.ROTATION] !== undefined) this.marker.setRotation(data[Param.ROTATION] as number);
    if (data[Param.TITLE] !== undefined) this.marker.setTitle(data[Param.TITLE] as string);
    if (data[Param.SNIPPET] !== undefined) this.marker.setSnippet(data[Param.SNIPPET] as string);
    if (data[Param.INFO_WINDOW] !== undefined) {
      const iw = data[Param.INFO_WINDOW] as Record<string, Object>;
      if (iw) {
        if (iw[Param.TITLE] !== undefined) this.marker.setTitle(iw[Param.TITLE] as string);
        if (iw[Param.SNIPPET] !== undefined) this.marker.setSnippet(iw[Param.SNIPPET] as string);
        if (iw[Param.ANCHOR] !== undefined) {
          const a = iw[Param.ANCHOR] as Array<number>;
          if (Array.isArray(a)) this.marker.setInfoWindowAnchor(a[0], a[1]);
        }
      }
    }
    if (data[Param.VISIBLE] !== undefined) this.marker.setVisible(data[Param.VISIBLE] as boolean);
    if (data[Param.Z_INDEX] !== undefined) this.marker.setZIndex(data[Param.Z_INDEX] as number);
    if (data[Param.ANIMATION] !== undefined) {
      // Dart sends a JSON STRING here (see lib/src/utils/to_json.dart animationSetToJson).
      const anim = AnimationConvert.decodeAnimationString(data[Param.ANIMATION]);
      if (anim) {
        try {
          this.marker.setAnimation(anim);
          hilog.info(0x0000, TAG, `marker.setAnimation success nativeId=${this.getNativeId()}`);
        } catch (e) {
          hilog.warn(0x0000, TAG, `marker.setAnimation failed: ${e}`);
        }
      } else {
        hilog.warn(0x0000, TAG, `marker.setAnimation skipped: animation decode returned null nativeId=${this.getNativeId()}`);
      }
    }
  }

  startAnimation(): void {
    try {
      hilog.info(0x0000, TAG, `marker.startAnimation nativeId=${this.getNativeId()}`);
      this.marker.startAnimation();
    } catch (e) {
      hilog.warn(0x0000, TAG, `startAnimation failed: ${e}`);
    }
  }

  clearAnimation(): void {}

  showInfoWindow(): void { this.marker.setInfoWindowVisible(true); }
  hideInfoWindow(): void { this.marker.setInfoWindowVisible(false); }
  isInfoWindowShown(): boolean { return this.marker.isInfoWindowVisible(); }

  getMarker(): map.Marker { return this.marker; }
  getNativeId(): string { return this.marker.getId() ?? ''; }
  getPosition(): mapCommon.LatLng { return this.marker.getPosition(); }
}

export class PolylineController {
  private polyline: map.MapPolyline;
  constructor(polyline: map.MapPolyline) { this.polyline = polyline; }

  delete(): void {
    try { this.polyline.remove(); } catch (e) { hilog.warn(0x0000, TAG, `polyline.remove failed: ${e}`); }
  }
  getNativeId(): string { return this.polyline.getId() ?? ''; }

  update(data: Record<string, Object>): void {
    if (data[Param.COLOR] !== undefined) this.polyline.setColor(Convert.toColor(data[Param.COLOR]));
    if (data[Param.WIDTH] !== undefined) {
      this.polyline.setWidth(vp2px(data[Param.WIDTH] as number));
    }
    if (data[Param.POINTS] !== undefined) {
      this.polyline.setPoints(Convert.toLatLngList(data[Param.POINTS] as Array<Object>));
    }
    if (data[Param.END_CAP] !== undefined) this.polyline.setEndCap(Convert.toCapStyle(data[Param.END_CAP]));
    if (data[Param.START_CAP] !== undefined) this.polyline.setStartCap(Convert.toCapStyle(data[Param.START_CAP]));
    if (data[Param.JOINT_TYPE] !== undefined) this.polyline.setJointType(Convert.toJointType(data[Param.JOINT_TYPE] as number));
    if (data[Param.PATTERN] !== undefined) {
      const items = Convert.toPatternItems(data[Param.PATTERN]);
      if (items.length > 0) this.polyline.setPatterns(items);
    }
    if (data[Param.GEODESIC] !== undefined) this.polyline.setGeodesic(data[Param.GEODESIC] as boolean);
    if (data[Param.CLICKABLE] !== undefined) this.polyline.setClickable(data[Param.CLICKABLE] as boolean);
    if (data[Param.VISIBLE] !== undefined) this.polyline.setVisible(data[Param.VISIBLE] as boolean);
    if (data[Param.Z_INDEX] !== undefined) this.polyline.setZIndex(data[Param.Z_INDEX] as number);
    if (data[Param.GRADIENT] !== undefined) this.polyline.setGradient(data[Param.GRADIENT] as boolean);
    if (data[Param.COLOR_VALUES] !== undefined) {
      const colors = data[Param.COLOR_VALUES];
      if (Array.isArray(colors) && (colors as Array<Object>).length > 0) {
        this.polyline.setColors(colors as Array<number>);
      }
    }
  }
}

export class PolygonController {
  private polygon: map.MapPolygon;
  constructor(polygon: map.MapPolygon) { this.polygon = polygon; }

  delete(): void {
    try { this.polygon.remove(); } catch (e) { hilog.warn(0x0000, TAG, `polygon.remove failed: ${e}`); }
  }
  getNativeId(): string { return this.polygon.getId() ?? ''; }

  update(data: Record<string, Object>): void {
    if (data[Param.FILL_COLOR] !== undefined) this.polygon.setFillColor(Convert.toColor(data[Param.FILL_COLOR]));
    if (data[Param.STROKE_COLOR] !== undefined) this.polygon.setStrokeColor(Convert.toColor(data[Param.STROKE_COLOR]));
    if (data[Param.STROKE_WIDTH] !== undefined) this.polygon.setStrokeWidth(data[Param.STROKE_WIDTH] as number);
    if (data[Param.POINTS] !== undefined) {
      this.polygon.setPoints(Convert.toLatLngList(data[Param.POINTS] as Array<Object>));
    }
    if (data[Param.HOLES] !== undefined) {
      const holesArr = data[Param.HOLES] as Array<Object>;
      if (Array.isArray(holesArr)) {
        this.polygon.setHoles(holesArr.map(h => Convert.toLatLngList(h as Array<Object>)));
      }
    }
    if (data[Param.CLICKABLE] !== undefined) this.polygon.setClickable(data[Param.CLICKABLE] as boolean);
    if (data[Param.GEODESIC] !== undefined) this.polygon.setGeodesic(data[Param.GEODESIC] as boolean);
    if (data[Param.VISIBLE] !== undefined) this.polygon.setVisible(data[Param.VISIBLE] as boolean);
    if (data[Param.Z_INDEX] !== undefined) this.polygon.setZIndex(data[Param.Z_INDEX] as number);
    if (data[Param.STROKE_JOINT_TYPE] !== undefined) {
      this.polygon.setJointType(Convert.toJointType(data[Param.STROKE_JOINT_TYPE] as number));
    }
    if (data[Param.STROKE_PATTERN] !== undefined) {
      const items = Convert.toPatternItems(data[Param.STROKE_PATTERN]);
      if (items.length > 0) this.polygon.setPatterns(items);
    }
  }
}

export class CircleController {
  private circle: map.MapCircle;
  constructor(circle: map.MapCircle) { this.circle = circle; }

  delete(): void {
    try { this.circle.remove(); } catch (e) { hilog.warn(0x0000, TAG, `circle.remove failed: ${e}`); }
  }
  getNativeId(): string { return this.circle.getId() ?? ''; }

  update(data: Record<string, Object>): void {
    if (data[Param.CENTER] !== undefined) this.circle.setCenter(Convert.toLatLng(data[Param.CENTER]));
    if (data[Param.RADIUS] !== undefined) this.circle.setRadius(data[Param.RADIUS] as number);
    if (data[Param.FILL_COLOR] !== undefined) this.circle.setFillColor(Convert.toColor(data[Param.FILL_COLOR]));
    if (data[Param.STROKE_COLOR] !== undefined) this.circle.setStrokeColor(Convert.toColor(data[Param.STROKE_COLOR]));
    if (data[Param.STROKE_WIDTH] !== undefined) this.circle.setStrokeWidth(data[Param.STROKE_WIDTH] as number);
    if (data[Param.CLICKABLE] !== undefined) this.circle.setClickable(data[Param.CLICKABLE] as boolean);
    if (data[Param.VISIBLE] !== undefined) this.circle.setVisible(data[Param.VISIBLE] as boolean);
    if (data[Param.Z_INDEX] !== undefined) this.circle.setZIndex(data[Param.Z_INDEX] as number);
    if (data[Param.STROKE_PATTERN] !== undefined) {
      const items = Convert.toPatternItems(data[Param.STROKE_PATTERN]);
      if (items.length > 0) this.circle.setPatterns(items);
    }
    // Dart may send Param.ANIMATION (a JSON string) but Harmony MapCircle does
    // not expose setAnimation; silently ignore.
  }
}

export class GroundOverlayController {
  private overlay: map.ImageOverlay;
  private ctx: common.UIAbilityContext | null;
  private assetPathResolver: ((name: string, pkg?: string) => string) | null;

  constructor(
    overlay: map.ImageOverlay,
    ctx: common.UIAbilityContext | null,
    assetPathResolver: ((name: string, pkg?: string) => string) | null
  ) {
    this.overlay = overlay;
    this.ctx = ctx;
    this.assetPathResolver = assetPathResolver;
  }

  delete(): void {
    try { this.overlay.remove(); } catch (e) { hilog.warn(0x0000, TAG, `imageOverlay.remove failed: ${e}`); }
  }
  getNativeId(): string { return this.overlay.getId() ?? ''; }

  update(data: Record<string, Object>): void {
    if (data[Param.BEARING] !== undefined) this.overlay.setBearing(data[Param.BEARING] as number);
    if (data[Param.CLICKABLE] !== undefined) this.overlay.setClickable(data[Param.CLICKABLE] as boolean);
    if (data[Param.IMAGE_DESCRIPTOR] !== undefined) {
      resolveIcon(data[Param.IMAGE_DESCRIPTOR], this.ctx, this.assetPathResolver).then((pixelMap) => {
        if (pixelMap) {
          this.overlay.setImage(pixelMap).catch((e: Error) => {
            hilog.warn(0x0000, TAG, `imageOverlay.setImage failed: ${e.message}`);
          });
        }
      });
    }
    if (data[Param.POSITION] !== undefined && data[Param.WIDTH] !== undefined) {
      this.overlay.setPosition(Convert.toLatLng(data[Param.POSITION]));
      const w = data[Param.WIDTH] as number;
      const h = (data[Param.HEIGHT] as number) ?? w;
      this.overlay.setDimensions(w, h);
    }
    if (data[Param.BOUNDS] !== undefined) {
      this.overlay.setBounds(Convert.toLatLngBounds(data[Param.BOUNDS]));
    }
    if (data[Param.TRANSPARENCY] !== undefined) this.overlay.setTransparency(data[Param.TRANSPARENCY] as number);
    if (data[Param.VISIBLE] !== undefined) this.overlay.setVisible(data[Param.VISIBLE] as boolean);
    if (data[Param.Z_INDEX] !== undefined) this.overlay.setZIndex(data[Param.Z_INDEX] as number);
  }
}

export class TileOverlayController {
  private tileOverlay: map.TileOverlay;
  constructor(tileOverlay: map.TileOverlay) { this.tileOverlay = tileOverlay; }

  delete(): void {
    try { this.tileOverlay.remove(); } catch (e) { hilog.warn(0x0000, TAG, `tileOverlay.remove failed: ${e}`); }
  }
  getNativeId(): string { return this.tileOverlay.getId() ?? ''; }

  update(data: Record<string, Object>): void {
    if (data[Param.FADE_IN] !== undefined) {
      this.tileOverlay.setFadeIn(data[Param.FADE_IN] as boolean);
      hilog.info(0x0000, TAG, `tileOverlay.setFadeIn nativeId=${this.getNativeId()} value=${String(data[Param.FADE_IN])}`);
    }
    if (data[Param.VISIBLE] !== undefined) {
      this.tileOverlay.setVisible(data[Param.VISIBLE] as boolean);
      hilog.info(0x0000, TAG, `tileOverlay.setVisible nativeId=${this.getNativeId()} value=${String(data[Param.VISIBLE])}`);
    }
    if (data[Param.Z_INDEX] !== undefined) {
      this.tileOverlay.setZIndex(data[Param.Z_INDEX] as number);
      hilog.info(0x0000, TAG, `tileOverlay.setZIndex nativeId=${this.getNativeId()} value=${String(data[Param.Z_INDEX])}`);
    }
    if (data[Param.TRANSPARENCY] !== undefined) {
      hilog.warn(0x0000, TAG, `tileOverlay transparency update ignored: no runtime setter nativeId=${this.getNativeId()}`);
    }
  }
}

export class HeatMapController {
  private heatMap: map.Heatmap;
  private dartId: string;
  constructor(heatMap: map.Heatmap, dartId: string) {
    this.heatMap = heatMap;
    this.dartId = dartId;
  }

  delete(): void {
    try { this.heatMap.remove(); } catch (e) { hilog.warn(0x0000, TAG, `heatMap.remove failed: ${e}`); }
  }
  /** Heatmap has no nativeId. Use the dart-side id as the synthetic native id. */
  getNativeId(): string { return this.dartId; }

  update(data: Record<string, Object>): void {
    if (data[Param.COLOR] !== undefined) {
      const colorMap = Convert.toHeatmapColor(data[Param.COLOR]);
      if (colorMap) {
        try { this.heatMap.setColor(colorMap); } catch (e) {
          hilog.warn(0x0000, TAG, `heatMap.setColor failed: ${e}`);
        }
      }
    }
    if (data[Param.JSON_DATA] !== undefined) {
      try {
        this.heatMap.setData(Convert.toWeightedLatLngList(data[Param.JSON_DATA]));
      } catch (e) {
        hilog.warn(0x0000, TAG, `heatMap.setData failed: ${e}`);
      }
    }
    if (data[Param.INTENSITY_MAP] !== undefined) {
      const m = Convert.toDoubleKeyedNumberMap(data[Param.INTENSITY_MAP]);
      if (m) {
        try { this.heatMap.setIntensity(m); } catch (e) { hilog.warn(0x0000, TAG, `setIntensity map: ${e}`); }
      }
    } else if (data[Param.INTENSITY] !== undefined) {
      try { this.heatMap.setIntensity(data[Param.INTENSITY] as number); } catch (e) {
        hilog.warn(0x0000, TAG, `setIntensity: ${e}`);
      }
    }
    if (data[Param.OPACITY_MAP] !== undefined) {
      const m = Convert.toDoubleKeyedNumberMap(data[Param.OPACITY_MAP]);
      if (m) {
        try { this.heatMap.setOpacity(m); } catch (e) { hilog.warn(0x0000, TAG, `setOpacity map: ${e}`); }
      }
    } else if (data[Param.OPACITY] !== undefined) {
      try { this.heatMap.setOpacity(data[Param.OPACITY] as number); } catch (e) {
        hilog.warn(0x0000, TAG, `setOpacity: ${e}`);
      }
    }
    if (data[Param.RADIUS_MAP] !== undefined) {
      const m = Convert.toDoubleKeyedNumberMap(data[Param.RADIUS_MAP]);
      if (m) {
        try { this.heatMap.setRadius(m); } catch (e) { hilog.warn(0x0000, TAG, `setRadius map: ${e}`); }
      }
    } else if (data[Param.RADIUS] !== undefined) {
      try { this.heatMap.setRadius(data[Param.RADIUS] as number); } catch (e) {
        hilog.warn(0x0000, TAG, `setRadius: ${e}`);
      }
    }
    if (data[Param.RADIUS_UNIT] !== undefined) {
      try {
        this.heatMap.setRadiusUnit(data[Param.RADIUS_UNIT] as mapCommon.RadiusUnit);
      } catch (e) {
        hilog.warn(0x0000, TAG, `setRadiusUnit: ${e}`);
      }
    }
    if (data[Param.VISIBLE] !== undefined) this.heatMap.setVisible(data[Param.VISIBLE] as boolean);
  }
}
