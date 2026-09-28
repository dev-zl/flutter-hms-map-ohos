package com.huawei.hms.flutter.map.marker;

import android.animation.ValueAnimator;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.text.TextPaint;
import android.text.TextUtils;
import android.view.animation.AccelerateDecelerateInterpolator;

import com.huawei.hms.maps.HuaweiMap;
import com.huawei.hms.maps.model.BitmapDescriptorFactory;
import com.huawei.hms.maps.model.LatLng;
import com.huawei.hms.maps.model.Marker;
import com.huawei.hms.maps.model.MarkerOptions;
import com.huawei.hms.maps.model.animation.AlphaAnimation;
import com.huawei.hms.maps.model.animation.Animation;
import com.huawei.hms.maps.model.animation.ScaleAnimation;

import java.util.List;
import java.util.Locale;
import java.util.Map;

/** A native banner rendered below the business marker without changing its bitmap. */
final class MarkerBanner {
    private static final long EXPAND_DURATION = 340;
    private static final long COLLAPSE_DURATION = 240;
    private static final long DIRECTION_DURATION = 450;
    private static final float MAX_TEXT_WIDTH = 120;
    private static final float MAX_BITMAP_WIDTH_PX = 576;
    private static final float HORIZONTAL_PADDING = 12;
    private static final float MARKER_MARGIN_PX = 4;
    private static final float EXTRA_WIDTH_PX = 30;
    private static final float RIGHT_EXTRA_WIDTH_PX = 20;
    private static final float EXTRA_HEIGHT_PX = 20;
    private static final float TEXT_GAP = 6;
    private static final float VERTICAL_LIFT = 2;

    private final HuaweiMap map;
    private final Marker marker;
    private final float density;
    private Marker leftBanner;
    private Marker rightBanner;
    private ValueAnimator positionAnimator;
    private String title = "";
    private String subtitle = "";
    private int color;
    private int direction = -1;
    private boolean expanded;
    private boolean configured;
    private boolean disposed;
    private float iconWidth;
    private float iconHeight;
    private float anchorX;
    private float anchorY;

    static boolean enabled(Map<?, ?> data) {
        Map<?, ?> appearance = (Map<?, ?>) data.get("appearance");
        Object icon = data.get("icon");
        if (appearance == null || !(icon instanceof List)
            || ((List<?>) icon).size() < 2 || !"fromBytes".equals(((List<?>) icon).get(0))) {
            return false;
        }
        return text(appearance.get("bannerTitle")).length() > 0
            || text(appearance.get("bannerSubtitle")).length() > 0;
    }

    MarkerBanner(HuaweiMap map, Marker marker, float density) {
        this.map = map;
        this.marker = marker;
        this.density = density;
    }

    void configure(Map<?, ?> data, int requestedDirection) {
        Map<?, ?> appearance = (Map<?, ?>) data.get("appearance");
        List<?> anchor = (List<?>) data.get("anchor");
        byte[] icon = (byte[]) ((List<?>) data.get("icon")).get(1);
        BitmapFactory.Options bounds = new BitmapFactory.Options();
        bounds.inJustDecodeBounds = true;
        BitmapFactory.decodeByteArray(icon, 0, icon.length, bounds);

        String newTitle = text(appearance.get("bannerTitle")).toUpperCase(Locale.ROOT);
        String newSubtitle = text(appearance.get("bannerSubtitle"));
        int newColor = appearance.get("bannerColor") instanceof Number
            ? ((Number) appearance.get("bannerColor")).intValue() : 0xFFFFC200;
        float newIconWidth = bounds.outWidth / density;
        float newIconHeight = bounds.outHeight / density;
        float newAnchorX = ((Number) anchor.get(0)).floatValue();
        float newAnchorY = ((Number) anchor.get(1)).floatValue();
        boolean artworkChanged = !newTitle.equals(title) || !newSubtitle.equals(subtitle)
            || newColor != color || newIconWidth != iconWidth || newIconHeight != iconHeight
            || newAnchorX != anchorX || newAnchorY != anchorY;

        title = newTitle;
        subtitle = newSubtitle;
        color = newColor;
        iconWidth = newIconWidth;
        iconHeight = newIconHeight;
        anchorX = newAnchorX;
        anchorY = newAnchorY;
        direction = requestedDirection;

        if (leftBanner == null || rightBanner == null) {
            createMarkers();
            artworkChanged = true;
        }
        if (artworkChanged) updateArtwork();
        syncMarkerProperties();
        updatePositions();

        boolean shouldExpand = Boolean.TRUE.equals(appearance.get("bannerExpanded"));
        if (!configured) {
            expanded = shouldExpand;
            banner(direction).setVisible(expanded && marker.isVisible());
            otherBanner(direction).setVisible(false);
            configured = true;
        } else if (shouldExpand != expanded) {
            expanded = shouldExpand;
            if (expanded) {
                animateScale(banner(direction), 0, 1, EXPAND_DURATION, false);
            } else {
                animateScale(banner(direction), 1, 0, COLLAPSE_DURATION, true);
            }
        } else {
            banner(direction).setVisible(expanded && marker.isVisible());
            otherBanner(direction).setVisible(false);
        }
    }

