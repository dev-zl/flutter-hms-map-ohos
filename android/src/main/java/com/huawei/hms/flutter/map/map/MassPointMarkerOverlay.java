/*
 * Copyright 2020-2024. Huawei Technologies Co., Ltd. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 */

package com.huawei.hms.flutter.map.map;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;

import com.huawei.hms.maps.HuaweiMap;
import com.huawei.hms.maps.model.BitmapDescriptor;
import com.huawei.hms.maps.model.BitmapDescriptorFactory;
import com.huawei.hms.maps.model.LatLng;
import com.huawei.hms.maps.model.LatLngBounds;
import com.huawei.hms.maps.model.Marker;
import com.huawei.hms.maps.model.MarkerOptions;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Collections;
import java.util.IdentityHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Keeps a bounded pool of native, fixed-size markers for visible mass points.
 * No projection, query, marker creation, or marker update occurs while the
 * camera is moving.
 */
final class MassPointMarkerOverlay {
    private static final String CENTER = "center";
    private static final String SCREEN_RADIUS = "screenRadius";
    private static final int POINT_COLOR = 0xFF22C55E;
    private static final int MAX_VISIBLE_MARKERS = 800;
    private static final int SAMPLE_COLUMNS = 32;
    private static final int SAMPLE_ROWS = 25;
    private static final double VIEWPORT_PADDING_RATIO = 0.1;

    private final float density;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final PointQuadTree spatialIndex = new PointQuadTree();
    private final Map<MassPoint, Marker> activeMarkers = new IdentityHashMap<>();
    private final ArrayDeque<Marker> markerPool = new ArrayDeque<>();
    private final List<List<?>> pendingBatches = new ArrayList<>();
    private final Runnable refreshMarkers = this::refreshVisibleMarkers;

    private HuaweiMap huaweiMap;
    private BitmapDescriptor pointIcon;
    private Bitmap pointIconBitmap;
    private float pointIconAnchorV = 0.5f;
    private double screenRadius = 1.0;
    private double iconRadius = -1.0;
    private double verticalOffset;
    private double iconVerticalOffset = -1.0;
    private boolean cameraMoving;
    private boolean disposed;

    MassPointMarkerOverlay(float density) {
        this.density = density;
    }

    void setMap(@NonNull HuaweiMap map) {
        huaweiMap = map;
        scheduleRefresh();
    }

    void setCameraMoving(boolean moving) {
        cameraMoving = moving;
        if (moving) {
            mainHandler.removeCallbacks(refreshMarkers);
            return;
        }
        flushPendingBatches();
        scheduleRefresh();
    }

    void addMassPoints(List<?> values, double requestedVerticalOffset) {
        if (disposed || values == null || values.isEmpty()) {
            return;
        }
        verticalOffset = Math.max(0.0, requestedVerticalOffset);
        if (cameraMoving) {
            pendingBatches.add(new ArrayList<>(values));
            return;
        }
        if (indexPoints(values)) {
            scheduleRefresh();
        }
    }

    void refreshVisibleMarkers() {
        mainHandler.removeCallbacks(refreshMarkers);
        if (disposed || cameraMoving || huaweiMap == null || spatialIndex.isEmpty()) {
            return;
        }

        final LatLngBounds bounds;
        try {
            bounds = huaweiMap.getProjection().getVisibleRegion().latLngBounds;
        } catch (RuntimeException exception) {
            return;
        }
        if (bounds == null) {
            return;
        }

        ensurePointIcon();
        final Viewport viewport = Viewport.from(bounds, VIEWPORT_PADDING_RATIO);
        final List<MassPoint> desiredPoints = selectVisiblePoints(viewport);
        final Set<MassPoint> desiredSet = Collections.newSetFromMap(new IdentityHashMap<>());
        desiredSet.addAll(desiredPoints);

        final List<MassPoint> pointsToHide = new ArrayList<>();
        for (MassPoint point : activeMarkers.keySet()) {
            if (!desiredSet.contains(point)) {
                pointsToHide.add(point);
            }
        }
        for (MassPoint point : pointsToHide) {
            final Marker marker = activeMarkers.remove(point);
            if (marker != null) {
                marker.setVisible(false);
                markerPool.addLast(marker);
            }
        }

        for (MassPoint point : desiredPoints) {
            if (activeMarkers.containsKey(point)) {
                continue;
            }
            final Marker marker;
            if (markerPool.isEmpty()) {
                marker = huaweiMap.addMarker(new MarkerOptions()
                    .position(new LatLng(point.latitude, point.longitude))
                    .icon(pointIcon)
                    .anchorMarker(0.5f, pointIconAnchorV)
                    .clickable(false)
                    .draggable(false)
                    .flat(false)
                    .visible(true)
                    .zIndex(Float.MAX_VALUE));
            } else {
                marker = markerPool.removeFirst();
                marker.setPosition(new LatLng(point.latitude, point.longitude));
                marker.setIcon(pointIcon);
                marker.setMarkerAnchor(0.5f, pointIconAnchorV);
                marker.setVisible(true);
            }
            activeMarkers.put(point, marker);
        }
    }

