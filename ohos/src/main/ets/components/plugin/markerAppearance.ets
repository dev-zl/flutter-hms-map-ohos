import { map } from '@kit.MapKit';
import { LengthMetricsUnit } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Convert } from './utils/Convert';

interface ContentBounds {
  left: number;
  top: number;
  right: number;
  bottom: number;
}

/** Native texture compositor. Marker, dot and capsule use one 450ms timeline. */
export class MarkerAppearance {
  private marker: map.Marker;
  private options: Record<string, Object> = {};
  private icon: image.PixelMap | null = null;
  private bytes: Uint8Array | null = null;
  private width: number = 0;
  private height: number = 0;
  private contentBounds: ContentBounds = { left: 0, top: 0, right: 0, bottom: 0 };
  private anchorX: number = 0.5;
  private anchorY: number = 1;
  private groundOffset: number = 0;
  private direction: number = -1;
  private targetDirection: number = -1;
  private expansion: number = 0;
  private scale: number = 1;
  private visible: boolean = false;
  private initialized: boolean = false;
  private disposed: boolean = false;
  private timer: number = -1;
  private revision: number = 0;
  private rendering: boolean = false;
  private dirty: boolean = false;
  private lastFrame: image.PixelMap | null = null;
  private density: number = vp2px(1);

  constructor(marker: map.Marker) { this.marker = marker; }

  static enabled(data: Record<string, Object>): boolean {
    const options = data['appearance'] as Record<string, Object> | undefined;
    return options !== undefined && Convert.isFromBytesIcon(data['icon'])
      && (options['swayOnPan'] === true || options['popOnAppear'] === true
        || options['showAnchorDot'] === true || typeof options['bannerTitle'] === 'string'
        || typeof options['bannerSubtitle'] === 'string');
  }

  async configure(data: Record<string, Object>, groundOffset: number, direction: number): Promise<void> {
    const revision = ++this.revision;
    this.options = data['appearance'] as Record<string, Object>;
    this.groundOffset = groundOffset;
    this.targetDirection = direction;
    const anchor = data['anchor'] as Array<number>;
    this.anchorX = anchor[0]; this.anchorY = anchor[1];
    const raw = (data['icon'] as Array<Object>)[1];
    const bytes = raw instanceof Uint8Array ? raw : new Uint8Array(raw as ArrayBuffer);
    if (!this.sameBytes(bytes)) {
      const icon = await Convert.fromBytesToPixelMap(data['icon']);
      if (!icon) return;
      const info = await icon.getImageInfo();
      const contentBounds = await this.readContentBounds(icon, info);
      if (this.disposed || revision !== this.revision) { await icon.release(); return; }
      const old = this.icon;
      this.icon = icon; this.bytes = bytes;
      this.width = info.size.width / this.density; this.height = info.size.height / this.density;
      this.contentBounds = contentBounds;
      if (old) await old.release();
    }
    if (this.disposed || revision !== this.revision) return;
    const wasVisible = this.visible;
    this.visible = data['visible'] !== false;
    const first = !this.initialized;
    this.initialized = true;
    const targetExpansion = this.expansionTarget();
    if (first) { this.direction = this.targetDirection; this.expansion = targetExpansion; }
    const pop = this.visible && !wasVisible && this.flag('popOnAppear');
    if (pop) this.scale = 0.16;
    this.animate(this.targetDirection, targetExpansion, this.visible && (!first || pop), pop);
  }