    void pan(int requestedDirection, boolean animated) {
        if (disposed || requestedDirection == direction) return;
        Marker outgoing = banner(direction);
        direction = requestedDirection;
        Marker incoming = banner(direction);

        if (expanded && marker.isVisible()) {
            if (animated) {
                animateDirection(outgoing, false);
                animateDirection(incoming, true);
            } else {
                outgoing.setVisible(false);
                incoming.setVisible(true);
            }
        }
        followMarkerAnimation(animated);
    }

    void updatePosition() {
        if (disposed) return;
        updatePositions();
    }

    void dispose() {
        if (disposed) return;
        disposed = true;
        if (positionAnimator != null) positionAnimator.cancel();
        if (leftBanner != null) leftBanner.remove();
        if (rightBanner != null) rightBanner.remove();
    }

    private void createMarkers() {
        LatLng position = marker.getPosition();
        leftBanner = map.addMarker(new MarkerOptions().position(position)
            .anchorMarker(.5f, .5f).clickable(false).clusterable(false).visible(false));
        rightBanner = map.addMarker(new MarkerOptions().position(position)
            .anchorMarker(.5f, .5f).clickable(false).clusterable(false).visible(false));
    }

    private void updateArtwork() {
        BannerBitmap left = drawBanner(false);
        BannerBitmap right = drawBanner(true);
        leftBanner.setIcon(BitmapDescriptorFactory.fromBitmap(left.bitmap));
        leftBanner.setMarkerAnchor(left.anchorX, left.anchorY);
        rightBanner.setIcon(BitmapDescriptorFactory.fromBitmap(right.bitmap));
        rightBanner.setMarkerAnchor(right.anchorX, right.anchorY);
    }