    void clear() {
        disposed = true;
        mainHandler.removeCallbacks(refreshMarkers);
        pendingBatches.clear();
        for (Marker marker : activeMarkers.values()) {
            marker.remove();
        }
        activeMarkers.clear();
        while (!markerPool.isEmpty()) {
            markerPool.removeFirst().remove();
        }
        spatialIndex.clear();
        huaweiMap = null;
        pointIcon = null;
        if (pointIconBitmap != null) {
            pointIconBitmap.recycle();
            pointIconBitmap = null;
        }
    }

    private void scheduleRefresh() {
        if (disposed || cameraMoving) {
            return;
        }
        mainHandler.removeCallbacks(refreshMarkers);
        mainHandler.post(refreshMarkers);
    }

    private void flushPendingBatches() {
        if (pendingBatches.isEmpty()) {
            return;
        }
        for (List<?> batch : pendingBatches) {
            indexPoints(batch);
        }
        pendingBatches.clear();
    }

    private boolean indexPoints(List<?> values) {
        boolean changed = false;
        for (Object value : values) {
            if (!(value instanceof Map)) {
                continue;
            }
            final Map<?, ?> data = (Map<?, ?>) value;
            final Object centerValue = data.get(CENTER);
            final Object radiusValue = data.get(SCREEN_RADIUS);
            if (!(centerValue instanceof List)
                || ((List<?>) centerValue).size() < 2
                || !(radiusValue instanceof Number)) {
                continue;
            }
            final List<?> center = (List<?>) centerValue;
            if (!(center.get(0) instanceof Number) || !(center.get(1) instanceof Number)) {
                continue;
            }
            final double latitude = ((Number) center.get(0)).doubleValue();
            final double longitude = ((Number) center.get(1)).doubleValue();
            final double radius = ((Number) radiusValue).doubleValue();
            if (!Double.isFinite(latitude)
                || !Double.isFinite(longitude)
                || !Double.isFinite(radius)
                || latitude < -90.0
                || latitude > 90.0
                || radius <= 0.0) {
                continue;
            }
            spatialIndex.add(new MassPoint(latitude, longitude));
            screenRadius = Math.max(screenRadius, radius);
            changed = true;
        }
        return changed;
    }

    private List<MassPoint> selectVisiblePoints(Viewport viewport) {
        final List<MassPoint> visible = new ArrayList<>(MAX_VISIBLE_MARKERS + 1);
        spatialIndex.query(viewport, visible, MAX_VISIBLE_MARKERS + 1);
        if (visible.size() <= MAX_VISIBLE_MARKERS) {
            return visible;
        }

        final List<MassPoint> sampled = new ArrayList<>(MAX_VISIBLE_MARKERS);
        final Set<MassPoint> sampledSet = Collections.newSetFromMap(new IdentityHashMap<>());
        final double cellWidth = viewport.width() / SAMPLE_COLUMNS;
        final double cellHeight = (viewport.maxLatitude - viewport.minLatitude) / SAMPLE_ROWS;
        for (int row = 0; row < SAMPLE_ROWS; row++) {
            final double minLatitude = viewport.minLatitude + row * cellHeight;
            final double maxLatitude = row == SAMPLE_ROWS - 1
                ? viewport.maxLatitude
                : minLatitude + cellHeight;
            for (int column = 0; column < SAMPLE_COLUMNS; column++) {
                final double startX = viewport.startX + column * cellWidth;
                final double endX = column == SAMPLE_COLUMNS - 1
                    ? viewport.endX
                    : startX + cellWidth;
                final MassPoint point = spatialIndex.findFirstWrapped(
                    startX, endX, minLatitude, maxLatitude);
                if (point != null && sampledSet.add(point)) {
                    sampled.add(point);
                }
            }
        }
        return sampled;
    }

