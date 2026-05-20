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

export class Channel {
  // Per-map MethodChannel prefix. Dart appends `_<viewId>` after this.
  static readonly CHANNEL: string = 'com.huawei.hms.flutter.map/harmony/map';
  // Util MethodChannel name (distance / convert coordinates / logger / api key).
  static readonly MAP_UTILS: string = 'com.huawei.hms.flutter.map/harmony/mapUtils';
  static readonly ANIMATION: string = 'com.huawei.hms.flutter.map/harmony/animation';

  // viewType used by Dart's PlatformViewsService.initExpensiveOhosView.
  // NOTE: Dart side passes _mapChannel (the non-harmony name) as viewType
  // for both Android and OHOS — see lib/src/channel/huawei_map_method_channel.dart.
  static readonly VIEW_TYPE: string = 'com.huawei.hms.flutter.map/map';
}
