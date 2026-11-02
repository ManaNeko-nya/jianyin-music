import { Typo, Theme, withAlpha } from './Theme';
import { InkText, RoundIconButton, AppTopBar } from './Components';
import { Backs, AppMetrics } from './AppState';

/** 让父页面主动关闭弹窗，并在系统下滑动画结束后再执行后续动作。 */
export class SheetController {
  private handler: (done: () => void) => void = (done: () => void): void => done();

  bind(handler: (done: () => void) => void): void {
    this.handler = handler;
  }

  close(done: () => void): void {
    this.handler(done);
  }
}

/**
 * 全应用唯一的底部弹窗基础组件。
 * 默认用 bindContentCover 承载自绘遮罩、拖拽与关闭动画；
 * 需要系统下滑关闭/键盘避让的弹窗（评论、播放器更多）用 bindSheet。
 * 面板本身由 panel() 统一绘制，两种宿主视觉一致。
 */
@ComponentV2
export struct AppModalSheet {
  @Event onDismissRequest: () => void = () => {
  };
  @Param title: string = '';
  @Param hint: string = '';
  @Param heightFraction: number = 0;
  @Param containerColor: string = '';
  @Param contentColor: string = '';
  @Param mutedColor: string = '';
  @Param closeTint: string = '';
  @Param dismissEnabled: boolean = true;
  @Param sheetHost: boolean = false;
  @Param controller: SheetController | undefined = undefined;
  @BuilderParam content: () => void = emptySheetBuilder;

  @Local visible: boolean = false;
  @Local shown: boolean = false;
  @Local dragOffset: number = 0;
  private sheetHeight: number = 0;
  private closing: boolean = false;
  private closeDone: (() => void) | undefined = undefined;
  private backHandler: () => boolean = (): boolean => false;

  private container(): string {
    return this.containerColor.length > 0 ? this.containerColor : Theme.ink.raised;
  }

  private contentClr(): string {
    return this.contentColor.length > 0 ? this.contentColor : Theme.ink.ink;
  }

  private mutedClr(): string {
    return this.mutedColor.length > 0 ? this.mutedColor : Theme.ink.inkMuted;
  }

  private closeClr(): string {
    return this.closeTint.length > 0 ? this.closeTint : this.mutedClr();
  }

  aboutToAppear(): void {
    this.backHandler = (): boolean => {
      if (!this.dismissEnabled || this.closing) {
        return false;
      }
      this.close();
      return true;
    };
    Backs.push(this.backHandler);
    if (this.controller !== undefined) {
      this.controller.bind((done: () => void): void => this.closeWith(done));
    }
  }

  aboutToDisappear(): void {
    this.visible = false;
    Backs.pop(this.backHandler);
  }

  /** 关闭：先把面板滑回屏幕外，动画结束再销毁模态层（模态层拆树时子节点 transition 不会反向播放）。 */
  private close(): void {
    this.closeWith((): void => {
    });
  }

