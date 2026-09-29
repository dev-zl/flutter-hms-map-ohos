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

import com.huawei.hms.maps.model.BitmapDescriptor;
import com.huawei.hms.maps.model.LatLng;
import com.huawei.hms.maps.model.Marker;
import com.huawei.hms.maps.model.animation.AnimationSet;

class MarkerController implements MarkerMethods {

    private final Marker marker;
    private LatLng logicalPosition;
    private MarkerAppearance appearance;
    private MarkerBanner banner;
    private boolean panEnabled;
    private final com.huawei.hms.maps.HuaweiMap map;
    private final float density;

    void configureAppearance(java.util.Map<?, ?> data, float groundOffset, int direction) {
        java.util.Map<?, ?> options = (java.util.Map<?, ?>) data.get("appearance");
        panEnabled = options != null &&
            (Boolean.TRUE.equals(options.get("showAnchorDot"))
                || Boolean.TRUE.equals(options.get("swayOnPan"))
                || Boolean.TRUE.equals(options.get("bannerExpanded")));
        if (MarkerAppearance.enabled(data)) {
            if (appearance == null) {
                appearance = new MarkerAppearance(map, marker, density, logicalPosition, data);
            }
            appearance.configure(data, logicalPosition, groundOffset, direction);
        } else if (appearance != null) {
            appearance.dispose();
            appearance = null;
            marker.setPosition(logicalPosition);
        }
        if (MarkerBanner.enabled(data)) {
            if (banner == null) banner = new MarkerBanner(map, marker, density);
            banner.configure(data, direction);
        } else if (banner != null) {
            banner.dispose();
            banner = null;
        }
    }

    void pan(int direction, boolean animated) {
        if (appearance != null) appearance.pan(direction, animated);
        if (banner != null) banner.pan(direction, animated);
    }

    void groundOffset(float value) {
        if (appearance != null) appearance.setGroundOffset(value);
    }

    void updateAppearancePosition() {
        if (appearance != null) appearance.updatePositions();
        if (banner != null) banner.updatePosition();
    }

    LatLng position() { return logicalPosition; }

    boolean needsPanUpdate() {
        // showAnchorDot 控制当前业务标记；其他旧标记的摇摆和展开横幅仍可沿用原配置。
        return panEnabled && marker.isVisible() && marker.getAlpha() > 0;
    }

    void disposeAppearance() {
        if (appearance != null) {
            appearance.dispose();
            appearance = null;
        }
        if (banner != null) {
            banner.dispose();
            banner = null;
        }
    }

    private final String mapMarkerId;

    private final boolean clusterable;

    MarkerController(final Marker marker, final boolean clusterable,
                     com.huawei.hms.maps.HuaweiMap map, float density) {
        this.marker = marker;
        this.map = map;
        this.density = density;
        logicalPosition = marker.getPosition();
        mapMarkerId = marker.getId();
        this.clusterable = clusterable;
    }

    @Override
    public void delete() {
        disposeAppearance();
        marker.remove();
    }

    @Override
    public void setAlpha(final float alpha) {
        marker.setAlpha(alpha);
    }

    @Override
    public void setClusterable(final boolean isClusterable) {
    }

    @Override
    public void setAnchor(final float u, final float v) {
        marker.setMarkerAnchor(u, v);
    }

    @Override
    public void setClickable(final boolean clickable) {
        marker.setClickable(clickable);
    }

    @Override
    public void setDraggable(final boolean draggable) {
        marker.setDraggable(draggable);
    }

    @Override
    public void setFlat(final boolean flat) {
        marker.setFlat(flat);
    }

    @Override
    public void setIcon(final BitmapDescriptor bitmapDescriptor) {
        marker.setIcon(bitmapDescriptor);
    }

    @Override
    public void setInfoWindowAnchor(final float u, final float v) {
        marker.setInfoWindowAnchor(u, v);
    }

    @Override
    public void setInfoWindowText(final String title, final String snippet) {
        marker.setTitle(title);
        marker.setSnippet(snippet);
    }

    @Override
    public void setPosition(final LatLng position) {
        logicalPosition = position;
        marker.setPosition(position);
    }

    @Override
    public void setRotation(final float rotation) {
        marker.setRotation(rotation);
    }

    @Override
    public void setVisible(final boolean visible) {
        marker.setVisible(visible);
    }

    @Override
    public void setZIndex(final float zIndex) {
        marker.setZIndex(zIndex);
    }

    @Override
    public void setAnimationSet(final AnimationSet animationSet) {
        marker.setAnimation(animationSet);
    }

    @Override
    public void startAnimation() {
        marker.startAnimation();
    }

    String getMapMarkerId() {
        return mapMarkerId;
    }

    boolean isClickable() {
        return marker.isClickable();
    }

    boolean isClusterable() {
        return clusterable;
    }

    void showInfoWindow() {
        marker.showInfoWindow();
    }

    void hideInfoWindow() {
        marker.hideInfoWindow();
    }

    boolean isInfoWindowShown() {
        return marker.isInfoWindowShown();
    }
}
