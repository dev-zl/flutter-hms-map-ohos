package com.huawei.hms.flutter.map.marker;

import android.animation.ValueAnimator;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Point;
import android.view.animation.AccelerateDecelerateInterpolator;
import com.huawei.hms.maps.HuaweiMap;
import com.huawei.hms.maps.Projection;
import com.huawei.hms.maps.model.BitmapDescriptorFactory;
import com.huawei.hms.maps.model.LatLng;
import com.huawei.hms.maps.model.Marker;
import com.huawei.hms.maps.model.MarkerOptions;
import java.util.List;
import java.util.Map;

/** Moves the original icon and its middle dot along the same line from the fixed ground point. */
final class MarkerAppearance {
    private final HuaweiMap map;
    private final Marker marker;
    private final Marker dot;
    private final float density;
    private LatLng logicalPosition;
    private ValueAnimator animator;
    private float iconWidth, iconHeight, anchorX, anchorY, offsetX, offsetY;
    private float dotSize, groundOffset, direction = -1;
    private int targetDirection = -1;
    private boolean sway, visible, disposed;

    static boolean enabled(Map<?, ?> data) {
        Map<?, ?> appearance = (Map<?, ?>) data.get("appearance");
        Object icon = data.get("icon");
        return appearance != null && Boolean.TRUE.equals(appearance.get("showAnchorDot"))
            && appearance.get("anchorDotColor") instanceof Number
            && icon instanceof List && "fromBytes".equals(((List<?>) icon).get(0));
    }

    MarkerAppearance(HuaweiMap map, Marker marker, float density, LatLng position, Map<?, ?> data) {
        this.map = map;
        this.marker = marker;
        this.density = density;
        logicalPosition = position;
        Map<?, ?> appearance = (Map<?, ?>) data.get("appearance");
        dotSize = ((Number) appearance.get("anchorDotSize")).floatValue();
        int color = ((Number) appearance.get("anchorDotColor")).intValue();
        int diameter = Math.max(1, Math.round(dotSize * density));
        Bitmap bitmap = Bitmap.createBitmap(diameter, diameter, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        paint.setColor(color);
        canvas.drawCircle(diameter / 2f, diameter / 2f, diameter / 2f, paint);
        dot = map.addMarker(new MarkerOptions().position(position)
            .icon(BitmapDescriptorFactory.fromBitmap(bitmap))
            .anchorMarker(.5f, .5f).clickable(false).clusterable(false)
            .visible(marker.isVisible()).zIndex(marker.getZIndex() - .01f));
    }

    void configure(Map<?, ?> data, LatLng position, float groundOffset, int requestedDirection) {
        Map<?, ?> appearance = (Map<?, ?>) data.get("appearance");
        List<?> anchor = (List<?>) data.get("anchor");
        List<?> offset = (List<?>) appearance.get("anchorDotOffset");
        byte[] icon = (byte[]) ((List<?>) data.get("icon")).get(1);
        android.graphics.BitmapFactory.Options bounds = new android.graphics.BitmapFactory.Options();
        bounds.inJustDecodeBounds = true;
        android.graphics.BitmapFactory.decodeByteArray(icon, 0, icon.length, bounds);
        iconWidth = bounds.outWidth / density;
        iconHeight = bounds.outHeight / density;
        anchorX = ((Number) anchor.get(0)).floatValue();
        anchorY = ((Number) anchor.get(1)).floatValue();
        offsetX = ((Number) offset.get(0)).floatValue();
        offsetY = ((Number) offset.get(1)).floatValue();
        dotSize = ((Number) appearance.get("anchorDotSize")).floatValue();
        this.groundOffset = groundOffset;
        logicalPosition = position;
        sway = Boolean.TRUE.equals(appearance.get("swayOnPan"));
        visible = !Boolean.FALSE.equals(data.get("visible"));
        dot.setVisible(visible);
        dot.setZIndex(marker.getZIndex() - .01f);
        dot.setAlpha(marker.getAlpha());
        marker.setMarkerAnchor(anchorX, anchorY);
        if (animator == null) direction = requestedDirection;
        targetDirection = requestedDirection;
        updatePositions();
    }

    void pan(int requestedDirection, boolean animated) {
        if (targetDirection == requestedDirection || disposed) return;
        targetDirection = requestedDirection;
        if (animator != null) animator.cancel();
        if (!animated || !visible || !sway) {
            direction = requestedDirection;
            updatePositions();
            return;
        }
        float start = direction;
        animator = ValueAnimator.ofFloat(start, requestedDirection);
        animator.setDuration(450);
        animator.setInterpolator(new AccelerateDecelerateInterpolator());
        animator.addUpdateListener(value -> {
            direction = (float) value.getAnimatedValue();
            updatePositions();
        });
        animator.start();
    }

    void setGroundOffset(float offset) {
        groundOffset = offset;
        updatePositions();
    }

    void updatePositions() {
        if (disposed || !visible) return;
        float shift = sway ? direction * iconWidth * .9f : 0;
        float markerX = shift - offsetX;
        float markerY = -offsetY;
        float markerRadius = Math.min(iconWidth, iconHeight) / 2;
        float centerOffsetX = (0.5f - anchorX) * iconWidth;
        float centerOffsetY = (1 - anchorY) * iconHeight - markerRadius;
        float centerX = markerX + centerOffsetX;
        float centerY = markerY + centerOffsetY;
        float fromGroundY = centerY - groundOffset;
        float contactDistance = markerRadius + dotSize / 2 - dotSize * .11f;
        // Derive one scale from the end position, then keep it unchanged for the
        // whole transition. This makes the marker travel on a horizontal line.
        float endpointX = Math.abs(centerOffsetX - offsetX) + (sway ? iconWidth * .9f : 0);
        float endpointLength = (float) Math.hypot(endpointX, fromGroundY);
        float targetLength = Math.min(endpointLength, contactDistance + dotSize * 1.05f);
        float pairScale = endpointLength > 0 ? targetLength / endpointLength : 1;
        centerX *= pairScale;
        centerY = groundOffset + fromGroundY * pairScale - 2;
        markerX = centerX - centerOffsetX;
        markerY = centerY - centerOffsetY;

        // Use the endpoint to choose a fixed Y for the middle dot. X remains an
        // interpolation on the same line, matching the iOS horizontal motion.
        float adjustedEndpointLength = (float) Math.hypot(endpointX * pairScale, groundOffset - centerY);
        float contactFraction = adjustedEndpointLength > 0
            ? Math.min(1, contactDistance / adjustedEndpointLength) : 0;
        float middleY = centerY + (groundOffset - centerY) * contactFraction;
        float lineFraction = groundOffset != centerY
            ? (groundOffset - middleY) / (groundOffset - centerY) : 0;
        float middleX = centerX * lineFraction;

        Projection projection = map.getProjection();
        Point base = projection.toScreenLocation(logicalPosition);
        marker.setPosition(projection.fromScreenLocation(new Point(
            Math.round(base.x + markerX * density), Math.round(base.y + markerY * density))));
        dot.setPosition(projection.fromScreenLocation(new Point(
            Math.round(base.x + middleX * density), Math.round(base.y + middleY * density))));
    }

    void dispose() {
        if (disposed) return;
        disposed = true;
        if (animator != null) animator.cancel();
        dot.remove();
    }
}