  private closeWith(done: () => void): void {
    if (!this.dismissEnabled || this.closing) {
      return;
    }
    this.closing = true;
    this.closeDone = done;
    if (this.sheetHost) {
      this.visible = false;
      return;
    }
    this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseIn }, () => {
      this.shown = false;
    });
    setTimeout((): void => {
      this.visible = false;
    }, 230);
  }

  private finishDismiss(): void {
    this.onDismissRequest();
    const done = this.closeDone;
    this.closeDone = undefined;
    if (done !== undefined) {
      setTimeout(done, 0);
    }
  }

  private settleDrag(): void {
    if (this.sheetHeight <= 0) {
      this.close();
      return;
    }
    const shouldClose = this.dragOffset > this.sheetHeight * 0.18;
    if (shouldClose) {
      this.close();
      return;
    }
    this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
      this.dragOffset = 0;
    });
  }

  build() {
    if (this.sheetHost) {
      Column()
        .width(1)
        .height(1)
        .opacity(0)
        .onAppear((): void => {
          this.visible = true;
        })
        .bindSheet(this.visible, this.sheetPanel(), {
          height: this.heightFraction > 0
            ? AppTopBar.screenHeight * this.heightFraction : SheetSize.FIT_CONTENT,
          dragBar: false,
          showClose: false,
          preferType: SheetType.BOTTOM,
          mode: SheetMode.OVERLAY,
          maskColor: withAlpha('#FF000000', 0.58),
          backgroundColor: this.container(),
          radius: { topLeft: 24, topRight: 24 },
          blurStyle: BlurStyle.NONE,
          keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_RESIZE,
          shouldDismiss: (dismiss: SheetDismiss): void => {
            if (this.dismissEnabled && !this.closing) {
              this.closing = true;
              dismiss.dismiss();
            }
          },
          onDisappear: (): void => {
            this.finishDismiss();
          },
        })
    } else {
      // 宿主节点：模态层挂在系统 contentCover 上，层级高于整窗所有内容。
      // builder 只能直传 @Builder 调用，用箭头函数包一层会让模态层静默不渲染。
      Column()
        .width(1)
        .height(1)
        .opacity(0)
        .onAppear((): void => {
          this.visible = true;
        })
        .bindContentCover(this.visible, this.sheetUi(), {
          modalTransition: ModalTransition.NONE,
          onDisappear: (): void => {
            this.finishDismiss();
          },
          onWillDismiss: (_action: DismissContentCoverAction): void => {
            this.close();
          },
        })
    }
  }

  @Builder
  private sheetPanel() {
    this.panel(false)
  }

  @Builder
  private sheetUi() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(withAlpha('#FF000000', 0.58))
        .opacity(this.shown ? 1 : 0)
        .onClick(() => this.close())

      this.panel(true)
    }
    .width('100%')
    .height('100%')
    .onAppear((): void => {
      this.getUIContext().animateTo({ duration: 250, curve: Curve.EaseOut }, () => {
        this.shown = true;
      });
    })
  }

  @Builder
  private panel(draggable: boolean) {
    Column({ space: 0 }) {
      Column({ space: 0 }) {
        Column()
          .width(34)
          .height(3)
          .borderRadius(1.5)
          .backgroundColor(withAlpha(this.contentClr(), 0.22))
          .margin({ top: 10 })
        if (draggable) {
          Row() {
            this.titleRow()
          }
          .width('100%')
          .padding({ left: 24, right: 10, top: 12, bottom: 4 })
          .alignItems(VerticalAlign.Center)
          .gesture(PanGesture({ fingers: 1, direction: PanDirection.Vertical, distance: 5 })
            .onActionStart((_e: GestureEvent): void => {
            })
            .onActionUpdate((e: GestureEvent): void => {
              const next = Math.min(Math.max(e.offsetY, 0), this.sheetHeight);
              this.dragOffset = next;
            })
            .onActionEnd(() => this.settleDrag()))
        } else {
          Row() {
            this.titleRow()
          }
          .width('100%')
          .padding({ left: 24, right: 10, top: 12, bottom: 4 })
          .alignItems(VerticalAlign.Center)
        }
      }
      .hitTestBehavior(HitTestMode.Default)

      Column({ space: 0 }) {
        this.content()
      }
      .width('100%')
      .layoutWeight(this.heightFraction > 0 ? 1 : 0)
    }
    .width('100%')
    .height(this.heightFraction > 0 ? (draggable ? `${this.heightFraction * 100}%` : '100%') : undefined)
    .borderRadius({ topLeft: 24, topRight: 24 })
    .backgroundColor(this.container())
    .padding({ bottom: AppMetrics.navBottom })
    .onAreaChange((_o: Area, n: Area) => {
      const h = n.height;
      this.sheetHeight = typeof h === 'number' ? h as number : 0;
    })
    .translate({ y: draggable ? (this.shown ? this.dragOffset : AppTopBar.screenHeight) : 0 })
    .hitTestBehavior(HitTestMode.Default)
  }

  @Builder
  private titleRow() {
    Column({ space: 0 }) {
      if (this.title.length > 0) {
        InkText({ text: this.title, style: Typo.headlineSmall, color: this.contentClr() })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)

    if (this.hint.length > 0) {
      InkText({ text: this.hint, style: Typo.labelMedium, color: this.mutedClr() })
      Row().width(4).height(1)
    }
    RoundIconButton({
      icon: 'close',
      desc: '关闭',
      onTap: () => this.close(),
      tint: this.closeClr(),
      boxSize: 38,
      iconSize: 20,
    })
  }
}

@Builder
function emptySheetBuilder(): void {
}
