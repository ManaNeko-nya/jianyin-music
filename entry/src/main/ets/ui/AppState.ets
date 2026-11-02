import { promptAction } from '@kit.ArkUI';
import { L10n } from '../data/L10n';

/**
 * 单个二级页自己的标题栏状态。每个页面 new 一份，互不共享；
 * 页面销毁时状态随页面一起销毁，不会影响其他页面。
 * 'none' 无菜单；'actions' 图标菜单；'selectOnly' 只显示选择；'more' 只显示更多；
 * 'select' 文字菜单（全选 / 完成）。
 */
@ObservedV2
export class TopBarState {
  @Trace menuKind: string = 'none';
  @Trace sub: string = '';
  @Trace toggleLabel: string = '全选';
  @Trace onSelect: () => void = () => {
  };
  @Trace onMore: () => void = () => {
  };
  @Trace onToggle: () => void = () => {
  };
  @Trace onDone: () => void = () => {
  };
}

/** 搜索页自己的顶栏状态：同样每个页面实例一份，不与其他页共享。 */
@ObservedV2
export class SearchBarState {
  @Trace query: string = '';
  @Trace submitTick: number = 0;
}

/** 页面底部操作栏（多选栏等）占用的高度：悬浮迷你播放条要为其让位。 */
@ObservedV2
export class BottomBarState {
  @Trace height: number = 0;
}

export const BottomBar: BottomBarState = new BottomBarState();

export class AppUI {
  private static uiContext: UIContext | null = null;

  static bind(context: UIContext): void {
    AppUI.uiContext = context;
  }

  /** 等价于安卓端 Toast.LENGTH_SHORT。 */
  static toast(message: string): void {
    const ctx = AppUI.uiContext;
    if (ctx === null) {
      return;
    }
    try {
      ctx.getPromptAction().showToast({
        message: L10n.tr(message),
        duration: 2000,
        showMode: promptAction.ToastShowMode.TOP_MOST,
      });
    } catch (err) {
    }
  }

  static keyboardHide(): void {
    const ctx = AppUI.uiContext;
    if (ctx === null) {
      return;
    }
    try {
      ctx.getFocusController().clearFocus();
    } catch (err) {
    }
  }
}

/** 通知栏点击打开播放器的请求（等价于 MainActivity 的 EXTRA_OPEN_PLAYER）。 */
@ObservedV2
export class PlayerOpenRequest {
  @Trace pending: boolean = false;
}

export const PlayerOpen: PlayerOpenRequest = new PlayerOpenRequest();

/**
 * 返回键分发：弹窗、播放器浮层等先于导航栈消费系统返回。
 * 各 NavDestination 的 onBackPressed 与 @Entry.onBackPress 都先经过这里。
 */
export class BackDispatcher {
  private stack: Array<() => boolean> = [];

  push(handler: () => boolean): void {
    this.stack.push(handler);
  }

  pop(handler: () => boolean): void {
    const idx = this.stack.lastIndexOf(handler);
    if (idx >= 0) {
      this.stack.splice(idx, 1);
    }
  }

  handle(): boolean {
    if (this.stack.length === 0) {
      return false;
    }
    return this.stack[this.stack.length - 1]();
  }
}

export const Backs: BackDispatcher = new BackDispatcher();

/** 屏幕与导航栏尺寸（vp），由 EntryAbility 注入。 */
export class AppMetrics {
  static navBottom: number = 0;
  /** 迷你播放条本体高度（含与内容之间的一点余量）。 */
  static readonly miniBar: number = 78;
}