    private void ensurePointIcon() {
        if (pointIcon != null
            && iconRadius == screenRadius
            && iconVerticalOffset == verticalOffset) {
            return;
        }
        final int diameter = Math.max(2, (int) Math.ceil(screenRadius * 2.0 * density));
        final int offsetPixels = Math.max(0, (int) Math.round(verticalOffset * density));
        final int height = diameter + offsetPixels;
        final Bitmap bitmap = Bitmap.createBitmap(diameter, height, Bitmap.Config.ARGB_8888);
        final Canvas canvas = new Canvas(bitmap);
        final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        paint.setColor(POINT_COLOR);
        paint.setStyle(Paint.Style.FILL);
        canvas.drawCircle(
            diameter * 0.5f,
            offsetPixels + diameter * 0.5f,
            diameter * 0.5f,
            paint);
        pointIcon = BitmapDescriptorFactory.fromBitmap(bitmap);
        iconRadius = screenRadius;
        iconVerticalOffset = verticalOffset;
        final float anchorV = (diameter * 0.5f) / height;
        pointIconAnchorV = anchorV;

        for (Marker marker : activeMarkers.values()) {
            marker.setIcon(pointIcon);
            marker.setMarkerAnchor(0.5f, anchorV);
        }
        for (Marker marker : markerPool) {
            marker.setIcon(pointIcon);
            marker.setMarkerAnchor(0.5f, anchorV);
        }
        if (pointIconBitmap != null) {
            pointIconBitmap.recycle();
        }
        pointIconBitmap = bitmap;
    }

    private static double normalizeLongitude(double longitude) {
        return ((longitude + 180.0) % 360.0 + 360.0) % 360.0 / 360.0;
    }

    private static final class MassPoint {
        final double latitude;
        final double longitude;
        final double x;

        MassPoint(double latitude, double longitude) {
            this.latitude = latitude;
            this.longitude = longitude;
            x = normalizeLongitude(longitude);
        }
    }

    private static final class Viewport {
        final double startX;
        final double endX;
        final double minLatitude;
        final double maxLatitude;

        Viewport(double startX, double endX, double minLatitude, double maxLatitude) {
            this.startX = startX;
            this.endX = endX;
            this.minLatitude = minLatitude;
            this.maxLatitude = maxLatitude;
        }

        static Viewport from(LatLngBounds bounds, double paddingRatio) {
            final double westX = normalizeLongitude(bounds.southwest.longitude);
            final double eastX = normalizeLongitude(bounds.northeast.longitude);
            double width = eastX - westX;
            if (width < 0.0 || bounds.southwest.longitude > bounds.northeast.longitude) {
                width += 1.0;
            }
            final double longitudePadding = width * paddingRatio;
            final double latitudeSpan = bounds.northeast.latitude - bounds.southwest.latitude;
            final double latitudePadding = latitudeSpan * paddingRatio;
            return new Viewport(
                westX - longitudePadding,
                westX + width + longitudePadding,
                Math.max(-90.0, bounds.southwest.latitude - latitudePadding),
                Math.min(90.0, bounds.northeast.latitude + latitudePadding));
        }

        double width() {
            return endX - startX;
        }
    }

    private static final class PointQuadTree {
        private static final int LEAF_CAPACITY = 64;
        private static final int MAX_DEPTH = 18;
        private Node root = new Node(0.0, -90.0, 1.0, 90.0);
        private int size;

