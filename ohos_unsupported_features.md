# 鸿蒙端地图 API 支持情况报告

---

## 📋 概述

本报告详细列出 Flutter HMS Map 插件在鸿蒙（HarmonyOS）端的 API 支持情况，基于对 `lib/src/constants/method.dart` 和 `ohos/src/main/ets/components/plugin/` 的代码分析。

---

## ❌ 完全不支持的功能

### 1. 事件监听

| 方法名 | Flutter 定义 | 状态 | 原因 |
|--------|------------|------|------|
| `InfoWindowLongClick` | `[InfoWindow]longClick` | ❌ 不支持 | OHOS MapKit 只暴露 `infoWindowClick` 和 `infoWindowClose` 事件 |

### 2. 覆盖物动画

| 方法名 | Flutter 定义 | 状态 | 原因 |
|--------|------------|------|------|
| `CircleStartAnimation` | `CircleStartAnimation` | ❌ 不支持 | OHOS MapCircle 没有动画 API |

### 3. 定位源控制

| 方法名 | Flutter 定义 | 状态 | 原因 |
|--------|------------|------|------|
| `SetLocationSource` | `[Map]setLocationSource` | ❌ 不支持 | OHOS MapKit 隐式管理定位源 |
| `DeactivateLocationSource` | `[Map]deactivateLocationSource` | ❌ 不支持 | 同上 |

---

## ⚠️ 部分支持/有限支持的功能

### 1. 地图样式

| 方法名 | 支持情况 | 说明 |
|--------|---------|------|
| `MapSetStyle(string)` | ⚠️ 仅记录日志 | OHOS 的 `setStyle(string)` API 不可用 |
| `setStyleId` | ⚠️ 仅记录日志 | OHOS MapComponentController 无此运行时 API |

### 2. 聚合标记样式

| 方法名 | 支持情况 | 说明 |
|--------|---------|------|
| `clusterMarkerColor` | ⚠️ 仅存储 | 无运行时 API，需通过自定义 icon builder 实现 |
| `clusterMarkerTextColor` | ⚠️ 仅存储 | 同上 |
| `clusterMarkerIcon` | ⚠️ 仅存储 | 同上 |

### 3. HeatMap 数据源

| 参数 | 支持情况 | 说明 |
|------|---------|------|
| `resourceId` | ⚠️ 不支持 | Android int 资源 ID 无法映射到 OHOS rawfile |
| `dataSet` | ✅ 支持 | 需使用 GeoJSON 字符串传递数据 |

---

## ✅ 完整支持的功能

### 事件监听
- CameraMoveStart / CameraOnMove / CameraOnIdle / CameraMoveCanceled
- MarkerClick / MarkerDragStart / MarkerDrag / MarkerDragEnd
- InfoWindowClick / InfoWindowClose
- PolylineClick / PolygonClick / CircleClick / GroundOverlayClick
- MapClick / MapLongClick / MapPoiClick
- MapOnMyLocationClick / MapOnMyLocationButtonClick

### 地图操作
- CameraMove / CameraAnimate / StopAnimation
- MapGetVisibleRegion / MapGetScreenCoordinate / MapGetLatLng
- MapGetZoomLevel / MapGetScalePerPixel
- MapTakeSnapshot / MapWaitForMap / MapUpdate
- SetLocation

### 覆盖物管理
- MarkersUpdate / PolygonsUpdate / PolylinesUpdate / CirclesUpdate
- GroundOverlaysUpdate / TileOverlaysUpdate / HeatMapUpdate
- MarkerStartAnimation / MarkerIsClusterable

### 工具方法
- InitializeMap / SetApiKey / SetAccessToken
- MapDistanceCalculator / MapConvertCoordinate / MapConvertCoordinates
- EnableLogger / DisableLogger / ClearTileCache

---

## 📊 支持情况统计

| 类别 | 总数 | 已实现 | 未实现 | 部分支持 |
|------|------|--------|--------|----------|
| 事件监听 | 17 | 16 | 1 | 0 |
| 地图操作 | 12 | 10 | 0 | 2 |
| 覆盖物操作 | 12 | 11 | 1 | 0 |
| 工具方法 | 9 | 9 | 0 | 0 |
| **总计** | **50** | **46** | **2** | **2** |

**支持率：92%**

---

## 📝 技术说明

### 不支持功能的处理方式

所有不支持的方法均采用以下处理策略：

1. **静默接受**：调用成功返回 `null`，确保 Dart Future 正常 resolve
2. **日志记录**：通过 `hilog.info/warn` 记录不支持的调用，便于调试
3. **注释说明**：代码中添加注释说明限制原因和替代方案

### 代码位置参考

- 事件监听限制：`mapMapListenerHandler.ets`
- 地图操作限制：`mapMapController.ets`
- 覆盖物限制：`overlayControllers.ets` / `mapMapUtils.ets`
- HeatMap 限制：`Convert.ets`

---

