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

/// A lightweight, non-interactive point rendered by a shared map overlay.
///
/// The radius is measured in logical screen pixels, so it stays the same size
/// while the map zoom changes. Mass points are append-only and need no ID.
@immutable
class MassPoint {
  const MassPoint({
    required this.center,
    required this.screenRadius,
    required this.color,
  }) : assert(screenRadius > 0);

  final LatLng center;
  final double screenRadius;
  final int color;
}