  setGroundOffset(value: number): void { this.groundOffset = value; this.requestRender(); }
  pan(direction: number, animated: boolean = true): void {
    if (direction === this.targetDirection) return;
    this.targetDirection = direction;
    this.animate(direction, this.expansionTarget(), this.visible && animated, false);
  }
  dispose(): void {
    this.disposed = true; this.revision++;
    if (this.timer >= 0) clearInterval(this.timer);
    this.timer = -1;
    this.icon?.release().catch(() => {}); this.icon = null;
    this.lastFrame?.release().catch(() => {}); this.lastFrame = null;
    this.bytes = null;
  }
  private sameBytes(bytes: Uint8Array): boolean {
    if (!this.bytes || this.bytes.length !== bytes.length) return false;
    for (let i = 0; i < bytes.length; i++) { if (this.bytes[i] !== bytes[i]) return false; }
    return true;
  }
  private async readContentBounds(pixelMap: image.PixelMap, info: image.ImageInfo): Promise<ContentBounds> {
    const width = info.size.width, height = info.size.height;
    if (info.pixelFormat !== image.PixelMapFormat.RGBA_8888 &&
      info.pixelFormat !== image.PixelMapFormat.BGRA_8888 &&
      info.pixelFormat !== image.PixelMapFormat.ARGB_8888) {
      return { left: 0, top: 0, right: width, bottom: height };
    }
    const buffer = new ArrayBuffer(pixelMap.getPixelBytesNumber());
    await pixelMap.readPixelsToBuffer(buffer);
    const pixels = new Uint8Array(buffer);
    const stride = pixelMap.getBytesNumberPerRow();
    const alphaOffset = info.pixelFormat === image.PixelMapFormat.ARGB_8888 ? 0 : 3;
    let left = width, top = height, right = -1, bottom = -1;
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        if (pixels[y * stride + x * 4 + alphaOffset] <= 8) continue;
        left = Math.min(left, x); top = Math.min(top, y);
        right = Math.max(right, x); bottom = Math.max(bottom, y);
      }
    }
    return right >= left && bottom >= top
      ? { left: left, top: top, right: right + 1, bottom: bottom + 1 }
      : { left: 0, top: 0, right: width, bottom: height };
  }
  private flag(key: string): boolean { return this.options[key] === true; }
  private number(key: string, fallback: number): number { return typeof this.options[key] === 'number' ? this.options[key] as number : fallback; }
  private string(key: string): string { return typeof this.options[key] === 'string' ? this.options[key] as string : ''; }
  private hasText(): boolean { return this.string('bannerTitle').length > 0 || this.string('bannerSubtitle').length > 0; }
  private expansionTarget(): number { return this.flag('bannerExpanded') && this.hasText() ? 1 : 0; }
  private color(key: string, fallback: number): string {
    const color = this.number(key, fallback);
    return `rgba(${(color >>> 16) & 255},${(color >>> 8) & 255},${color & 255},${((color >>> 24) & 255) / 255})`;
  }
  private animate(toDirection: number, toExpansion: number, animated: boolean, pop: boolean): void {
    if (this.timer >= 0) clearInterval(this.timer);
    this.timer = -1;
    if (!animated || (this.direction === toDirection && this.expansion === toExpansion && this.scale === 1)) {
      this.direction = toDirection; this.expansion = toExpansion; this.scale = 1; this.requestRender(); return;
    }
    const fromDirection = this.direction, fromExpansion = this.expansion, fromScale = this.scale;
    const start = Date.now(), duration = pop ? this.number('popDurationMs', 280) : 450;
    this.timer = setInterval(() => {
      const progress = Math.min(1, (Date.now() - start) / Math.max(1, duration));
      const t = 0.5 - 0.5 * Math.cos(Math.PI * progress);
      this.direction = fromDirection + (toDirection - fromDirection) * t;
      this.expansion = fromExpansion + (toExpansion - fromExpansion) * t;
      this.scale = fromScale + (1 - fromScale) * t;
      this.requestRender();
      if (progress === 1) { clearInterval(this.timer); this.timer = -1; }
    }, 32);
  }
  private requestRender(): void {
    if (!this.visible || this.disposed || !this.icon) return;
    if (this.rendering) { this.dirty = true; return; }
    this.rendering = true;
    this.render().catch((error: Error) => {
      if (!this.disposed) hilog.warn(0, '[MarkerAppearance]', `render failed: ${error.message}`);
    }).finally(() => {
      this.rendering = false;
      if (this.dirty) { this.dirty = false; this.requestRender(); }
    });
  }
  private fit(context: OffscreenCanvasRenderingContext2D, value: string, width: number): string {
    if (context.measureText(value).width <= width) return value;
    let result = value;
    while (result.length > 0 && context.measureText(result + '…').width > width) result = result.slice(0, -1);
    return result + '…';
  }
  private capsule(context: OffscreenCanvasRenderingContext2D, x: number, y: number, w: number, h: number): void {
    const r = Math.min(w, h) / 2;
    context.beginPath(); context.moveTo(x + r, y);
    context.arcTo(x + w, y, x + w, y + h, r);
    context.arcTo(x + w, y + h, x, y + h, r);
    context.arcTo(x, y + h, x, y, r);
    context.arcTo(x, y, x + w, y, r); context.closePath(); context.fill();
  }
  private async render(): Promise<void> {
    if (!this.icon) return;
    const w = this.width, h = this.height;
    const dot = this.flag('showAnchorDot') && typeof this.options['anchorDotColor'] === 'number';
    const dotSize = this.number('anchorDotSize', 8);
    const offset = this.options['anchorDotOffset'] as Array<number>;
    const ox = dot ? offset[0] : 0, oy = dot ? offset[1] : 0;
    const sway = this.flag('swayOnPan');
    const shiftAmplitude = sway
      ? (dot ? w * 0.46 : Math.max(8, this.number('maxSwayDegrees', 24) * 0.55)) : 0;
    const shift = this.direction * shiftAmplitude;
    const title = this.string('bannerTitle').toUpperCase(), subtitle = this.string('bannerSubtitle');
    const measure = new OffscreenCanvasRenderingContext2D(1, 1, new RenderingContextSettings(true), LengthMetricsUnit.PX);
    measure.font = 'bold 11px sans-serif'; const titleW = measure.measureText(title).width;
    measure.font = '13px sans-serif';
    const textW = Math.min(150, Math.max(40, titleW, measure.measureText(subtitle).width));
    const extension = this.hasText() ? 6 + textW + 12 : 0, grow = extension * this.expansion;
    const capsuleH = Math.max(h + 4, 56);
    const contentLeft = this.contentBounds.left / this.density;
    const contentTop = this.contentBounds.top / this.density;
    const contentWidth = (this.contentBounds.right - this.contentBounds.left) / this.density;
    const contentHeight = (this.contentBounds.bottom - this.contentBounds.top) / this.density;
    const markerRadius = Math.min(contentWidth, contentHeight) / 2;
    const centerOffsetX = contentLeft + contentWidth / 2 - this.anchorX * w;
    // The social marker's visible circle sits at the bottom of its bitmap.
    const centerOffsetY = contentTop + contentHeight - markerRadius - this.anchorY * h;
    // Match iOS's fixed-height horizontal switch. Lift both composed elements
    // by half a middle-dot diameter to leave a clear gap above the mass point.
    const markerTravel = shiftAmplitude;
    const leftTravelExtra = dot && sway ? dotSize * 0.55 : 0;
    const verticalLift = dotSize / 2;
    const centerX = dot ? this.direction * markerTravel + Math.min(0, this.direction) * leftTravelExtra - ox
      : shift + centerOffsetX;
    const centerY = dot ? -markerRadius - oy - verticalLift : centerOffsetY;
    const markerX = centerX - centerOffsetX;
    const markerY = centerY - centerOffsetY;
    const left = markerX - w * this.anchorX;
    const top = markerY - h * this.anchorY;

    const dotY = -dotSize / 3 - verticalLift + 3 / this.density;
    const lineFraction = (this.groundOffset - dotY) / (this.groundOffset - centerY);
    const dotX = centerX * lineFraction;
    const bannerLeft = left - 4 - (1 - this.direction) / 2 * grow, bannerTop = top + (h - capsuleH) / 2;
    // Keep texture dimensions and anchor stable throughout each transition.
    const expanded = this.expansion > 0 || this.expansionTarget() > 0;
    const extra = expanded ? extension + 4 : 0;
    const endpointCenterLeft = dot ? -markerTravel - leftTravelExtra - ox : -shiftAmplitude + centerOffsetX;
    const endpointCenterRight = dot ? markerTravel - ox : shiftAmplitude + centerOffsetX;
    const endpointMarkerLeft = endpointCenterLeft - centerOffsetX - w * this.anchorX;
    const endpointMarkerRight = endpointCenterRight - centerOffsetX - w * this.anchorX;
    const endpointDotLeft = endpointCenterLeft * lineFraction;
    const endpointDotRight = endpointCenterRight * lineFraction;
    const margin = 2 + (dot ? dotSize / 2 : 0);
    const minX = Math.min(0, endpointMarkerLeft - extra, dot ? endpointDotLeft - dotSize / 2 : 0) - margin;
    const maxX = Math.max(0, endpointMarkerRight + w + extra, dot ? endpointDotRight + dotSize / 2 : 0) + margin;
    const minY = Math.min(0, top, expanded ? bannerTop : top, dot ? dotY - dotSize / 2 : 0) - 2;
    const maxY = Math.max(0, top + h, expanded ? bannerTop + capsuleH : top + h, dot ? dotY + dotSize / 2 : 0) + 2;
    const pixelW = Math.ceil((maxX - minX) * this.density), pixelH = Math.ceil((maxY - minY) * this.density);
    const context = new OffscreenCanvasRenderingContext2D(pixelW, pixelH, new RenderingContextSettings(true), LengthMetricsUnit.PX);
    context.scale(this.density, this.density); context.translate(-minX, -minY);
    if (dot) {
      context.fillStyle = this.color('anchorDotColor', 0);
      context.beginPath(); context.arc(dotX, dotY, dotSize / 2, 0, Math.PI * 2); context.fill();
    }
    context.save(); context.scale(this.scale, this.scale);
    if (grow > 0 && this.hasText()) {
      context.fillStyle = this.color('bannerColor', 0xFFFFC200);
      this.capsule(context, bannerLeft, bannerTop, w + 8 + grow, capsuleH);
      const textX = left + (1 + this.direction) / 2 * (w + 6) - (1 - this.direction) / 2 * (textW + 6);
      const textH = (title.length > 0 ? 14 : 0) + (subtitle.length > 0 ? 16 : 0) + (title.length > 0 && subtitle.length > 0 ? 2 : 0);
      let textY = bannerTop + (capsuleH - textH) / 2;
      context.save(); context.beginPath(); context.rect(bannerLeft, bannerTop, w + 8 + grow, capsuleH); context.clip();
      context.fillStyle = '#FFFFFF'; context.globalAlpha = this.expansion;
      if (title.length > 0) { context.font = 'bold 11px sans-serif'; context.fillText(this.fit(context, title, textW), textX, textY + 11); textY += 16; }
      if (subtitle.length > 0) { context.font = '13px sans-serif'; context.fillText(this.fit(context, subtitle, textW), textX, textY + 13); }
      context.restore();
    }
    context.drawImage(this.icon, left, top, w, h); context.restore();
    const frame = context.getPixelMap(0, 0, pixelW, pixelH);
    try {
      await this.marker.setIcon(frame);
      if (this.disposed) { await frame.release(); return; }
      const anchorBiasX = dot ? markerRadius * 0.4 : 0;
      this.marker.setMarkerAnchor((-minX + anchorBiasX) * this.density / pixelW,
        -minY * this.density / pixelH);
      const old = this.lastFrame; this.lastFrame = frame;
      if (old) await old.release();
    } catch (error) { await frame.release(); throw new Error(String(error)); }
  }
}
