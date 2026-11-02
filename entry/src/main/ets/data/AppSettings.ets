import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export enum ThemeMode {
  System = 'System',
  Light = 'Light',
  Dark = 'Dark',
}

export enum LanguageMode {
  System = 'System',
  Chinese = 'Chinese',
  English = 'English',
}

export function languageModeLabel(mode: LanguageMode): string {
  switch (mode) {
    case LanguageMode.Chinese:
      return '中文';
    case LanguageMode.English:
      return 'English';
    default:
      return '跟随系统';
  }
}

export function languageModeDescription(mode: LanguageMode): string {
  switch (mode) {
    case LanguageMode.Chinese:
      return '始终使用中文';
    case LanguageMode.English:
      return '始终使用英文';
    default:
      return '随系统语言自动切换';
  }
}

export function themeModeLabel(mode: ThemeMode): string {
  switch (mode) {
    case ThemeMode.System:
      return '跟随系统';
    case ThemeMode.Light:
      return '浅色';
    case ThemeMode.Dark:
      return '深色';
  }
}

export function themeModeDescription(mode: ThemeMode): string {
  switch (mode) {
    case ThemeMode.System:
      return '随手机的深色模式自动切换';
    case ThemeMode.Light:
      return '始终使用亮色界面';
    case ThemeMode.Dark:
      return '始终使用暗色界面';
  }
}

/** 全局应用设置（等价于安卓端 AppSettings 单例 + StateFlow）。 */
/** 播放顺序：顺序播放到队列尾停止，列表循环回到队首，单曲循环重播当前，随机打乱。 */
export enum PlayMode {
  Order = 'Order',
  LoopList = 'LoopList',
  LoopOne = 'LoopOne',
  Shuffle = 'Shuffle',
}

export function playModeLabel(mode: PlayMode): string {
  switch (mode) {
    case PlayMode.Order:
      return '顺序播放';
    case PlayMode.LoopList:
      return '列表循环';
    case PlayMode.LoopOne:
      return '单曲循环';
    case PlayMode.Shuffle:
      return '随机播放';
  }
}

@ObservedV2
export class AppSettingsStore {
  private static readonly KEY_SPEED = 'playback_speed';
  private static readonly KEY_THEME = 'theme_mode';
  private static readonly KEY_PLAY_MODE = 'play_mode';
  private static readonly KEY_LANGUAGE = 'language_mode';

  private prefs: preferences.Preferences | null = null;

  @Trace speed: number = 1;
  @Trace themeMode: ThemeMode = ThemeMode.System;
  @Trace playMode: PlayMode = PlayMode.Order;
  @Trace languageMode: LanguageMode = LanguageMode.System;

  init(context: common.Context): void {
    this.prefs = preferences.getPreferencesSync(context, { name: 'app_settings' });
    this.speed = this.getFloat(AppSettingsStore.KEY_SPEED, 1);
    this.themeMode = this.parseTheme(this.getString(AppSettingsStore.KEY_THEME, 'System'));
    this.playMode = this.parsePlayMode(this.getString(AppSettingsStore.KEY_PLAY_MODE, 'Order'));
    this.languageMode = this.parseLanguage(this.getString(AppSettingsStore.KEY_LANGUAGE, 'System'));
  }

  private parseLanguage(raw: string): LanguageMode {
    switch (raw) {
      case 'Chinese':
        return LanguageMode.Chinese;
      case 'English':
        return LanguageMode.English;
      default:
        return LanguageMode.System;
    }
  }

  private parsePlayMode(raw: string): PlayMode {
    switch (raw) {
      case 'LoopList':
        return PlayMode.LoopList;
      case 'LoopOne':
        return PlayMode.LoopOne;
      case 'Shuffle':
        return PlayMode.Shuffle;
      default:
        return PlayMode.Order;
    }
  }

  private parseTheme(raw: string): ThemeMode {
    switch (raw) {
      case 'Light':
        return ThemeMode.Light;
      case 'Dark':
        return ThemeMode.Dark;
      default:
        return ThemeMode.System;
    }
  }

  private getString(key: string, def: string): string {
    if (this.prefs === null) {
      return def;
    }
    try {
      const v = this.prefs.getSync(key, def);
      return typeof v === 'string' ? v : def;
    } catch (err) {
      return def;
    }
  }

  private getFloat(key: string, def: number): number {
    if (this.prefs === null) {
      return def;
    }
    try {
      const v = this.prefs.getSync(key, def);
      return typeof v === 'number' ? v : def;
    } catch (err) {
      return def;
    }
  }

  private putString(key: string, value: string): void {
    if (this.prefs === null) {
      return;
    }
    try {
      this.prefs.putSync(key, value);
      this.prefs.flush();
    } catch (err) {
    }
  }

  private putFloat(key: string, value: number): void {
    if (this.prefs === null) {
      return;
    }
    try {
      this.prefs.putSync(key, value);
      this.prefs.flush();
    } catch (err) {
    }
  }

  setSpeed(value: number): void {
    const safe = Math.min(Math.max(value, 0.5), 2.5);
    this.speed = safe;
    this.putFloat(AppSettingsStore.KEY_SPEED, safe);
  }

  setThemeMode(mode: ThemeMode): void {
    this.themeMode = mode;
    this.putString(AppSettingsStore.KEY_THEME, mode);
  }

  setPlayMode(mode: PlayMode): void {
    this.playMode = mode;
    this.putString(AppSettingsStore.KEY_PLAY_MODE, mode);
  }

  setLanguageMode(mode: LanguageMode): void {
    this.languageMode = mode;
    this.putString(AppSettingsStore.KEY_LANGUAGE, mode);
  }
}

export const AppSettings: AppSettingsStore = new AppSettingsStore();
