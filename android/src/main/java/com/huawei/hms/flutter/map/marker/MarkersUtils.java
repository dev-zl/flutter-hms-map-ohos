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

package com.huawei.hms.flutter.map.marker;

import android.app.Application;

import com.huawei.hms.flutter.map.constants.Method;
import com.huawei.hms.flutter.map.constants.Param;
import com.huawei.hms.flutter.map.logger.HMSLogger;
import com.huawei.hms.flutter.map.utils.Convert;
import com.huawei.hms.flutter.map.utils.ToJson;
import com.huawei.hms.maps.HuaweiMap;
import com.huawei.hms.maps.model.LatLng;
import com.huawei.hms.maps.model.LatLngBounds;
import com.huawei.hms.maps.model.Marker;
import com.huawei.hms.maps.model.MarkerOptions;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class MarkersUtils {
    private HuaweiMap huaweiMap;
    private final float density;
    private int panDirection = -1;
    private float lastZoom = Float.NaN, lastBearing = Float.NaN, lastTilt = Float.NaN;
    private final Map<LatLng, Float> groundOffsets = new HashMap<>();
    private static final double PAN_CELL_SIZE = 0.02;
    private final Map<String, Map<String, MarkerController>> panCells = new HashMap<>();
    private final Map<String, String> panCellById = new HashMap<>();

    private final MethodChannel mChannel;

    private BinaryMessenger messenger;

    private final Map<String, MarkerController> idsOnMap;

    private final Map<String, String> ids;

    private final HMSLogger logger;

    public MarkersUtils(final MethodChannel mChannel, final Application application) {
        density = application.getResources().getDisplayMetrics().density;
        idsOnMap = new HashMap<>();
        ids = new HashMap<>();
        this.mChannel = mChannel;
        logger = HMSLogger.getInstance(application);
    }

    public void setMap(final HuaweiMap huaweiMap) {
        this.huaweiMap = huaweiMap;
    }

    public void insertMulti(final List<HashMap<String, Object>> markerList, final BinaryMessenger messenger) {
        this.messenger = messenger;
        if (markerList == null) {
            return;
        }

        for (final HashMap<String, Object> markerToAdd : markerList) {
            insert(markerToAdd, messenger);
        }
    }

    private void insert(final HashMap<String, Object> marker, final BinaryMessenger messenger) {
        if (huaweiMap == null) {
            return;
        }
        if (marker == null) {
            return;
        }

        final MarkerBuilder markerBuilder = new MarkerBuilder();
        final String id = Convert.processMarkerOptions(marker, markerBuilder, messenger);
        final MarkerOptions options = markerBuilder.build();

        logger.startMethodExecutionTimer("addMarker");
        final Marker newMarker = huaweiMap.addMarker(options);
        logger.sendSingleEvent("addMarker");

        final MarkerController controller = new MarkerController(
            newMarker, markerBuilder.isClusterable(), huaweiMap, density);
        controller.setAnimationSet(markerBuilder.getAnimationSet());
        controller.configureAppearance(marker,
            groundOffsets.getOrDefault(controller.position(), 0f), panDirection);

        idsOnMap.put(id, controller);
        ids.put(newMarker.getId(), id);
        reindexPanMarker(id, controller);
    }

    private void update(final HashMap<String, Object> marker) {
        if (marker == null) {
            return;
        }
        final String markerId = getId(marker);
        final MarkerController markerController = idsOnMap.get(markerId);
        if (markerController != null) {
            Convert.processMarkerOptions(marker, markerController, messenger);
            markerController.configureAppearance(marker,
                groundOffsets.getOrDefault(markerController.position(), 0f), panDirection);
            reindexPanMarker(markerId, markerController);
        }
    }

    public void updateMulti(final List<HashMap<String, Object>> marker) {
        if (marker == null) {
            return;
        }

        for (final HashMap<String, Object> markerToChange : marker) {
            update(markerToChange);
        }
    }

    public void deleteMulti(final List<String> markerList) {
        if (markerList == null) {
            return;
        }

        for (final String id : markerList) {
            if (id == null) {
                continue;
            }

            final MarkerController markerController = idsOnMap.remove(id);
            removePanMarker(id);
            if (markerController != null) {

                logger.startMethodExecutionTimer("removeMarker");
                markerController.delete();
                logger.sendSingleEvent("removeMarker");

                ids.remove(markerController.getMapMarkerId());
            }
        }
    }

    public void isMarkerClusterable(final String id, final MethodChannel.Result result) {
        final MarkerController markerController = idsOnMap.get(id);
        if (markerController == null) {
            return;
        }
        result.success(markerController.isClusterable());
    }

    public void showInfoWindow(final String id, final MethodChannel.Result result) {
        final MarkerController markerController = idsOnMap.get(id);
        if (markerController == null) {
            return;
        }

        markerController.showInfoWindow();
        result.success(null);
    }

    public void hideInfoWindow(final String id, final MethodChannel.Result result) {
        final MarkerController markerController = idsOnMap.get(id);
        if (markerController == null) {
            return;
        }

        markerController.hideInfoWindow();
        result.success(null);
    }

    public void isInfoWindowShown(final String id, final MethodChannel.Result result) {
        final MarkerController markerController = idsOnMap.get(id);
        if (markerController == null) {
            return;
        }
        result.success(markerController.isInfoWindowShown());
    }

    public boolean onMarkerClick(final String idOnMap) {
        logger.startMethodExecutionTimer("onMarkerClick");
        final String id = ids.get(idOnMap);
        if (id == null) {
            return false;
        }
        mChannel.invokeMethod(Method.MARKER_CLICK, markerIdToJson(id));
        logger.sendSingleEvent("onMarkerClick");

        final MarkerController markerController = idsOnMap.get(id);

        if (markerController != null) {
            markerController.showInfoWindow();
            return markerController.isClickable();
        }
        return false;

    }

    public void onMarkerDragEnd(final String idOnMap, final LatLng latLng) {
        final String id = ids.get(idOnMap);
        if (id == null) {
            return;
        }

        final Map<String, Object> args = new HashMap<>();
        args.put(Param.MARKER_ID, id);
        args.put(Param.POSITION, ToJson.latLng(latLng));
        mChannel.invokeMethod(Method.MARKER_ON_DRAG_END, args);
    }

    public void onMarkerDragStart(final String idOnMap, final LatLng latLng) {
        final String id = ids.get(idOnMap);
        if (id == null) {
            return;
        }

        final Map<String, Object> args = new HashMap<>();
        args.put(Param.MARKER_ID, id);
        args.put(Param.POSITION, ToJson.latLng(latLng));
        mChannel.invokeMethod(Method.MARKER_ON_DRAG_START, args);
    }

    public void onMarkerDrag(final String idOnMap, final LatLng latLng) {
        final String id = ids.get(idOnMap);
        if (id == null) {
            return;
        }

        final Map<String, Object> args = new HashMap<>();
        args.put(Param.MARKER_ID, id);
        args.put(Param.POSITION, ToJson.latLng(latLng));
        mChannel.invokeMethod(Method.MARKER_ON_DRAG, args);
    }

    public void onInfoWindowClick(final String idOnMap) {
        final String markerId = ids.get(idOnMap);
        if (markerId == null) {
            return;
        }

        mChannel.invokeMethod(Method.INFO_WINDOW_CLICK, markerIdToJson(markerId));
    }

    public void onInfoWindowLongClick(final String idOnMap) {
        final String markerId = ids.get(idOnMap);
        if (markerId == null) {
            return;
        }

        mChannel.invokeMethod(Method.INFO_WINDOW_LONG_CLICK, markerIdToJson(markerId));
    }

    public void onInfoWindowClose(final String idOnMap) {
        final String markerId = ids.get(idOnMap);
        if (markerId == null) {
            return;
        }

        mChannel.invokeMethod(Method.INFO_WINDOW_CLOSE, markerIdToJson(markerId));
    }

    private static String getId(final HashMap<String, Object> marker) {
        return (String) marker.get(Param.MARKER_ID);
    }

    private static HashMap<String, Object> markerIdToJson(final String markerId) {
        if (markerId == null) {
            return null;
        }

        final HashMap<String, Object> data = new HashMap<>();
        data.put(Param.MARKER_ID, markerId);
        return data;
    }

    public void setPanDirection(int direction) {
        if (direction == panDirection || huaweiMap == null) return;
        panDirection = direction;
        refreshVisiblePanMarkers(true);
    }

    public void refreshVisiblePanMarkers() {
        refreshVisiblePanMarkers(false);
    }

    private void refreshVisiblePanMarkers(boolean animated) {
        if (huaweiMap == null || panCells.isEmpty()) return;
        LatLngBounds bounds =
            huaweiMap.getProjection().getVisibleRegion().latLngBounds;
        int south = cell(bounds.southwest.latitude);
        int north = cell(bounds.northeast.latitude);
        int west = cell(bounds.southwest.longitude);
        int east = cell(bounds.northeast.longitude);
        long cellCount = (long) (north - south + 1) *
            (west <= east ? east - west + 1 : cell(180) - west + east - cell(-180) + 2);
        if (cellCount > panCells.size()) {
            for (Map<String, MarkerController> bucket : panCells.values()) {
                panBucket(bucket, bounds, panDirection, animated);
            }
            return;
        }
        for (int lat = south; lat <= north; lat++) {
            if (west <= east) {
                for (int lon = west; lon <= east; lon++) {
                    panBucket(panCells.get(lat + ":" + lon), bounds, panDirection, animated);
                }
            } else {
                for (int lon = west; lon <= cell(180); lon++) {
                    panBucket(panCells.get(lat + ":" + lon), bounds, panDirection, animated);
                }
                for (int lon = cell(-180); lon <= east; lon++) {
                    panBucket(panCells.get(lat + ":" + lon), bounds, panDirection, animated);
                }
            }
        }
    }

    private static int cell(double coordinate) {
        return (int) Math.floor(coordinate / PAN_CELL_SIZE);
    }

    private static String panCell(LatLng position) {
        return cell(position.latitude) + ":" + cell(position.longitude);
    }

    private void removePanMarker(String id) {
        String key = panCellById.remove(id);
        if (key == null) return;
        Map<String, MarkerController> bucket = panCells.get(key);
        bucket.remove(id);
        if (bucket.isEmpty()) panCells.remove(key);
    }

    private void reindexPanMarker(String id, MarkerController controller) {
        removePanMarker(id);
        if (!controller.needsPanUpdate()) return;
        String key = panCell(controller.position());
        panCells.computeIfAbsent(key, ignored -> new HashMap<>()).put(id, controller);
        panCellById.put(id, key);
    }

    private static void panBucket(Map<String, MarkerController> bucket,
                                  LatLngBounds bounds, int direction, boolean animated) {
        if (bucket == null) return;
        for (MarkerController controller : bucket.values()) {
            if (bounds.contains(controller.position())) controller.pan(direction, animated);
        }
    }

    public void setGroundPoints(List<?> points, float offset) {
        if (points == null) return;
        for (Object value : points) {
            List<?> center = (List<?>) ((Map<?, ?>) value).get("center");
            groundOffsets.put(new LatLng(
                ((Number) center.get(0)).doubleValue(),
                ((Number) center.get(1)).doubleValue()), offset);
        }
        for (MarkerController controller : idsOnMap.values()) {
            controller.groundOffset(groundOffsets.getOrDefault(controller.position(), 0f));
        }
    }

    public void updateAppearancePositions() {
        if (huaweiMap == null) return;
        com.huawei.hms.maps.model.CameraPosition camera = huaweiMap.getCameraPosition();
        if (camera.zoom == lastZoom && camera.bearing == lastBearing && camera.tilt == lastTilt) return;
        lastZoom = camera.zoom;
        lastBearing = camera.bearing;
        lastTilt = camera.tilt;
        for (MarkerController controller : idsOnMap.values()) controller.updateAppearancePosition();
    }

    public void disposeAppearances() {
        for (MarkerController controller : idsOnMap.values()) controller.disposeAppearance();
        panCells.clear();
        panCellById.clear();
        groundOffsets.clear();
    }

    public void startAnimation(final String id) {
        final MarkerController markerController = idsOnMap.get(id);
        if (markerController != null) {
            markerController.startAnimation();
        }
    }

}
