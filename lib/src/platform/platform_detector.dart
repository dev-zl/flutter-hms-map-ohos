/*
    Copyright 2020-2024. Huawei Technologies Co., Ltd. All rights reserved.

    Licensed under the Apache License, Version 2.0 (the "License")
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        https://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

part of '../../huawei_map_ohos.dart';

/// Platform type detector using Dart's Platform.isOhos
enum PlatformType {
  android,
  harmonyos,
}

/// Current platform detector
PlatformType _currentPlatform = PlatformDetector.isHarmonyOS ? PlatformType.harmonyos : PlatformType.android;

/// Platform detector utility class
class PlatformDetector {
  /// Auto-configure platform based on Platform.isOhos
  static void autoConfigurePlatform() {
    _currentPlatform = isHarmonyOS? PlatformType.harmonyos : PlatformType.android;
  }

  /// Check if current platform is HarmonyOS
  static bool get isHarmonyOS =>  Platform.operatingSystem=='ohos';

  /// Check if current platform is Android
  static bool get isAndroid => Platform.isAndroid;

  /// Get current platform type
  static PlatformType get currentPlatform => _currentPlatform;
}
