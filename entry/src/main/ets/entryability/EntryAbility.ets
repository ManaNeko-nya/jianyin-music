import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { KeyboardAvoidMode, window } from '@kit.ArkUI';
import { display } from '@kit.ArkUI';
import { fileIo as fs } from '@kit.CoreFileKit';
import { i18n } from '@kit.LocalizationKit';
import { initBridge } from '../platform/BridgeClient';
import { Session } from '../data/Session';
import { AppSettings, LanguageMode } from '../data/AppSettings';
import { L10n } from '../data/L10n';
import { Player } from '../playback/PlayerEngine';
import { Theme } from '../ui/Theme';
import { AppUI, AppMetrics, PlayerOpen } from '../ui/AppState';
import { AppTopBar } from '../ui/Components';

const DOMAIN = 0x0000;
const TAG = 'JianYin';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'Ability onCreate');
    this.handleOpenPlayerWant(want);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.handleOpenPlayerWant(want);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
  }

  private handleOpenPlayerWant(want: Want): void {
    const params = want.parameters;
    if (params !== undefined && params !== null) {
      const open = params['open_player'];
      if (open === true || open === 'true' || open === 1 || open === '1') {
        PlayerOpen.pending = true;
      }
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageCreate');

    // 初始化持久化会话与设置（等价于安卓端 Application.onCreate）。
    Session.init(this.context.getApplicationContext());
    AppSettings.init(this.context.getApplicationContext());
    this.applyLanguage();
    L10n.init(this.context.resourceManager);

    const mainWindow = windowStage.getMainWindowSync();
    try {
      // 沉浸式全屏布局（等价于 enableEdgeToEdge）。
      mainWindow.setWindowLayoutFullScreen(true);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'setWindowLayoutFullScreen failed');
    }
    try {
      const dark = this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      Theme.onSystemDarkChanged(dark);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to read system color mode.');
    }
    Theme.bindWindow(mainWindow);
    this.computeMetrics(mainWindow);

    Player.bind(this.context);

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      // 页面加载完成后窗口才有 UIContext，提前调用会抛 "Uicontent is nullptr"。
      try {
        const uiContext = windowStage.getMainWindowSync().getUIContext();
        AppUI.bind(uiContext);
        // 页面级键盘避让；contentCover 是否跟随由 ArkUI-X 运行时决定。
        uiContext.setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
      } catch (err2) {
        hilog.error(DOMAIN, TAG, 'bind UIContext failed');
      }
      initBridge();
      setTimeout((): void => Theme.refresh(), 600);
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
    });

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode.');
    }
  }

  private applyLanguage(): void {
    let tag = '';
    if (AppSettings.languageMode === LanguageMode.Chinese) {
      tag = 'zh-Hans';
    } else if (AppSettings.languageMode === LanguageMode.English) {
      tag = 'en';
    } else {
      try {
        const system = i18n.System.getSystemLanguage();
        tag = system.toLowerCase().startsWith('zh') ? 'zh-Hans' : 'en';
      } catch (err) {
        tag = 'zh-Hans';
      }
    }
    try {
      i18n.System.setAppPreferredLanguage(tag);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'setAppPreferredLanguage failed');
    }
  }

  private computeMetrics(win: window.Window): void {
    const d = display.getDefaultDisplaySync();
    const density = d.densityPixels > 0 ? d.densityPixels : 3;
    AppTopBar.screenHeight = d.height / density;
    if (this.readInjectedInsets()) {
      return;
    }
    try {
      const systemArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      AppTopBar.topPad = Math.max(14, systemArea.topRect.height / density);
    } catch (err) {
      AppTopBar.topPad = 14;
    }
    try {
      const navArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      AppMetrics.navBottom = navArea.bottomRect.height / density;
    } catch (err) {
      AppMetrics.navBottom = 0;
    }
  }

  /** Android 壳层在 MainActivity 里写出的真实安全区（px）；鸿蒙没有该文件。 */
  private readInjectedInsets(): boolean {
    try {
      const path = this.context.getApplicationContext().filesDir + '/insets.txt';
      const text = fs.readTextSync(path);
      let top = -1;
      let bottom = -1;
      let density = 0;
      for (const line of text.split(';')) {
        const idx = line.indexOf('=');
        if (idx <= 0) {
          continue;
        }
        const key = line.substring(0, idx).trim();
        const value = parseFloat(line.substring(idx + 1).trim());
        if (isNaN(value)) {
          continue;
        }
        if (key === 'top') {
          top = value;
        } else if (key === 'bottom') {
          bottom = value;
        } else if (key === 'density' && value > 0) {
          density = value;
        }
      }
      if (top >= 0 && bottom >= 0 && density > 0) {
        AppTopBar.topPad = Math.max(14, top / density);
        AppMetrics.navBottom = bottom / density;
        return true;
      }
    } catch (err) {
    }
    return false;
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    const dark = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    Theme.onSystemDarkChanged(dark);
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
  }
}
