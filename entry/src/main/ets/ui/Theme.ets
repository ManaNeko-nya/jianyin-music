import { AppSettings, ThemeMode } from '../data/AppSettings';
import { window } from '@kit.ArkUI';
import { IS_ANDROID, getAndroidSystemDark, setAndroidSystemBars } from '../platform/BridgeClient';

/** 颜色以 #AARRGGBB 字符串表示，工具函数复刻 Compose 的颜色语义。 */
export class InkPalette {
  readonly dark: boolean;
  readonly canvas: string;
  readonly raised: string;
  readonly ink: string;
  readonly inkSoft: string;
  readonly inkMuted: string;
  readonly accent: string;
  readonly onAccent: string;
  readonly hairline: string;
  readonly fill: string;
  readonly fillStrong: string;
  readonly danger: string;

  constructor(dark: boolean, canvas: string, raised: string, ink: string, inkSoft: string,
    inkMuted: string, accent: string, onAccent: string, hairline: string, fill: string,
    fillStrong: string, danger: string) {
    this.dark = dark;
    this.canvas = canvas;
    this.raised = raised;
    this.ink = ink;
    this.inkSoft = inkSoft;
    this.inkMuted = inkMuted;
    this.accent = accent;
    this.onAccent = onAccent;
    this.hairline = hairline;
    this.fill = fill;
    this.fillStrong = fillStrong;
    this.danger = danger;
  }

  get isLight(): boolean {
    return !this.dark;
  }
}

export const DarkInk: InkPalette = new InkPalette(
  true,
  '#FF0C0D11', '#FF14161B', '#FFF3F2EE', '#FFC7CAD2', '#FF858B97',
  '#FFDDE6FA', '#FF17233A', '#1FFFFFFF', '#14FFFFFF', '#24FFFFFF', '#FFFFB4AB',
);

export const LightInk: InkPalette = new InkPalette(
  false,
  '#FFF5F4F0', '#FFEAE9E4', '#FF14161B', '#FF3E424B', '#FF727783',
  '#FF2F4E78', '#FFF7F9FF', '#1A000000', '#0F000000', '#1F000000', '#FFB3261E',
);

export function parseArgb(color: string): number[] {
  let hex = color;
  if (hex.startsWith('#')) {
    hex = hex.substring(1);
  }
  if (hex.length === 3) {
    hex = `${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}`;
  }
  if (hex.length === 6) {
    hex = `FF${hex}`;
  }
  const value = parseInt(hex, 16);
  return [(value >>> 24) & 0xFF, (value >>> 16) & 0xFF, (value >>> 8) & 0xFF, value & 0xFF];
}

function toHex2(v: number): string {
  const clamped = Math.min(Math.max(Math.round(v), 0), 255);
  const s = clamped.toString(16);
  return s.length === 1 ? `0${s}` : s;
}

/** 等价于 Color.copy(alpha = x)。 */
export function withAlpha(color: string, alpha: number): string {
  const c = parseArgb(color);
  const base = c[0] / 255.0;
  const finalAlpha = Math.min(Math.max(base * alpha, 0), 1);
  return `#${toHex2(finalAlpha * 255)}${toHex2(c[1])}${toHex2(c[2])}${toHex2(c[3])}`;
}

function srgbToLinear(c: number): number {
  const v = c / 255.0;
  return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
}

/** 等价于 Compose Color.luminance()。 */
export function luminance(color: string): number {
  const c = parseArgb(color);
  return 0.2126 * srgbToLinear(c[1]) + 0.7152 * srgbToLinear(c[2]) + 0.0722 * srgbToLinear(c[3]);
}

/** 等价于 Compose lerp(from, to, fraction)。 */
export function lerpColor(from: string, to: string, fraction: number): string {
  const f = Math.min(Math.max(fraction, 0), 1);
  const a = parseArgb(from);
  const b = parseArgb(to);
  return `#${toHex2(a[0] + (b[0] - a[0]) * f)}${toHex2(a[1] + (b[1] - a[1]) * f)}` +
    `${toHex2(a[2] + (b[2] - a[2]) * f)}${toHex2(a[3] + (b[3] - a[3]) * f)}`;
}

/** 等价于 playerBaseColorFor：把封面平均色压暗成播放器底色。 */
export function playerBaseColorFor(color: string): string {
  const lightness = Math.min(Math.max((luminance(color) - 0.35) / 0.45, 0), 1);
  return lerpColor(color, '#FF000000', 0.42 + 0.18 * lightness);
}

