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
 * AnimationConvert
 *   - CameraUpdate decoding   (Dart sends a positional array: [type, ...args])
 *   - HmsAnimation decoding   (Dart sends an object: {animationType, ...})
 */

import { map, mapCommon } from '@kit.MapKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { Param } from './constants/Param';
import { Convert } from './utils/Convert';

const TAG: string = '[AnimationConvert]';

export class AnimationConvert {

  // ====================================================================
  // CameraUpdate
  //
  // Dart `CameraUpdate.toJson()` outputs a positional list, e.g.:
  //   ['newLatLng',          [lat, lng]]
  //   ['newLatLngZoom',      [lat, lng], zoom]
  //   ['newLatLngBounds',    [[sw], [ne]], padding]
  //   ['newCameraPosition',  {target, zoom, tilt, bearing}]
  //   ['scrollBy',           dx, dy]
  //   ['zoomBy',             amount]
  //   ['zoomBy',             amount, [focusX, focusY]]
  //   ['zoomIn']  ['zoomOut']  ['zoomTo', zoom]
  // ====================================================================
  static toCameraUpdate(arg: Object | undefined | null): map.CameraUpdate {
    const fallback = (): map.CameraUpdate =>
      map.newCameraPosition({
        target: { latitude: 39.9, longitude: 116.4 },
        zoom: 10, tilt: 0, bearing: 0
      });

    if (!Array.isArray(arg)) return fallback();
    const data = arg as Array<Object>;
    if (data.length === 0) return fallback();

    const type = String(data[0] ?? '');
    try {
      switch (type) {
        case Param.NEW_CAMERA_POSITION:
          return map.newCameraPosition(Convert.toCameraPosition(data[1]));

        case Param.NEW_LAT_LNG:
          return map.newLatLng(Convert.toLatLng(data[1]));

        case Param.NEW_LAT_LNG_BOUNDS: {
          const bounds = Convert.toLatLngBounds(data[1]);
          const padding = (data[2] as number) ?? 0;
          return map.newLatLngBounds(bounds, padding);
        }

        case Param.NEW_LAT_LNG_ZOOM: {
          const target = Convert.toLatLng(data[1]);
          const zoom = (data[2] as number) ?? 10;
          return map.newLatLng(target, zoom);
        }

        case Param.SCROLL_BY: {
          const dx = (data[1] as number) ?? 0;
          const dy = (data[2] as number) ?? 0;
          return map.scrollBy(dx, dy);
        }

        case Param.ZOOM_BY: {
          const amount = (data[1] as number) ?? 1.0;
          if (data.length >= 3 && Array.isArray(data[2])) {
            const focus = data[2] as Array<number>;
            const pt: mapCommon.MapPoint = {
              positionX: (focus[0] ?? 0) as number,
              positionY: (focus[1] ?? 0) as number
            };
            return map.zoomBy(amount, pt);
          }
          return map.zoomBy(amount);
        }

        case Param.ZOOM_IN:
          return map.zoomIn();

        case Param.ZOOM_OUT:
          return map.zoomOut();

        case Param.ZOOM_TO:
          return map.zoomTo((data[1] as number) ?? 10);

        default:
          hilog.warn(0x0000, TAG, `Unknown CameraUpdate type: ${type}`);
          return fallback();
      }
    } catch (e) {
      hilog.error(0x0000, TAG, `toCameraUpdate failed for type=${type}: ${e}`);
      return fallback();
    }
  }

  // ====================================================================
  // HmsAnimation (object form)
  //
  // Dart `animationToJson` and `animationSetToJson` produce JSON STRINGS
  // (json.encode'd). The caller is responsible for JSON.parse first.
  // Format example:
  //   {
  //     "animationType": "AlphaAnimation",
  //     "duration": 1000,
  //     "fromAlpha": 0.0, "toAlpha": 1.0,
  //     ...
  //   }
  // ====================================================================
  static toAnimation(data: Record<string, Object> | undefined | null): map.Animation | map.AnimationSet | null {
    if (!data || typeof data !== 'object') return null;
    const animationType = String(data[Param.ANIMATION_TYPE] ?? '');
    try {
      switch (animationType) {
        case 'AlphaAnimation':
        case 'HmsAlphaAnimation':
          return AnimationConvert.toAlphaAnimation(data);
        case 'RotateAnimation':
        case 'HmsRotateAnimation':
          return AnimationConvert.toRotateAnimation(data);
        case 'ScaleAnimation':
        case 'HmsScaleAnimation':
          return AnimationConvert.toScaleAnimation(data);
        case 'TranslateAnimation':
        case 'HmsTranslateAnimation':
          return AnimationConvert.toTranslateAnimation(data);
        case 'AnimationSet':
        case 'HmsAnimationSet':
          return AnimationConvert.toAnimationSet(data);
        default:
          hilog.warn(0x0000, TAG, `Unknown animation type: ${animationType}`);
          return null;
      }
    } catch (e) {
      hilog.error(0x0000, TAG, `toAnimation failed: ${e}`);
      return null;
    }
  }

