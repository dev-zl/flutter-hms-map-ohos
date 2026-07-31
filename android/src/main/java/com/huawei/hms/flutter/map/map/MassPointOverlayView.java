/*
 * Copyright 2020-2024. Huawei Technologies Co., Ltd. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 */

package com.huawei.hms.flutter.map.map;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Point;
import android.view.View;

import androidx.annotation.NonNull;

import com.huawei.hms.maps.HuaweiMap;
import com.huawei.hms.maps.model.LatLng;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Draws all mass points in one transparent Android view.
 *
 * Huawei Map Kit for Android has no MassPointOverlay equivalent. Keeping the
 * points in one view avoids creating a native Marker/Circle object per point
 * while retaining the fixed screen radius used by the Dart API.
 */
final class MassPointOverlayView extends View {
    private static final String CENTER = "center";
    private static final String SCREEN_RADIUS = "screenRadius";
    private static final String COLOR = "color";

    private final List<MassPoint> points = new ArrayList<>();
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final float density;
    private HuaweiMap huaweiMap;

    MassPointOverlayView(@NonNull Context context, float density) {
        super(context);
        this.density = density;
        paint.setStyle(Paint.Style.FILL);
        setClickable(false);
        setFocusable(false);
        setWillNotDraw(false);
    }

    void setMap(HuaweiMap map) {
        huaweiMap = map;
        invalidateForCameraChange();
    }

    void addMassPoints(List<?> values) {
        if (values == null || values.isEmpty()) {
            return;
        }
        for (Object value : values) {
            if (!(value instanceof Map)) {
                continue;
            }
            Map<?, ?> data = (Map<?, ?>) value;
            Object centerValue = data.get(CENTER);
            Object radiusValue = data.get(SCREEN_RADIUS);
            Object colorValue = data.get(COLOR);
            if (!(centerValue instanceof List)
                || ((List<?>) centerValue).size() < 2
                || !(radiusValue instanceof Number)
                || !(colorValue instanceof Number)) {
                continue;
            }
            List<?> center = (List<?>) centerValue;
            if (!(center.get(0) instanceof Number) || !(center.get(1) instanceof Number)) {
                continue;
            }
            points.add(new MassPoint(
                new LatLng(
                    ((Number) center.get(0)).doubleValue(),
                    ((Number) center.get(1)).doubleValue()),
                ((Number) radiusValue).floatValue() * density,
                ((Number) colorValue).intValue()));
        }
        invalidateForCameraChange();
    }

    void invalidateForCameraChange() {
        postInvalidateOnAnimation();
    }

    void clear() {
        points.clear();
        invalidate();
    }

    @Override
    protected void onDraw(@NonNull Canvas canvas) {
        super.onDraw(canvas);
        HuaweiMap map = huaweiMap;
        if (map == null || points.isEmpty()) {
            return;
        }
        for (MassPoint massPoint : points) {
            Point screenPoint = map.getProjection().toScreenLocation(massPoint.center);
            if (screenPoint == null) {
                continue;
            }
            paint.setColor(massPoint.color);
            canvas.drawCircle(
                screenPoint.x,
                screenPoint.y,
                massPoint.screenRadius,
                paint);
        }
    }

    private static final class MassPoint {
        final LatLng center;
        final float screenRadius;
        final int color;

        MassPoint(LatLng center, float screenRadius, int color) {
            this.center = center;
            this.screenRadius = screenRadius;
            this.color = color;
        }
    }
}