export const WHITE: string = '#FFFFFFFF';
export const BLACK: string = '#FF000000';
export const TRANSPARENT: string = '#00000000';

/** Material 3 Typography 到 ArkUI 的映射；数值与安卓端 Theme.kt 一一对应。 */
export class TypoStyle {
  readonly size: number;
  readonly weight: number;
  readonly lineHeight: number;
  readonly letterSpacing: number;

  constructor(size: number, weight: number, lineHeight: number, letterSpacing: number) {
    this.size = size;
    this.weight = weight;
    this.lineHeight = lineHeight;
    this.letterSpacing = letterSpacing;
  }
}

export class Typo {
  static readonly displayLarge = new TypoStyle(44, 900, 46, -1.4);
  static readonly displayMedium = new TypoStyle(36, 900, 39, -1);
  static readonly displaySmall = new TypoStyle(30, 900, 34, -0.8);
  static readonly headlineLarge = new TypoStyle(28, 700, 32, -0.6);
  static readonly headlineMedium = new TypoStyle(24, 700, 28, -0.4);
  static readonly headlineSmall = new TypoStyle(20, 700, 24, -0.2);
  static readonly titleLarge = new TypoStyle(19, 600, 24, -0.1);
  static readonly titleMedium = new TypoStyle(16, 600, 22, 0);
  static readonly titleSmall = new TypoStyle(14, 600, 20, 0);
  static readonly bodyLarge = new TypoStyle(16, 400, 24, 0);
  static readonly bodyMedium = new TypoStyle(14, 400, 21, 0);
  static readonly bodySmall = new TypoStyle(12, 400, 17, 0);
  static readonly labelLarge = new TypoStyle(13, 500, 18, 0.3);
  static readonly labelMedium = new TypoStyle(11, 500, 15, 0.8);
  static readonly labelSmall = new TypoStyle(10, 500, 13, 1.2);
}

/**
 * 主题控制器：决定深浅色并把状态栏外观与系统保持一致。
 * darkMode 由 EntryAbility 在配置变化时推动刷新。
 */
@ObservedV2
export class ThemeController {
  @Trace systemDark: boolean = false;
  @Trace themeMode: ThemeMode = ThemeMode.System;
  private window: window.Window | null = null;
  private lightBarsCount: number = 0;

  bindWindow(win: window.Window): void {
    this.window = win;
    this.themeMode = AppSettings.themeMode;
    this.applySystemBar();
  }

  get darkTheme(): boolean {
    const mode = this.themeMode;
    if (mode === ThemeMode.Light) {
      return false;
    }
    if (mode === ThemeMode.Dark) {
      return true;
    }
    return this.systemDark;
  }

  get ink(): InkPalette {
    return this.darkTheme ? DarkInk : LightInk;
  }

  onSystemDarkChanged(dark: boolean): void {
    this.systemDark = dark;
    this.applySystemBar();
  }

  /** AppSettings.themeMode 变化后调用，刷新主题与状态栏外观。 */
  refresh(): void {
    this.themeMode = AppSettings.themeMode;
    if (IS_ANDROID) {
      const systemDark = getAndroidSystemDark();
      if (systemDark !== null) {
        this.systemDark = systemDark;
      }
    }
    this.applySystemBar();
  }

  /** 大图页（专辑/歌单/艺人/播放器）强制白色状态栏内容。 */
  pushLightBars(): void {
    this.lightBarsCount++;
    this.applySystemBar();
  }

  popLightBars(): void {
    this.lightBarsCount = Math.max(0, this.lightBarsCount - 1);
    this.applySystemBar();
  }

  private applySystemBar(): void {
    if (this.window === null) {
      return;
    }
    const forceLight = this.lightBarsCount > 0;
    const dark = this.darkTheme;
    const lightContent = forceLight || dark;
    // ArkUI-X 在 Android 上的 window 系统栏实现不可靠，改走原生 bridge。
    if (IS_ANDROID) {
      setAndroidSystemBars(lightContent);
      return;
    }
    try {
      this.window.setWindowSystemBarProperties({
        statusBarContentColor: lightContent ? '#FFFFFFFF' : '#FF000000',
        navigationBarContentColor: lightContent ? '#FFFFFFFF' : '#FF000000',
      });
    } catch (err) {
    }
  }
}

export const Theme: ThemeController = new ThemeController();
