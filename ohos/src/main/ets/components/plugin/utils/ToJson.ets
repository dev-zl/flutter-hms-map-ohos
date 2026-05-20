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
 * ToJson - serialize HarmonyOS MapKit types back to what Flutter Dart expects.
 *
 * Important Dart-side expectations (lib/src/channel/huawei_map_method_channel.dart):
 *   - LatLng                       : [lat, lng]  (LatLng.fromJson reads [0] and [1])
 *   - getScreenCoordinate result   : {x: int, y: int}
 *   - getLatLng result             : [lat, lng]
 *   - getVisibleRegion result      : {northeast: [lat,lng], southwest: [lat,lng]}
 *   - CameraPosition (event arg)   : {target, zoom, tilt, bearing}
 *   - PointOfInterest              : {latLng:[lat,lng], name, placeId}
 *   - Location                     : {latitude, longitude}
 */

import { mapCommon } from '@kit.MapKit';
import { Any } from '@ohos/flutter_ohos';
import { Param } from '../constants/Param';

export class ToJson {

  static latLng(latLng: mapCommon.LatLng): Array<number> {
    return [latLng.latitude, latLng.longitude];
  }

  static latLngList(latLngs: Array<mapCommon.LatLng>): Array<Array<number>> {
    return latLngs.map(l => ToJson.latLng(l));
  }

  /** Map shape {northeast: [lat,lng], southwest: [lat,lng]} expected by Dart. */
  static latlngBounds(bounds: mapCommon.LatLngBounds): Record<string, Array<number>> {
    const result: Record<string, Array<number>> = {};
    result[Param.NORTHEAST] = ToJson.latLng(bounds.northeast);
    result[Param.SOUTHWEST] = ToJson.latLng(bounds.southwest);
    return result;
  }

  static cameraPosition(pos: mapCommon.CameraPosition): Record<string, Any> {
    const out: Record<string, Any> = {};
    out[Param.TARGET] = ToJson.latLng(pos.target);
    out[Param.ZOOM] = pos.zoom;
    out[Param.TILT] = pos.tilt;
    out[Param.BEARING] = pos.bearing;
    return out;
  }

  /** Map shape {x: int, y: int} expected by Dart's getScreenCoordinate. */
  static point(point: mapCommon.MapPoint): Record<string, number> {
    const out: Record<string, number> = {};
    out[Param.X] = Math.round(point.positionX);
    out[Param.Y] = Math.round(point.positionY);
    return out;
  }

  /**
   * Dart's getVisibleRegion expects a Map with {northeast, southwest} at the
   * top level — same shape as latlngBounds. We forward bounds directly.
   */
  static visibleRegion(region: mapCommon.VisibleRegion): Record<string, Array<number>> {
    if (region && region.bounds) {
      return ToJson.latlngBounds(region.bounds);
    }
    // Fall back to a bounds object computed from the 4 corners.
    const lats: Array<number> = [
      region.farLeft.latitude, region.farRight.latitude,
      region.nearLeft.latitude, region.nearRight.latitude
    ];
    const lngs: Array<number> = [
      region.farLeft.longitude, region.farRight.longitude,
      region.nearLeft.longitude, region.nearRight.longitude
    ];
    const minLat = Math.min(lats[0], lats[1], lats[2], lats[3]);
    const maxLat = Math.max(lats[0], lats[1], lats[2], lats[3]);
    const minLng = Math.min(lngs[0], lngs[1], lngs[2], lngs[3]);
    const maxLng = Math.max(lngs[0], lngs[1], lngs[2], lngs[3]);
    const out: Record<string, Array<number>> = {};
    out[Param.NORTHEAST] = [maxLat, maxLng];
    out[Param.SOUTHWEST] = [minLat, minLng];
    return out;
  }
}