    private BannerBitmap drawBanner(boolean toRight) {
        float markerMargin = MARKER_MARGIN_PX / density;
        TextPaint titlePaint = textPaint(10, true);
        TextPaint subtitlePaint = textPaint(12, false);
        float titleWidth = title.isEmpty() ? 0 : titlePaint.measureText(title);
        float subtitleWidth = subtitle.isEmpty() ? 0 : subtitlePaint.measureText(subtitle);
        float availableTextWidth = MAX_BITMAP_WIDTH_PX / density
            - markerMargin - iconWidth - TEXT_GAP - HORIZONTAL_PADDING;
        float textWidth = Math.min(Math.max(0, availableTextWidth),
            Math.min(MAX_TEXT_WIDTH, Math.max(40, Math.max(titleWidth, subtitleWidth))))
            + (EXTRA_WIDTH_PX + (toRight ? RIGHT_EXTRA_WIDTH_PX : 0)) / density;
        float titleHeight = title.isEmpty() ? 0 : 14;
        float subtitleHeight = subtitle.isEmpty() ? 0 : 16;
        float textHeight = titleHeight + (titleHeight > 0 && subtitleHeight > 0 ? 2 : 0) + subtitleHeight;
        textHeight = Math.max(textHeight, 20);
        float capsuleHeight = Math.max(iconHeight + 4, 56) + EXTRA_HEIGHT_PX / density;
        float width = markerMargin + iconWidth + TEXT_GAP + textWidth + HORIZONTAL_PADDING;
        int bitmapWidth = Math.max(1, Math.round(width * density));
        int bitmapHeight = Math.max(1, Math.round(capsuleHeight * density));
        Bitmap bitmap = Bitmap.createBitmap(bitmapWidth, bitmapHeight, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        canvas.scale(density, density);

        Paint background = new Paint(Paint.ANTI_ALIAS_FLAG);
        background.setColor(color);
        canvas.drawRoundRect(new RectF(0, 0, width, capsuleHeight),
            capsuleHeight / 2, capsuleHeight / 2, background);

        float markerX = toRight ? markerMargin : HORIZONTAL_PADDING + textWidth + TEXT_GAP;
        float textX = toRight ? markerX + iconWidth + TEXT_GAP : HORIZONTAL_PADDING;
        float textTop = (capsuleHeight - textHeight) / 2;
        if (!title.isEmpty()) {
            String line = ellipsize(title, titlePaint, textWidth);
            canvas.drawText(line, textX, textTop - titlePaint.ascent(), titlePaint);
            textTop += titleHeight + (subtitle.isEmpty() ? 0 : 2);
        }
        if (!subtitle.isEmpty()) {
            String line = ellipsize(subtitle, subtitlePaint, textWidth);
            canvas.drawText(line, textX, textTop - subtitlePaint.ascent(), subtitlePaint);
        }

        return new BannerBitmap(bitmap,
            (markerX + anchorX * iconWidth) / width,
            ((capsuleHeight - iconHeight) / 2 + anchorY * iconHeight
                + VERTICAL_LIFT + 10 / density)
                / capsuleHeight);
    }

    private TextPaint textPaint(float size, boolean bold) {
        TextPaint paint = new TextPaint(Paint.ANTI_ALIAS_FLAG | Paint.SUBPIXEL_TEXT_FLAG);
        paint.setColor(Color.WHITE);
        paint.setTextSize(size);
        paint.setTypeface(Typeface.create(Typeface.DEFAULT, bold ? Typeface.BOLD : Typeface.NORMAL));
        return paint;
    }

    private String ellipsize(String value, TextPaint paint, float width) {
        return TextUtils.ellipsize(value, paint, width, TextUtils.TruncateAt.END).toString();
    }

    private void syncMarkerProperties() {
        float zIndex = marker.getZIndex() - .01f;
        leftBanner.setZIndex(zIndex);
        rightBanner.setZIndex(zIndex);
        leftBanner.setAlpha(marker.getAlpha());
        rightBanner.setAlpha(marker.getAlpha());
        if (!marker.isVisible()) {
            leftBanner.setVisible(false);
            rightBanner.setVisible(false);
        }
    }

    private void updatePositions() {
        LatLng position = marker.getPosition();
        leftBanner.setPosition(position);
        rightBanner.setPosition(position);
    }

    private void followMarkerAnimation(boolean animated) {
        if (positionAnimator != null) positionAnimator.cancel();
        if (!animated) {
            updatePositions();
            return;
        }
        positionAnimator = ValueAnimator.ofFloat(0, 1);
        positionAnimator.setDuration(DIRECTION_DURATION);
        positionAnimator.setInterpolator(new AccelerateDecelerateInterpolator());
        positionAnimator.addUpdateListener(value -> updatePositions());
        positionAnimator.start();
    }

    private void animateScale(Marker target, float fromX, float toX, long duration,
                              boolean hideAtEnd) {
        target.setVisible(marker.isVisible());
        ScaleAnimation animation = new ScaleAnimation(fromX, toX, 1, 1);
        animation.setDuration(duration);
        animation.setInterpolator(new AccelerateDecelerateInterpolator());
        animation.setFillMode(Animation.FILL_MODE_FORWARDS);
        if (hideAtEnd) {
            animation.setAnimationListener(new Animation.AnimationListener() {
                @Override public void onAnimationStart() { }
                @Override public void onAnimationEnd() {
                    if (!expanded || target != banner(direction)) {
                        target.setVisible(false);
                    }
                }
            });
        }
        target.setAnimation(animation);
        target.startAnimation();
    }

    private void animateDirection(Marker target, boolean showing) {
        target.setVisible(true);
        AlphaAnimation animation = new AlphaAnimation(showing ? 0 : 1, showing ? 1 : 0);
        animation.setDuration(DIRECTION_DURATION);
        animation.setInterpolator(new AccelerateDecelerateInterpolator());
        animation.setFillMode(Animation.FILL_MODE_FORWARDS);
        if (!showing) {
            animation.setAnimationListener(new Animation.AnimationListener() {
                @Override public void onAnimationStart() { }
                @Override public void onAnimationEnd() {
                    if (target != banner(direction)) target.setVisible(false);
                }
            });
        }
        target.setAnimation(animation);
        target.startAnimation();
    }

    private Marker banner(int value) {
        return value > 0 ? rightBanner : leftBanner;
    }

    private Marker otherBanner(int value) {
        return value > 0 ? leftBanner : rightBanner;
    }

    private static String text(Object value) {
        return value instanceof String ? ((String) value).trim() : "";
    }

    private static final class BannerBitmap {
        final Bitmap bitmap;
        final float anchorX;
        final float anchorY;

        BannerBitmap(Bitmap bitmap, float anchorX, float anchorY) {
            this.bitmap = bitmap;
            this.anchorX = anchorX;
            this.anchorY = anchorY;
        }
    }
}
