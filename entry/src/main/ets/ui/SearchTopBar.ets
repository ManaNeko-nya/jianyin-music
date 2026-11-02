import { Theme, withAlpha } from './Theme';
import { AppTopBar } from './Components';
import { BarIconButton, BarSurface } from './BarChrome';
import { AppNav } from './AppNav';
import { AppUI, Backs, SearchBarState } from './AppState';
import { L10n } from '../data/L10n';

/** 搜索页独立顶栏：返回 + 占满剩余宽度的搜索框，不显示标题。 */
@ComponentV2
export struct SearchTopBar {
  @Param bar: SearchBarState = new SearchBarState();

  private goBack(): void {
    if (Backs.handle()) {
      return;
    }
    if (AppNav.canPop) {
      AppNav.pop();
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      BarSurface()

      Column({ space: 0 }) {
        Row({ space: 0 }) {
          BarIconButton({ name: 'back', onTap: (): void => this.goBack() })
          Search({ value: this.bar.query, placeholder: L10n.tr('搜索歌曲、专辑') })
            .layoutWeight(1)
            .height(40)
            .backgroundColor(Theme.ink.raised)
            .placeholderColor(withAlpha(Theme.ink.inkMuted, 0.8))
            .fontColor(Theme.ink.ink)
            .defaultFocus(true)
            .enableKeyboardOnFocus(true)
            .margin({ left: 4 })
            .onChange((value: string): void => {
              this.bar.query = value;
            })
            .onSubmit((): void => {
              AppUI.keyboardHide();
              this.bar.submitTick = this.bar.submitTick + 1;
            })
        }
        .width('100%')
        .height(AppTopBar.barHeight)
        .padding({ left: 8, right: 12 })
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ top: AppTopBar.topPad })
    }
    .width('100%')
    .height(AppTopBar.topPad + AppTopBar.barHeight)
  }
}