        void add(MassPoint point) {
            root.add(point, 0);
            size++;
        }

        boolean isEmpty() {
            return size == 0;
        }

        void query(Viewport viewport, List<MassPoint> result, int limit) {
            queryWrapped(viewport.startX, viewport.endX,
                viewport.minLatitude, viewport.maxLatitude, result, limit);
        }

        MassPoint findFirstWrapped(double startX, double endX,
            double minLatitude, double maxLatitude) {
            final List<MassPoint> result = new ArrayList<>(1);
            queryWrapped(startX, endX, minLatitude, maxLatitude, result, 1);
            return result.isEmpty() ? null : result.get(0);
        }

        void clear() {
            root = new Node(0.0, -90.0, 1.0, 90.0);
            size = 0;
        }

        private void queryWrapped(double startX, double endX, double minLatitude,
            double maxLatitude, List<MassPoint> result, int limit) {
            if (endX - startX >= 1.0) {
                root.query(0.0, minLatitude, 1.0, maxLatitude, result, limit);
                return;
            }
            final double normalizedStart = startX - Math.floor(startX);
            final double normalizedEnd = normalizedStart + (endX - startX);
            if (normalizedEnd <= 1.0) {
                root.query(normalizedStart, minLatitude, normalizedEnd, maxLatitude, result, limit);
            } else {
                root.query(normalizedStart, minLatitude, 1.0, maxLatitude, result, limit);
                if (result.size() < limit) {
                    root.query(0.0, minLatitude, normalizedEnd - 1.0, maxLatitude, result, limit);
                }
            }
        }

        private static final class Node {
            final double minX;
            final double minY;
            final double maxX;
            final double maxY;
            List<MassPoint> values = new ArrayList<>();
            Node[] children;

            Node(double minX, double minY, double maxX, double maxY) {
                this.minX = minX;
                this.minY = minY;
                this.maxX = maxX;
                this.maxY = maxY;
            }

            void add(MassPoint point, int depth) {
                if (children != null) {
                    childFor(point).add(point, depth + 1);
                    return;
                }
                values.add(point);
                if (values.size() > LEAF_CAPACITY && depth < MAX_DEPTH) {
                    split(depth);
                }
            }

            void query(double queryMinX, double queryMinY, double queryMaxX, double queryMaxY,
                List<MassPoint> result, int limit) {
                if (result.size() >= limit
                    || queryMaxX < minX
                    || queryMinX > maxX
                    || queryMaxY < minY
                    || queryMinY > maxY) {
                    return;
                }
                if (children != null) {
                    for (Node child : children) {
                        child.query(queryMinX, queryMinY, queryMaxX, queryMaxY, result, limit);
                        if (result.size() >= limit) {
                            return;
                        }
                    }
                    return;
                }
                for (MassPoint point : values) {
                    if (point.x >= queryMinX
                        && point.x <= queryMaxX
                        && point.latitude >= queryMinY
                        && point.latitude <= queryMaxY) {
                        result.add(point);
                        if (result.size() >= limit) {
                            return;
                        }
                    }
                }
            }

            private void split(int depth) {
                final double middleX = (minX + maxX) * 0.5;
                final double middleY = (minY + maxY) * 0.5;
                children = new Node[] {
                    new Node(minX, minY, middleX, middleY),
                    new Node(middleX, minY, maxX, middleY),
                    new Node(minX, middleY, middleX, maxY),
                    new Node(middleX, middleY, maxX, maxY)
                };
                final List<MassPoint> previousValues = values;
                values = null;
                for (MassPoint point : previousValues) {
                    childFor(point).add(point, depth + 1);
                }
            }

            private Node childFor(MassPoint point) {
                final double middleX = (minX + maxX) * 0.5;
                final double middleY = (minY + maxY) * 0.5;
                final int column = point.x >= middleX ? 1 : 0;
                final int row = point.latitude >= middleY ? 1 : 0;
                return children[row * 2 + column];
            }
        }
    }
}
