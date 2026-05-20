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
 * HmsMapPlugin - Flutter plugin entry point on HarmonyOS. Mirrors the
 * Android HmsMap.java with:
 *   - util MethodChannel (distance / convert / logger / API-key)
 *   - PlatformViewFactory registration for the per-map view type
 */

import {
  MethodChannel,
  MethodCall,
  MethodResult,
  MethodCallHandler,
  StandardMethodCodec,
  FlutterPlugin,
  FlutterPluginBinding,
  BinaryMessenger
} from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { map, mapCommon } from '@kit.MapKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { Channel } from './constants/Channel';
import { Method } from './constants/Method';
import { Convert } from './utils/Convert';
import { ToJson } from './utils/ToJson';
import { MapFactory } from './mapMapFactory';
import { AssetPathResolver } from './mapMapUtils';

const TAG: string = '[HmsMapPlugin]';

export default class HmsMapPlugin implements FlutterPlugin, MethodCallHandler {
  private context: common.UIAbilityContext | null = null;
  private messenger: BinaryMessenger | null = null;
  private mapUtilsChannel: MethodChannel | null = null;
  private factory: MapFactory | null = null;
  private assetResolver: AssetPathResolver | null = null;

  constructor() {}

  getUniqueClassName(): string { return 'HmsMapPlugin'; }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.context = binding.getApplicationContext() as common.UIAbilityContext;
    this.messenger = binding.getBinaryMessenger();
    hilog.info(0x0000, TAG, 'HmsMapPlugin attached to engine');

    // ----- Util MethodChannel -----
    this.mapUtilsChannel = new MethodChannel(this.messenger, Channel.MAP_UTILS, StandardMethodCodec.INSTANCE);
    this.mapUtilsChannel.setMethodCallHandler(this);

    // ----- Asset resolver bridge -----
    const flutterAssets = binding.getFlutterAssets();
    this.assetResolver = (name: string, pkg?: string): string => {
      try {
        if (pkg && pkg.length > 0) return flutterAssets.getAssetFilePathByName(name, pkg);
        return flutterAssets.getAssetFilePathByName(name);
      } catch (e) {
        hilog.warn(0x0000, TAG, `assetResolver failed for ${name}: ${e}`);
        return name;
      }
    };

    // ----- PlatformViewFactory registration -----
    // NOTE: Dart side passes the non-harmony viewType for both platforms — see
    // lib/src/channel/huawei_map_method_channel.dart::buildView. We must register
    // against that exact string.
    this.factory = new MapFactory(this.context, this.messenger, this.assetResolver);
    const registry = binding.getPlatformViewRegistry();
    const ok = registry.registerViewFactory(Channel.VIEW_TYPE, this.factory);
    if (!ok) {
      hilog.error(0x0000, TAG, `Failed to register PlatformViewFactory for ${Channel.VIEW_TYPE}`);
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case Method.INITIALIZE_MAP:
        result.success(null);
        break;

      case Method.SET_API_KEY: {
        const apiKey = call.args as string;
        if (!apiKey) { result.error('INVALID_ARGUMENT', 'apiKey is required', null); return; }
        // OHOS MapKit uses agconnect-services / module-level config; no runtime
        // setter is exposed. Acknowledge so the Dart Future resolves.
        hilog.info(0x0000, TAG, 'setApiKey accepted (no runtime API on HarmonyOS)');
        result.success(true);
        break;
      }

      case Method.SET_ACCESS_TOKEN: {
        const accessToken = call.args as string;
        if (!accessToken) { result.error('INVALID_ARGUMENT', 'accessToken is required', null); return; }
        hilog.info(0x0000, TAG, 'setAccessToken accepted (no runtime API on HarmonyOS)');
        result.success(true);
        break;
      }

      case Method.DISTANCE_CALCULATOR: {
        try {
          const args = call.args as Array<Object>;
          if (!Array.isArray(args) || args.length < 2) {
            result.error('INVALID_ARGUMENT', 'expected [start, end]', null);
            return;
          }
          const start = Convert.toLatLng(args[0]);
          const end = Convert.toLatLng(args[1]);
          const distance = map.calculateDistance(start, end);
          result.success(distance);
        } catch (e) {
          result.error('DISTANCE_ERROR', `${e}`, null);
        }
        break;
      }

      case Method.CONVERT_COORDINATE: {
        try {
          const latLng = Convert.toLatLng(call.args);
          map.convertCoordinate(
            mapCommon.CoordinateType.WGS84,
            mapCommon.CoordinateType.GCJ02,
            latLng
          ).then((converted: mapCommon.LatLng) => {
            result.success(ToJson.latLng(converted));
          }).catch((e: Error) => {
            result.error('CONVERT_ERROR', `${e}`, null);
          });
        } catch (e) {
          result.error('CONVERT_ERROR', `${e}`, null);
        }
        break;
      }

      case Method.CONVERT_COORDINATES: {
        try {
          const rawList = call.args as Array<Object>;
          if (!Array.isArray(rawList)) {
            result.error('INVALID_ARGUMENT', 'expected an array of [lat,lng]', null);
            return;
          }
          const latLngs = rawList.map(item => Convert.toLatLng(item));
          // Promise.all preserves input order, which is required by Dart.
          Promise.all(latLngs.map(ll =>
            map.convertCoordinate(
              mapCommon.CoordinateType.WGS84,
              mapCommon.CoordinateType.GCJ02,
              ll
            )
          )).then((converted: Array<mapCommon.LatLng>) => {
            result.success(ToJson.latLngList(converted));
          }).catch((e: Error) => {
            result.error('CONVERT_ERROR', `${e}`, null);
          });
        } catch (e) {
          result.error('CONVERT_ERROR', `${e}`, null);
        }
        break;
      }

      case Method.ENABLE_LOGGER:
        hilog.info(0x0000, TAG, 'Logger enabled');
        result.success(null);
        break;

      case Method.DISABLE_LOGGER:
        hilog.info(0x0000, TAG, 'Logger disabled');
        result.success(null);
        break;

      default:
        result.notImplemented();
    }
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.mapUtilsChannel?.setMethodCallHandler(null);
    this.mapUtilsChannel = null;
    this.factory?.disposeAll();
    this.factory = null;
    this.assetResolver = null;
    this.messenger = null;
    this.context = null;
    hilog.info(0x0000, TAG, 'HmsMapPlugin detached from engine');
  }
}
