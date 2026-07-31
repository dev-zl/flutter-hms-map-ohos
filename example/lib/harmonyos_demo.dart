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

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:huawei_map_ohos/huawei_map_ohos.dart';

/// HarmonyOS 地图示例
/// HarmonyOS Map Example
class HarmonyOSMapDemo extends StatefulWidget {
  @override
  State<HarmonyOSMapDemo> createState() => _HarmonyOSMapDemoState();
}

class _HarmonyOSMapDemoState extends State<HarmonyOSMapDemo> {
  HuaweiMapController? _controller;
  int _nextMarkerId = 0;
  String _platformInfo = '检测平台中...';
  String _mapInfo = '地图未创建';

  @override
  void initState() {
    super.initState();
    _detectPlatform();
  }

  void _detectPlatform() {
    PlatformDetector.autoConfigurePlatform();
    setState(() {
      _platformInfo =
          '当前平台：${PlatformDetector.isHarmonyOS ? 'HarmonyOS' : 'Android'}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('HarmonyOS 地图示例'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            color: Colors.grey[200],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _platformInfo,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  _mapInfo,
                  style: TextStyle(color: Colors.blue),
                ),
              ],
            ),
          ),
          Expanded(
            child: HuaweiMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(39.9042, 116.4074),
                zoom: 12.0,
              ),
              onMapCreated: (HuaweiMapController controller) {
                _controller = controller;
                setState(() {
                  _mapInfo = '地图已创建 - 平台：${PlatformDetector.currentPlatform}';
                });
              },
              mapType: MapType.normal,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
              compassEnabled: true,
              markers: {
                Marker(
                  markerId: MarkerId('beijing'),
                  position: LatLng(39.9042, 116.4074),
                  infoWindow: InfoWindow(
                    title: '北京',
                    snippet: '中国首都',
                  ),
                ),
              },
              polygons: {
                Polygon(
                  polygonId: PolygonId('test_polygon'),
                  points: [
                    LatLng(39.9, 116.4),
                    LatLng(39.9, 116.5),
                    LatLng(39.8, 116.5),
                    LatLng(39.8, 116.4),
                  ],
                  strokeWidth: 2,
                  strokeColor: Colors.red,
                  fillColor: Colors.red.withOpacity(0.3),
                ),
              },
              polylines: {
                Polyline(
                  polylineId: PolylineId('test_polyline'),
                  points: [
                    LatLng(39.9042, 116.4074),
                    LatLng(39.8042, 116.3074),
                  ],
                  width: 5,
                  color: Colors.blue,
                ),
              },
              circles: {
                Circle(
                  circleId: CircleId('test_circle'),
                  center: LatLng(39.9042, 116.4074),
                  radius: 1000,
                  fillColor: Colors.green.withOpacity(0.3),
                  strokeColor: Colors.green,
                  strokeWidth: 2,
                ),
              },
              onCameraMoveStarted: (int? i) {
                print('相机开始移动');
              },
              onCameraMove: (CameraPosition position) {
                setState(() {
                  _mapInfo =
                      '相机位置：${position.target.lng}, ${position.target.lat}';
                });
              },
              onCameraIdle: () {
                print('相机停止移动');
              },
              onClick: (LatLng position) {
                print('地图点击：$position');
              },
              onLongPress: (LatLng position) {
                print('地图长按：$position');
                _addMarker(position);
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _animateCamera(1),
                  child: Text('放大'),
                ),
                ElevatedButton(
                  onPressed: () => _animateCamera(-1),
                  child: Text('缩小'),
                ),
                ElevatedButton(
                  onPressed: _takeSnapshot,
                  child: Text('截图'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _animateCamera(int delta) async {
    if (_controller == null) return;

    final double currentZoom = await _controller!.getZoomLevel() ?? 12.0;
    final double newZoom = (currentZoom + delta).clamp(3.0, 20.0);

    await _controller!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(39.9042, 116.4074),
          zoom: newZoom,
        ),
      ),
    );
  }

  Future<void> _takeSnapshot() async {
    if (_controller == null) return;

    final Uint8List? snapshot = await _controller!.takeSnapshot();
    if (snapshot != null) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.memory(snapshot),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('关闭'),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _addMarker(LatLng position) {
    if (_controller == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('添加标记'),
        content: Text('在位置 $position 添加标记'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final Marker marker = Marker(
                markerId: MarkerId('command_marker_${_nextMarkerId++}'),
                position: position,
                infoWindow: InfoWindow(title: '命令式 Marker'),
              );
              await _controller!.addMarker(marker);
            },
            child: Text('确定'),
          ),
        ],
      ),
    );
  }
}
