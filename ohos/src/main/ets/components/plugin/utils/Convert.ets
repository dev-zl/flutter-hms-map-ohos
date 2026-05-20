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
 * Convert - Converts Dart/Flutter JSON payloads into HarmonyOS MapKit types.
 *
 * Dart serializes via lib/src/utils/to_json.dart. Wire formats commonly seen:
 *   LatLng           : [lat, lng]
 *   LatLngBounds     : [[sw_lat, sw_lng], [ne_lat, ne_lng]]
 *   CameraTargetBounds: [[[sw...], [ne...]]]  (one extra outer wrap)
 *   PatternItem      : ['dot'] | ['dash', length] | ['gap', length]
 *   Cap              : ['buttCap'] | ['roundCap'] | ['squareCap'] | ['customCap', bitmap, refWidth]
 *   CameraUpdate     : ['newLatLng', [lat,lng]] | ['newLatLngBounds', bounds, padding] | ...
 *   BitmapDescriptor : ['defaultMarker'] | ['defaultMarker', hue] | ['fromAsset', name(, package)]
 *                      | ['fromAssetImage', name, scale] | ['fromBytes', Uint8List]
 *   anchor / offset  : [dx, dy]
 *   color (int)      : Dart Color.value (32-bit ARGB), comes through as number
 *   color (string)   : occasionally hex (#FFRRGGBB) — accepted for safety
 *   heatmap.color    : Map<double,String>  -> { "0": "4294901760", "0.5": "..." }
 *   mapType          : 0=none(blank) 1=normal(standard) 3=terrain (Dart enum)
 *                      Harmony enum: STANDARD=0, NONE=1, TERRAIN=2  (DIFFERENT!)
 */

import { mapCommon } from '@kit.MapKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';

import { Param } from '../constants/Param';

const TAG: string = '[Convert]';

export class Convert {

  static normalizeCodecValue(value: Object | null | undefined): Object | null | undefined {
    if (value instanceof Uint8Array || value instanceof ArrayBuffer) {
      return value;
    }
    if (value instanceof Map) {
      const record: Record<string, Object> = {};
      (value as Map<Object, Object>).forEach((mapValue: Object, mapKey: Object) => {
        record[String(mapKey)] = Convert.normalizeCodecValue(mapValue) as Object;
      });
      return record;
    }
    if (Array.isArray(value)) {
      return (value as Array<Object>).map((item: Object) => Convert.normalizeCodecValue(item) as Object);
    }
    return value;
  }

  // ========== LatLng / Bounds / Point ==========

  static toLatLng(data: Object | undefined | null): mapCommon.LatLng {
    if (!Array.isArray(data)) {
      return { latitude: 0, longitude: 0 };
    }
    const arr = data as Array<number>;
    return { latitude: arr[0] as number, longitude: arr[1] as number };
  }

  static toLatLngList(data: Array<Object> | undefined | null): Array<mapCommon.LatLng> {
    if (!Array.isArray(data)) return [];
    return (data as Array<Object>).map(item => Convert.toLatLng(item));
  }

  static toLatLngBounds(data: Object | undefined | null): mapCommon.LatLngBounds {
    if (!Array.isArray(data)) {
      return { southwest: { latitude: 0, longitude: 0 }, northeast: { latitude: 0, longitude: 0 } };
    }
    const bounds = data as Array<Object>;
    return {
      southwest: Convert.toLatLng(bounds[0]),
      northeast: Convert.toLatLng(bounds[1])
    };
  }

  /**
   * cameraTargetBounds is wrapped one extra time on the Dart side:
   *   [[[sw], [ne]]]   (see lib/src/utils/to_json.dart cameraTargetBoundsToJson)
   * This helper unwraps it back to a plain LatLngBounds.
   */
  static toCameraTargetBounds(data: Object | undefined | null): mapCommon.LatLngBounds | null {
    if (!Array.isArray(data)) return null;
    const outer = data as Array<Object>;
    if (outer.length === 0 || outer[0] === null) return null;
    return Convert.toLatLngBounds(outer[0]);
  }

  static toPoint(data: Object | undefined | null): mapCommon.MapPoint {
    if (!data) return { positionX: 0, positionY: 0 };
    if (Array.isArray(data)) {
      const arr = data as Array<number>;
      return { positionX: (arr[0] ?? 0) as number, positionY: (arr[1] ?? 0) as number };
    }
    if (typeof data === 'object') {
      const pt = data as Record<string, number>;
      return {
        positionX: pt['x'] ?? pt['positionX'] ?? 0,
        positionY: pt['y'] ?? pt['positionY'] ?? 0
      };
    }
    return { positionX: 0, positionY: 0 };
  }

  // ========== Color ==========

  static toColor(value: Object | undefined | null): number {
    if (value === undefined || value === null) return 0xFF000000;
    if (typeof value === 'number') return value as number;
    if (typeof value === 'string') {
      const str = (value as string).trim();
      if (str.startsWith('#')) {
        return parseInt(str.replace('#', '0x'), 16);
      }
      // numeric string (e.g. "4294901760")
      const n = parseInt(str, 10);
      if (!isNaN(n)) return n;
      return 0xFF000000;
    }
    return 0xFF000000;
  }

  // ========== MapType (Dart 0/1/3  -> Harmony STANDARD/NONE/TERRAIN) ==========

  static toMapType(value: Object | undefined | null): mapCommon.MapType {
    if (typeof value !== 'number') return mapCommon.MapType.STANDARD;
    switch (value as number) {
      case 0: return mapCommon.MapType.NONE;       // Dart MapType.none
      case 1: return mapCommon.MapType.STANDARD;   // Dart MapType.normal
      case 3: return mapCommon.MapType.TERRAIN;    // Dart MapType.terrain
      default: return mapCommon.MapType.STANDARD;
    }
  }

  // ========== Cap (Dart sends ['buttCap'] / ['customCap', bitmap, refWidth]) ==========

  static toCapStyle(data: Object | undefined | null): mapCommon.CapStyle {
    if (!Array.isArray(data) || (data as Array<Object>).length === 0) {
      return mapCommon.CapStyle.BUTT;
    }
    const arr = data as Array<Object>;
    const name = String(arr[0] ?? '');
    switch (name) {
      case Param.CAP_BUTT:   return mapCommon.CapStyle.BUTT;
      case Param.CAP_ROUND:  return mapCommon.CapStyle.ROUND;
      case Param.CAP_SQUARE: return mapCommon.CapStyle.SQUARE;
      case Param.CAP_CUSTOM:
        // Harmony has no custom cap with bitmap. Fall back to ROUND visually.
        return mapCommon.CapStyle.ROUND;
      default:
        return mapCommon.CapStyle.BUTT;
    }
  }

  // ========== PatternItem (Dart sends [name(, length)]) ==========

  static toPatternItems(patternData: Object | undefined | null): Array<mapCommon.PatternItem> {
    if (!Array.isArray(patternData)) return [];
    const items: Array<mapCommon.PatternItem> = [];
    for (const p of patternData as Array<Object>) {
      if (!Array.isArray(p)) continue;
      const arr = p as Array<Object>;
      const name = String(arr[0] ?? '');
      const length = ((arr[1] as number) ?? 10) as number;
      switch (name) {
        case Param.PATTERN_DOT:
          items.push({ type: mapCommon.PatternItemType.DOT, length: length });
          break;
        case Param.PATTERN_DASH:
          items.push({ type: mapCommon.PatternItemType.DASH, length: length });
          break;
        case Param.PATTERN_GAP:
          items.push({ type: mapCommon.PatternItemType.GAP, length: length });
          break;
        default:
          break;
      }
    }
    return items;
  }

  // ========== JointType (Dart enum int matches Harmony enum) ==========

  static toJointType(jointType: number | undefined | null): mapCommon.JointType {
    if (jointType === undefined || jointType === null) {
      return mapCommon.JointType.DEFAULT;
    }
    return jointType as mapCommon.JointType;
  }

  // ========== BitmapDescriptor ==========

  /** True if the icon array is the ['fromBytes', Uint8List] form. */
  static isFromBytesIcon(iconData: Object | undefined | null): boolean {
    if (!Array.isArray(iconData)) return false;
    const arr = iconData as Array<Object>;
    return arr.length > 1 && arr[0] === Param.FROM_BYTES;
  }

  /** True if the icon array is the ['fromAsset' | 'fromAssetImage', ...] form. */
  static isFromAssetIcon(iconData: Object | undefined | null): boolean {
    if (!Array.isArray(iconData)) return false;
    const arr = iconData as Array<Object>;
    if (arr.length < 2) return false;
    const type = arr[0];
    return type === Param.FROM_ASSET || type === Param.FROM_ASSET_IMAGE;
  }

  /**
   * Decode raw bytes ['fromBytes', Uint8List|ArrayBuffer] into a PixelMap.
   */
  static async fromBytesToPixelMap(iconData: Object): Promise<image.PixelMap | undefined> {
    try {
      if (!Array.isArray(iconData)) return undefined;
      const arr = iconData as Array<Object>;
      const byteData = arr[1];
      let buffer: ArrayBuffer;
      if (byteData instanceof ArrayBuffer) {
        buffer = byteData;
      } else if (byteData instanceof Uint8Array) {
        buffer = (byteData as Uint8Array).buffer.slice(
          (byteData as Uint8Array).byteOffset,
          (byteData as Uint8Array).byteOffset + (byteData as Uint8Array).byteLength
        ) as ArrayBuffer;
      } else {
        hilog.warn(0x0000, TAG, 'fromBytesToPixelMap: unsupported byte data type');
        return undefined;
      }
      hilog.info(0x0000, TAG, `fromBytesToPixelMap: decoding length=${buffer.byteLength}`);
      const imageSource = image.createImageSource(buffer);
      const pixelMap = await imageSource.createPixelMap();
      hilog.info(0x0000, TAG, 'fromBytesToPixelMap: decoded PixelMap');
      return pixelMap;
    } catch (e) {
      hilog.error(0x0000, TAG, `fromBytesToPixelMap failed: ${e}`);
      return undefined;
    }
  }

  /**
   * Decode a Flutter asset icon at `flutterAssetPath` (the path returned by
   * FlutterAssets.getAssetFilePathByName / getAssetFilePathBySubpath) into a
   * PixelMap, by reading it as a raw resource via resourceManager.
   */
  static async fromAssetToPixelMap(
    ctx: common.UIAbilityContext,
    flutterAssetPath: string
  ): Promise<image.PixelMap | undefined> {
    try {
      hilog.info(0x0000, TAG, `fromAssetToPixelMap: reading ${flutterAssetPath}`);
      const rawData: Uint8Array = await ctx.resourceManager.getRawFileContent(flutterAssetPath);
      const buf = rawData.buffer.slice(rawData.byteOffset, rawData.byteOffset + rawData.byteLength) as ArrayBuffer;
      hilog.info(0x0000, TAG, `fromAssetToPixelMap: decoding ${flutterAssetPath} length=${buf.byteLength}`);
      const imageSource = image.createImageSource(buf);
      const pixelMap = await imageSource.createPixelMap();
      hilog.info(0x0000, TAG, `fromAssetToPixelMap: decoded PixelMap ${flutterAssetPath}`);
      return pixelMap;
    } catch (e) {
      hilog.error(0x0000, TAG, `fromAssetToPixelMap(${flutterAssetPath}) failed: ${e}`);
      return undefined;
    }
  }

  /**
   * Extract the asset name + optional package from a BitmapDescriptor array.
   * Returns null when this is not an asset-based descriptor.
   */
  static parseAssetIcon(iconData: Object | undefined | null): AssetIconRef | null {
    if (!Array.isArray(iconData)) return null;
    const arr = iconData as Array<Object>;
    if (arr.length < 2) return null;
    const type = String(arr[0] ?? '');
    if (type === Param.FROM_ASSET) {
      const ref: AssetIconRef = {
        assetName: String(arr[1] ?? ''),
        packageName: (arr.length >= 3 && arr[2] != null) ? String(arr[2]) : undefined
      };
      return ref;
    }
    if (type === Param.FROM_ASSET_IMAGE) {
      const ref: AssetIconRef = {
        assetName: String(arr[1] ?? ''),
        packageName: undefined
      };
      return ref;
    }
    return null;
  }

  // ========== Marker Options ==========

  static toMarkerOptions(data: Record<string, Object>): mapCommon.MarkerOptions {
    const position = Convert.toLatLng(data[Param.POSITION] ?? data[Param.LAT_LNG]);
    const opts: mapCommon.MarkerOptions = { position: position };

    if (data[Param.ALPHA] !== undefined) opts.alpha = data[Param.ALPHA] as number;
    if (data[Param.ANCHOR] !== undefined) {
      const anchor = data[Param.ANCHOR] as Array<number>;
      if (Array.isArray(anchor)) {
        opts.anchorU = anchor[0];
        opts.anchorV = anchor[1];
      }
    }
    if (data[Param.CLICKABLE] !== undefined) opts.clickable = data[Param.CLICKABLE] as boolean;
    if (data[Param.DRAGGABLE] !== undefined) opts.draggable = data[Param.DRAGGABLE] as boolean;
    if (data[Param.FLAT] !== undefined) opts.flat = data[Param.FLAT] as boolean;
    if (data[Param.ROTATION] !== undefined) opts.rotation = data[Param.ROTATION] as number;
    if (data[Param.VISIBLE] !== undefined) opts.visible = data[Param.VISIBLE] as boolean;
    if (data[Param.Z_INDEX] !== undefined) opts.zIndex = data[Param.Z_INDEX] as number;

    if (data[Param.INFO_WINDOW] !== undefined) {
      const iw = data[Param.INFO_WINDOW] as Record<string, Object>;
      if (iw) {
        if (iw[Param.TITLE] !== undefined) opts.title = iw[Param.TITLE] as string;
        if (iw[Param.SNIPPET] !== undefined) opts.snippet = iw[Param.SNIPPET] as string;
        if (iw[Param.ANCHOR] !== undefined) {
          const a = iw[Param.ANCHOR] as Array<number>;
          if (Array.isArray(a)) {
            opts.infoWindowAnchorU = a[0];
            opts.infoWindowAnchorV = a[1];
          }
        }
      }
    }
    // icon is filled in asynchronously by the caller (see mapMapUtils.addMarker).
    return opts;
  }

  // ========== Polyline Options ==========

  static toPolylineOptions(data: Record<string, Object>): mapCommon.MapPolylineOptions {
    const points = Convert.toLatLngList(data[Param.POINTS] as Array<Object>);
    const opts: mapCommon.MapPolylineOptions = { points: points };

    if (data[Param.COLOR] !== undefined) opts.color = Convert.toColor(data[Param.COLOR]);
    if (data[Param.WIDTH] !== undefined) opts.width = data[Param.WIDTH] as number;
    if (data[Param.END_CAP] !== undefined) opts.endCap = Convert.toCapStyle(data[Param.END_CAP]);
    if (data[Param.START_CAP] !== undefined) opts.startCap = Convert.toCapStyle(data[Param.START_CAP]);
    if (data[Param.JOINT_TYPE] !== undefined) opts.jointType = Convert.toJointType(data[Param.JOINT_TYPE] as number);
    if (data[Param.PATTERN] !== undefined) {
      const items = Convert.toPatternItems(data[Param.PATTERN]);
      if (items.length > 0) opts.patterns = items;
    }
    if (data[Param.GEODESIC] !== undefined) opts.geodesic = data[Param.GEODESIC] as boolean;
    if (data[Param.CLICKABLE] !== undefined) opts.clickable = data[Param.CLICKABLE] as boolean;
    if (data[Param.VISIBLE] !== undefined) opts.visible = data[Param.VISIBLE] as boolean;
    if (data[Param.Z_INDEX] !== undefined) opts.zIndex = data[Param.Z_INDEX] as number;
    if (data[Param.GRADIENT] !== undefined) opts.gradient = data[Param.GRADIENT] as boolean;
    if (data[Param.COLOR_VALUES] !== undefined) {
      const colors = data[Param.COLOR_VALUES];
      if (Array.isArray(colors) && (colors as Array<Object>).length > 0) {
        opts.colors = (colors as Array<number>);
      }
    }
    return opts;
  }

  // ========== Polygon Options ==========

  static toPolygonOptions(data: Record<string, Object>): mapCommon.MapPolygonOptions {
    const points = Convert.toLatLngList(data[Param.POINTS] as Array<Object>);
    const opts: mapCommon.MapPolygonOptions = { points: points };

    if (data[Param.FILL_COLOR] !== undefined) opts.fillColor = Convert.toColor(data[Param.FILL_COLOR]);
    if (data[Param.STROKE_COLOR] !== undefined) opts.strokeColor = Convert.toColor(data[Param.STROKE_COLOR]);
    if (data[Param.STROKE_WIDTH] !== undefined) opts.strokeWidth = data[Param.STROKE_WIDTH] as number;
    if (data[Param.CLICKABLE] !== undefined) opts.clickable = data[Param.CLICKABLE] as boolean;
    if (data[Param.GEODESIC] !== undefined) opts.geodesic = data[Param.GEODESIC] as boolean;
    if (data[Param.VISIBLE] !== undefined) opts.visible = data[Param.VISIBLE] as boolean;
    if (data[Param.Z_INDEX] !== undefined) opts.zIndex = data[Param.Z_INDEX] as number;
    if (data[Param.HOLES] !== undefined) {
      const holesArr = data[Param.HOLES] as Array<Object>;
      if (Array.isArray(holesArr)) {
        opts.holes = holesArr.map(h => Convert.toLatLngList(h as Array<Object>));
      }
    }
    if (data[Param.STROKE_JOINT_TYPE] !== undefined) {
      opts.jointType = Convert.toJointType(data[Param.STROKE_JOINT_TYPE] as number);
    }
    if (data[Param.STROKE_PATTERN] !== undefined) {
      const items = Convert.toPatternItems(data[Param.STROKE_PATTERN]);
      if (items.length > 0) opts.patterns = items;
    }
    return opts;
  }

  // ========== Circle Options ==========

  static toCircleOptions(data: Record<string, Object>): mapCommon.MapCircleOptions {
    const center = Convert.toLatLng(data[Param.CENTER] ?? data[Param.LAT_LNG]);
    const radius = (data[Param.RADIUS] as number) ?? 0;
    const opts: mapCommon.MapCircleOptions = { center: center, radius: radius };

    if (data[Param.FILL_COLOR] !== undefined) opts.fillColor = Convert.toColor(data[Param.FILL_COLOR]);
    if (data[Param.STROKE_COLOR] !== undefined) opts.strokeColor = Convert.toColor(data[Param.STROKE_COLOR]);
    if (data[Param.STROKE_WIDTH] !== undefined) opts.strokeWidth = data[Param.STROKE_WIDTH] as number;
    if (data[Param.CLICKABLE] !== undefined) opts.clickable = data[Param.CLICKABLE] as boolean;
    if (data[Param.STROKE_PATTERN] !== undefined) {
      const items = Convert.toPatternItems(data[Param.STROKE_PATTERN]);
      if (items.length > 0) opts.patterns = items;
    }
    if (data[Param.VISIBLE] !== undefined) opts.visible = data[Param.VISIBLE] as boolean;
    if (data[Param.Z_INDEX] !== undefined) opts.zIndex = data[Param.Z_INDEX] as number;
    return opts;
  }

  // ========== GroundOverlay (ImageOverlay) Options ==========

  static toImageOverlayParams(data: Record<string, Object>): mapCommon.ImageOverlayParams {
    // image is filled in asynchronously by the caller after pixelMap is decoded.
    const opts: mapCommon.ImageOverlayParams = { image: '' };

    if (data[Param.BOUNDS] !== undefined) opts.bounds = Convert.toLatLngBounds(data[Param.BOUNDS]);
    if (data[Param.POSITION] !== undefined) opts.position = Convert.toLatLng(data[Param.POSITION]);
    if (data[Param.BEARING] !== undefined) opts.bearing = data[Param.BEARING] as number;
    if (data[Param.TRANSPARENCY] !== undefined) opts.transparency = data[Param.TRANSPARENCY] as number;
    if (data[Param.CLICKABLE] !== undefined) opts.clickable = data[Param.CLICKABLE] as boolean;
    if (data[Param.VISIBLE] !== undefined) opts.visible = data[Param.VISIBLE] as boolean;
    if (data[Param.Z_INDEX] !== undefined) opts.zIndex = data[Param.Z_INDEX] as number;
    if (data[Param.WIDTH] !== undefined) opts.width = data[Param.WIDTH] as number;
    if (data[Param.HEIGHT] !== undefined) opts.height = data[Param.HEIGHT] as number;
    if (data[Param.ANCHOR] !== undefined) {
      const a = data[Param.ANCHOR] as Array<number>;
      if (Array.isArray(a)) {
        opts.anchorU = a[0];
        opts.anchorV = a[1];
      }
    }
    return opts;
  }

  // ========== TileOverlay Options ==========

  static toTileOverlayOptions(data: Record<string, Object>): mapCommon.TileOverlayOptions {
    const opts: mapCommon.TileOverlayOptions = {};
    if (data[Param.FADE_IN] !== undefined) opts.fadeIn = data[Param.FADE_IN] as boolean;
    if (data[Param.Z_INDEX] !== undefined) opts.zIndex = data[Param.Z_INDEX] as number;
    if (data[Param.VISIBLE] !== undefined) opts.visible = data[Param.VISIBLE] as boolean;
    if (data[Param.TRANSPARENCY] !== undefined) opts.transparency = data[Param.TRANSPARENCY] as number;

    if (data[Param.TILE_PROVIDER] !== undefined) {
      const tp = data[Param.TILE_PROVIDER];
      // UrlTile -> {uri: "https://.../{x}/{y}/{z}.png"}
      if (tp && typeof tp === 'object' && !Array.isArray(tp)) {
        const tpRec = tp as Record<string, Object>;
        if (tpRec[Param.URI] !== undefined) {
          opts.tileUrl = String(tpRec[Param.URI]);
          hilog.info(0x0000, TAG, `toTileOverlayOptions: UrlTile tileUrl=${opts.tileUrl}`);
        } else if (tpRec[Param.IMAGE_DATA] !== undefined && tpRec[Param.ZOOM] !== undefined) {
          hilog.warn(0x0000, TAG, 'toTileOverlayOptions: RepetitiveTile provider is not supported on HarmonyOS MapKit, ignored');
        } else {
          hilog.warn(0x0000, TAG, `toTileOverlayOptions: unsupported tile provider keys=${Object.keys(tpRec).join(',')}`);
        }
      }
      // RepetitiveTile / List<Tile> have no clean OHOS equivalent — log it.
      else if (Array.isArray(tp)) {
        hilog.warn(0x0000, TAG, `toTileOverlayOptions: List<Tile> provider count=${(tp as Array<Object>).length} is not supported on HarmonyOS MapKit, ignored`);
      }
    }
    return opts;
  }

  // ========== HeatMap Options ==========

  /**
   * Heatmap color comes from Dart as Map<double,String> (value.value.toString()).
   * Convert it to Record<number, number> (key=stop, value=ARGB int) for MapKit.
   */
  static toHeatmapColor(raw: Object | undefined | null): Record<number, number> | undefined {
    if (!raw || typeof raw !== 'object') return undefined;
    const src = raw as Record<string, Object>;
    const out: Record<number, number> = {};
    let any = false;
    for (const k of Object.keys(src)) {
      const stop = parseFloat(k);
      if (isNaN(stop)) continue;
      out[stop] = Convert.toColor(src[k]);
      any = true;
    }
    return any ? out : undefined;
  }

  /**
   * Maps with double keys (intensity / opacity / radius) come through as
   * Record<string, number>; convert them to Record<number, number>.
   */
  static toDoubleKeyedNumberMap(raw: Object | undefined | null): Record<number, number> | undefined {
    if (!raw || typeof raw !== 'object') return undefined;
    const src = raw as Record<string, Object>;
    const out: Record<number, number> = {};
    let any = false;
    for (const k of Object.keys(src)) {
      const stop = parseFloat(k);
      if (isNaN(stop)) continue;
      out[stop] = Number(src[k]);
      any = true;
    }
    return any ? out : undefined;
  }

  static toHeatMapOptions(data: Record<string, Object>): mapCommon.HeatmapParams {
    const heatMapId = (data[Param.HEAT_MAP_ID] ?? `hm_${Date.now()}`) as string;
    const dataSet: Array<mapCommon.WeightedLatLng> =
      data[Param.JSON_DATA] !== undefined
        ? Convert.toWeightedLatLngList(data[Param.JSON_DATA])
        : [];

    // resourceId is an Android resource integer that cannot be resolved on
    // HarmonyOS. Warn the caller so they know to pass GeoJSON text via dataSet
    // (Dart HeatMap.dataSet) instead when targeting OHOS.
    if (data[Param.RESOURCE_ID] !== undefined &&
        data[Param.JSON_DATA] === undefined) {
      hilog.warn(0x0000, TAG,
        `HeatMap ${heatMapId}: resourceId is unsupported on HarmonyOS — ` +
        `pass GeoJSON via HeatMap.dataSet instead`);
    }

    const opts: mapCommon.HeatmapParams = { id: heatMapId, data: dataSet };

    if (data[Param.RADIUS_UNIT] !== undefined) {
      opts.radiusUnit = data[Param.RADIUS_UNIT] as mapCommon.RadiusUnit;
    }
    const color = Convert.toHeatmapColor(data[Param.COLOR]);
    if (color) opts.color = color;

    // Intensity: prefer per-zoom map if present
    if (data[Param.INTENSITY_MAP] !== undefined) {
      const m = Convert.toDoubleKeyedNumberMap(data[Param.INTENSITY_MAP]);
      if (m) opts.intensity = m;
    } else if (data[Param.INTENSITY] !== undefined) {
      opts.intensity = data[Param.INTENSITY] as number;
    }

    if (data[Param.OPACITY_MAP] !== undefined) {
      const m = Convert.toDoubleKeyedNumberMap(data[Param.OPACITY_MAP]);
      if (m) opts.opacity = m;
    } else if (data[Param.OPACITY] !== undefined) {
      opts.opacity = data[Param.OPACITY] as number;
    }

    if (data[Param.RADIUS_MAP] !== undefined) {
      const m = Convert.toDoubleKeyedNumberMap(data[Param.RADIUS_MAP]);
      if (m) opts.radius = m;
    } else if (data[Param.RADIUS] !== undefined) {
      opts.radius = data[Param.RADIUS] as number;
    }

    if (data[Param.VISIBLE] !== undefined) opts.visible = data[Param.VISIBLE] as boolean;
    return opts;
  }

  /**
   * Parse a Dart `dataSet` (GeoJSON string OR a List of weighted points) into
   * WeightedLatLng[]. Dart sends the string via lib (HeatMap.dataSet is String).
   */
  static toWeightedLatLngList(raw: Object | undefined | null): Array<mapCommon.WeightedLatLng> {
    if (raw === undefined || raw === null) return [];
    let arr: Array<Record<string, Object>> = [];
    if (typeof raw === 'string') {
      try {
        // GeoJSON FeatureCollection.features[].geometry.coordinates = [lng, lat]
        const parsed: Record<string, Object> = JSON.parse(raw as string) as Record<string, Object>;
        if (parsed && parsed.features && Array.isArray(parsed.features)) {
          const out: Array<mapCommon.WeightedLatLng> = [];
          for (const f of parsed.features as Array<Record<string, Object>>) {
            const geom = f['geometry'] as Record<string, Object>;
            const props = f['properties'] as Record<string, Object>;
            if (!geom) continue;
            const coords = geom['coordinates'] as Array<number>;
            if (!Array.isArray(coords) || coords.length < 2) continue;
            const weight = (props && (props['weight'] as number)) ?? 1;
            out.push({
              point: { latitude: coords[1] as number, longitude: coords[0] as number },
              intensity: weight
            });
          }
          return out;
        }
        if (Array.isArray(parsed)) arr = parsed as Array<Record<string, Object>>;
      } catch (e) {
        hilog.warn(0x0000, TAG, `toWeightedLatLngList: failed to parse JSON: ${e}`);
        return [];
      }
    } else if (Array.isArray(raw)) {
      arr = raw as Array<Record<string, Object>>;
    } else {
      return [];
    }

    return arr.map(item => {
      const lat = (item[Param.LATITUDE] ?? item['latitude'] ?? 0) as number;
      const lng = (item[Param.LONGITUDE] ?? item['longitude'] ?? 0) as number;
      const weight = (
        (item[Param.WEIGHT] ?? item[Param.INTENSITY] ?? item['intensity'] ?? item['weight'] ?? 1)
      ) as number;
      const out: mapCommon.WeightedLatLng = {
        point: { latitude: lat, longitude: lng },
        intensity: weight
      };
      return out;
    });
  }

  // ========== CameraPosition ==========

  static toCameraPosition(data: Object | undefined | null): mapCommon.CameraPosition {
    if (!data || typeof data !== 'object' || Array.isArray(data)) {
      return { target: { latitude: 39.9, longitude: 116.4 }, zoom: 10, tilt: 0, bearing: 0 };
    }
    const cp = data as Record<string, Object>;
    return {
      target: Convert.toLatLng(cp[Param.TARGET] ?? cp[Param.LAT_LNG]),
      zoom: (cp[Param.ZOOM] as number) ?? 10,
      tilt: (cp[Param.TILT] as number) ?? 0,
      bearing: (cp[Param.BEARING] as number) ?? 0
    };
  }

  // ========== MyLocationStyle ==========

  static toMyLocationStyle(data: Object | undefined | null): mapCommon.MyLocationStyle {
    const empty: Record<string, Object> = {};
    if (!data || typeof data !== 'object') return empty as mapCommon.MyLocationStyle;
    const style = data as Record<string, Object>;
    const mls: Record<string, Object> = {};
    if (style[Param.RADIUS_FILL_COLOR] !== undefined) {
      mls['radiusFillColor'] = Convert.toColor(style[Param.RADIUS_FILL_COLOR]);
    } else if (style['radiusFillColor'] !== undefined) {
      mls['radiusFillColor'] = Convert.toColor(style['radiusFillColor']);
    }
    if (style[Param.ANCHOR] !== undefined) {
      const a = style[Param.ANCHOR] as Array<number>;
      if (Array.isArray(a)) {
        mls['anchorU'] = a[0];
        mls['anchorV'] = a[1];
      }
    }
    return mls as mapCommon.MyLocationStyle;
  }

  // ========== Initial MapOptions ==========

  static toMapOptions(options: Record<string, Object>): mapCommon.MapOptions {
    let position: mapCommon.CameraPosition = {
      target: { latitude: 39.9042, longitude: 116.4074 },
      zoom: 10
    };

    // creationParams uses `initialCameraPosition` directly, not the CameraUpdate variants.
    if (options[Param.NEW_CAMERA_POSITION] !== undefined) {
      position = Convert.toCameraPosition(options[Param.NEW_CAMERA_POSITION]);
    }

    const opts: mapCommon.MapOptions = { position: position };

    if (options[Param.MAP_TYPE] !== undefined) {
      opts.mapType = Convert.toMapType(options[Param.MAP_TYPE]);
    }
    if (options[Param.ZOOM_GESTURES_ENABLED] !== undefined) {
      opts.zoomGesturesEnabled = options[Param.ZOOM_GESTURES_ENABLED] as boolean;
    }
    if (options[Param.SCROLL_GESTURES_ENABLED] !== undefined) {
      opts.scrollGesturesEnabled = options[Param.SCROLL_GESTURES_ENABLED] as boolean;
    }
    if (options[Param.ROTATE_GESTURES_ENABLED] !== undefined) {
      opts.rotateGesturesEnabled = options[Param.ROTATE_GESTURES_ENABLED] as boolean;
    }
    if (options[Param.TILT_GESTURES_ENABLED] !== undefined) {
      opts.tiltGesturesEnabled = options[Param.TILT_GESTURES_ENABLED] as boolean;
    }
    if (options[Param.COMPASS_ENABLED] !== undefined) {
      opts.compassControlsEnabled = options[Param.COMPASS_ENABLED] as boolean;
    }
    if (options[Param.MIN_MAX_ZOOM_PREFERENCE] !== undefined) {
      const pref = options[Param.MIN_MAX_ZOOM_PREFERENCE];
      if (Array.isArray(pref)) {
        const arr = pref as Array<number>;
        if (arr.length >= 2) {
          opts.minZoom = arr[0];
          opts.maxZoom = arr[1];
        }
      } else if (pref && typeof pref === 'object') {
        const m = pref as Record<string, number>;
        opts.minZoom = m['min'];
        opts.maxZoom = m['max'];
      }
    }
    if (options[Param.CAMERA_TARGET_BOUNDS] !== undefined) {
      const bounds = Convert.toCameraTargetBounds(options[Param.CAMERA_TARGET_BOUNDS]);
      if (bounds) opts.bounds = bounds;
    }
    if (options[Param.ZOOM_CONTROLS_ENABLED] !== undefined) {
      opts.zoomControlsEnabled = options[Param.ZOOM_CONTROLS_ENABLED] as boolean;
    }
    if (options[Param.MY_LOCATION_BUTTON_ENABLED] !== undefined) {
      opts.myLocationControlsEnabled = options[Param.MY_LOCATION_BUTTON_ENABLED] as boolean;
    }
    if (options[Param.PADDING] !== undefined) {
      // Dart sends [top, left, bottom, right]; Harmony expects {left, top, right, bottom}.
      const padding = options[Param.PADDING] as Array<number>;
      if (Array.isArray(padding) && padding.length >= 4) {
        opts.padding = { left: padding[1], top: padding[0], right: padding[3], bottom: padding[2] };
      }
    }
    if (options[Param.STYLE_ID] !== undefined) {
      opts.styleId = options[Param.STYLE_ID] as string;
    }
    return opts;
  }

  // ========== Process Map Options (call MapController setters in place) ==========

  static processMapOptions(options: Record<string, Object>, controller: Object): void {
    const ctrl = controller as MapControllerRef;

    if (options[Param.COMPASS_ENABLED] !== undefined) {
      ctrl.setCompassControlsEnabled(options[Param.COMPASS_ENABLED] as boolean);
    }
    if (options[Param.MAP_TOOLBAR_ENABLED] !== undefined) {
      hilog.warn(0x0000, TAG, 'setMapToolbarEnabled not supported on HarmonyOS');
    }
    if (options[Param.CAMERA_TARGET_BOUNDS] !== undefined) {
      const bounds = Convert.toCameraTargetBounds(options[Param.CAMERA_TARGET_BOUNDS]);
      if (bounds) ctrl.setLatLngBounds(bounds);
    }
    if (options[Param.MAP_TYPE] !== undefined) {
      ctrl.setMapType(Convert.toMapType(options[Param.MAP_TYPE]));
    }
    if (options[Param.MIN_MAX_ZOOM_PREFERENCE] !== undefined) {
      const pref = options[Param.MIN_MAX_ZOOM_PREFERENCE];
      if (Array.isArray(pref)) {
        const arr = pref as Array<number>;
        if (arr.length >= 2) {
          if (arr[0] !== null && arr[0] !== undefined) ctrl.setMinZoom(arr[0]);
          if (arr[1] !== null && arr[1] !== undefined) ctrl.setMaxZoom(arr[1]);
        }
      } else if (pref && typeof pref === 'object') {
        const m = pref as Record<string, number>;
        if (m['min'] !== null && m['min'] !== undefined) ctrl.setMinZoom(m['min']);
        if (m['max'] !== null && m['max'] !== undefined) ctrl.setMaxZoom(m['max']);
      }
    }
    if (options[Param.ROTATE_GESTURES_ENABLED] !== undefined) {
      ctrl.setRotateGesturesEnabled(options[Param.ROTATE_GESTURES_ENABLED] as boolean);
    }
    if (options[Param.SCROLL_GESTURES_ENABLED] !== undefined) {
      ctrl.setScrollGesturesEnabled(options[Param.SCROLL_GESTURES_ENABLED] as boolean);
    }
    if (options[Param.TILT_GESTURES_ENABLED] !== undefined) {
      ctrl.setTiltGesturesEnabled(options[Param.TILT_GESTURES_ENABLED] as boolean);
    }
    if (options[Param.ZOOM_GESTURES_ENABLED] !== undefined) {
      ctrl.setZoomGesturesEnabled(options[Param.ZOOM_GESTURES_ENABLED] as boolean);
    }
    if (options[Param.ALL_GESTURES_ENABLED] !== undefined) {
      ctrl.setAllGesturesEnabled(options[Param.ALL_GESTURES_ENABLED] as boolean);
    }
    if (options[Param.ZOOM_CONTROLS_ENABLED] !== undefined) {
      ctrl.setZoomControlsEnabled(options[Param.ZOOM_CONTROLS_ENABLED] as boolean);
    }
    if (options[Param.TRACK_CAMERA_POSITION] !== undefined) {
      ctrl.setTrackCameraPosition(options[Param.TRACK_CAMERA_POSITION] as boolean);
    }
    if (options[Param.MY_LOCATION_ENABLED] !== undefined) {
      ctrl.setMyLocationEnabled(options[Param.MY_LOCATION_ENABLED] as boolean);
    }
    if (options[Param.MY_LOCATION_BUTTON_ENABLED] !== undefined) {
      ctrl.setMyLocationControlsEnabled(options[Param.MY_LOCATION_BUTTON_ENABLED] as boolean);
    }
    if (options[Param.PADDING] !== undefined) {
      const padding = options[Param.PADDING] as Array<number>;
      if (Array.isArray(padding) && padding.length >= 4) {
        ctrl.setPadding({ left: padding[1], top: padding[0], right: padding[3], bottom: padding[2] });
      }
    }
    if (options[Param.TRAFFIC_ENABLED] !== undefined) {
      ctrl.setTrafficEnabled(options[Param.TRAFFIC_ENABLED] as boolean);
    }
    if (options[Param.BUILDINGS_ENABLED] !== undefined) {
      ctrl.setBuildingEnabled(options[Param.BUILDINGS_ENABLED] as boolean);
    }
    if (options[Param.POINT_TO_CENTER] !== undefined) {
      ctrl.setPointToCenter(Convert.toPoint(options[Param.POINT_TO_CENTER]));
    }
    if (options[Param.LOGO_POSITION] !== undefined) {
      ctrl.setLogoAlignment(options[Param.LOGO_POSITION] as mapCommon.LogoAlignment);
    }
    if (options[Param.MARKERS_CLUSTERING_ENABLED] !== undefined) {
      ctrl.setMarkersClustering(options[Param.MARKERS_CLUSTERING_ENABLED] as boolean);
    }
    if (options[Param.CLUSTER_MARKER_COLOR] !== undefined) {
      ctrl.setClusterMarkerColor(Convert.toColor(options[Param.CLUSTER_MARKER_COLOR]));
    }
    if (options[Param.CLUSTER_MARKER_TEXT_COLOR] !== undefined) {
      ctrl.setClusterMarkerTextColor(Convert.toColor(options[Param.CLUSTER_MARKER_TEXT_COLOR]));
    }
    if (options[Param.CLUSTER_MARKER_ICON] !== undefined) {
      ctrl.setClusterMarkerIcon(options[Param.CLUSTER_MARKER_ICON]);
    }
    if (options[Param.MY_LOCATION_STYLE] !== undefined) {
      ctrl.setMyLocationStyle(Convert.toMyLocationStyle(options[Param.MY_LOCATION_STYLE])).catch(() => {});
    }
    if (options[Param.STYLE_ID] !== undefined) {
      ctrl.setStyleId(options[Param.STYLE_ID] as string);
    }
    // Options that have no direct OHOS equivalent (logged once for visibility).
    if (options[Param.IS_SCROLL_GESTURES_ENABLED_DURING_ROTATE_OR_ZOOM] !== undefined) {
      hilog.info(0x0000, TAG, 'isScrollGesturesEnabledDuringRotateOrZoom ignored (no HarmonyOS API)');
    }
    if (options[Param.GESTURE_SCALE_BY_MAP_CENTER] !== undefined) {
      hilog.info(0x0000, TAG, 'gestureScaleByMapCenter ignored (no HarmonyOS API)');
    }
    if (options[Param.LITE_MODE] !== undefined) {
      hilog.info(0x0000, TAG, 'liteMode ignored (no HarmonyOS API)');
    }
    if (options[Param.PREVIEW_ID] !== undefined) {
      hilog.info(0x0000, TAG, 'previewId ignored (no HarmonyOS API)');
    }
    if (options[Param.DARK] !== undefined) {
      hilog.info(0x0000, TAG, 'isDark ignored (use setStyle on HarmonyOS)');
    }
  }

  // ========== Misc helpers ==========

  static toString(data: Object | undefined | null): string {
    if (data === undefined || data === null) return '';
    return String(data);
  }

  static toFloat(data: Object | undefined | null): number {
    if (data === undefined || data === null) return 0;
    if (typeof data === 'number') return data as number;
    return parseFloat(String(data));
  }
}

export interface AssetIconRef {
  assetName: string;
  packageName?: string;
}

/**
 * Subset of MapController used by processMapOptions. Defined here so that
 * Convert does not import MapController (would create a cycle).
 */
interface MapControllerRef {
  setCompassControlsEnabled(v: boolean): void;
  setLatLngBounds(b: mapCommon.LatLngBounds): void;
  setMapType(t: mapCommon.MapType): void;
  setMinZoom(min: number): void;
  setMaxZoom(max: number): void;
  setRotateGesturesEnabled(v: boolean): void;
  setScrollGesturesEnabled(v: boolean): void;
  setTiltGesturesEnabled(v: boolean): void;
  setZoomGesturesEnabled(v: boolean): void;
  setAllGesturesEnabled(v: boolean): void;
  setZoomControlsEnabled(v: boolean): void;
  setTrackCameraPosition(v: boolean): void;
  setMyLocationEnabled(v: boolean): void;
  setMyLocationControlsEnabled(v: boolean): void;
  setPadding(padding: mapCommon.Padding): void;
  setTrafficEnabled(v: boolean): void;
  setBuildingEnabled(v: boolean): void;
  setPointToCenter(p: mapCommon.MapPoint): void;
  setLogoAlignment(a: mapCommon.LogoAlignment): void;
  setMarkersClustering(v: boolean): void;
  setClusterMarkerColor(c: number): void;
  setClusterMarkerTextColor(c: number): void;
  setClusterMarkerIcon(icon: Object): void;
  setMyLocationStyle(s: mapCommon.MyLocationStyle): Promise<void>;
  setStyleId(s: string): void;
}