  /**
   * Decode the JSON STRING stored under Param.ANIMATION on a Dart marker/circle
   * into a single map.Animation (wrapping multiple in an AnimationSet if needed).
   * Returns null when the input is empty or malformed.
   */
  static decodeAnimationString(raw: Object | undefined | null): map.Animation | null {
    if (raw === undefined || raw === null) return null;
    if (typeof raw !== 'string') return null;
    const text = (raw as string).trim();
    if (text.length === 0 || text === 'null' || text === '[]') return null;
    let parsed: Object | null = null;
    try {
      parsed = JSON.parse(text) as Object;
    } catch (e) {
      hilog.warn(0x0000, TAG, `decodeAnimationString: invalid JSON: ${e}`);
      return null;
    }
    if (parsed === null) return null;
    if (Array.isArray(parsed)) {
      const list = parsed as Array<Record<string, Object>>;
      hilog.info(0x0000, TAG, `decodeAnimationString: array length=${list.length}`);
      if (list.length === 0) return null;
      if (list.length === 1) {
        const single = AnimationConvert.toAnimation(list[0]);
        hilog.info(
          0x0000,
          TAG,
          `decodeAnimationString: single type=${String(list[0][Param.ANIMATION_TYPE] ?? '')} resolved=${single !== null}`
        );
        if (single instanceof map.AnimationSet) return single as map.Animation;
        return single as map.Animation | null;
      }
      const set = new map.AnimationSet(false);
      let added = 0;
      for (const item of list) {
        const a = AnimationConvert.toAnimation(item);
        if (a && !(a instanceof map.AnimationSet)) {
          set.addAnimation(a as map.Animation);
          added++;
        }
      }
      hilog.info(0x0000, TAG, `decodeAnimationString: built AnimationSet children=${added}`);
      return set;
    }
    const obj = parsed as Record<string, Object>;
    const single = AnimationConvert.toAnimation(obj);
    hilog.info(
      0x0000,
      TAG,
      `decodeAnimationString: object type=${String(obj[Param.ANIMATION_TYPE] ?? '')} resolved=${single !== null}`
    );
    if (single instanceof map.AnimationSet) return single as map.Animation;
    return single as map.Animation | null;
  }

  static toAlphaAnimation(data: Record<string, Object>): map.AlphaAnimation {
    const fromAlpha = (data[Param.FROM_ALPHA] as number) ?? 1.0;
    const toAlpha = (data[Param.TO_ALPHA] as number) ?? 0.0;
    const anim = new map.AlphaAnimation(fromAlpha, toAlpha);
    AnimationConvert.applyBaseProperties(anim, data);
    return anim;
  }

  static toRotateAnimation(data: Record<string, Object>): map.RotateAnimation {
    const fromDegree = (data[Param.FROM_DEGREE] as number) ?? 0;
    const toDegree = (data[Param.TO_DEGREE] as number) ?? 360;
    const anim = new map.RotateAnimation(fromDegree, toDegree);
    AnimationConvert.applyBaseProperties(anim, data);
    return anim;
  }

  static toScaleAnimation(data: Record<string, Object>): map.ScaleAnimation {
    const fromX = (data[Param.FROM_X] as number) ?? 1.0;
    const toX = (data[Param.TO_X] as number) ?? 1.0;
    const fromY = (data[Param.FROM_Y] as number) ?? 1.0;
    const toY = (data[Param.TO_Y] as number) ?? 1.0;
    const anim = new map.ScaleAnimation(fromX, toX, fromY, toY);
    AnimationConvert.applyBaseProperties(anim, data);
    return anim;
  }

  static toTranslateAnimation(data: Record<string, Object>): map.TranslateAnimation {
    const target = Convert.toLatLng(data[Param.TARGET] ?? data[Param.LAT_LNG]);
    const anim = new map.TranslateAnimation(target);
    AnimationConvert.applyBaseProperties(anim, data);
    return anim;
  }

  static toAnimationSet(data: Record<string, Object>): map.AnimationSet {
    const shareInterpolator = (data['shareInterpolator'] as boolean) ?? false;
    const set = new map.AnimationSet(shareInterpolator);
    const animations = data['animations'] as Array<Record<string, Object>>;
    if (Array.isArray(animations)) {
      for (const animData of animations) {
        const child = AnimationConvert.toAnimation(animData);
        if (child && !(child instanceof map.AnimationSet)) {
          set.addAnimation(child as map.Animation);
        }
      }
    }
    AnimationConvert.applyBaseProperties(set, data);
    return set;
  }

  static applyBaseProperties(anim: map.Animation | map.AnimationSet, data: Record<string, Object>): void {
    if (data[Param.DURATION] !== undefined) {
      anim.setDuration(data[Param.DURATION] as number);
    }
    if (data[Param.FILL_MODE] !== undefined) {
      anim.setFillMode((data[Param.FILL_MODE] as number) as map.AnimationFillMode);
    }
    if (data[Param.REPEAT_COUNT] !== undefined) {
      anim.setRepeatCount(data[Param.REPEAT_COUNT] as number);
    }
    if (data[Param.REPEAT_MODE] !== undefined) {
      anim.setRepeatMode((data[Param.REPEAT_MODE] as number) as map.AnimationRepeatMode);
    }
    // Interpolator: Dart sends an int code (see Android Convert.toInterpolator).
    // HarmonyOS map.Animation has no public interpolator API exposed here, so
    // we deliberately ignore the field.
  }
}
