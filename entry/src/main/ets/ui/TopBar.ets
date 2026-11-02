import { Theme, Typo } from './Theme';
import { InkText, AppTopBar } from './Components';
import { BarIconButton, BarSurface, BarTextButton } from './BarChrome';
import { AppNav } from './AppNav';
import { Backs, TopBarState } from './AppState';

/** 二级页统一标题栏：实心顶栏 + 内容滑入后的模糊背景。 */
@ComponentV2
export struct SecondaryTitleBar {
  @Param title: string = '';
  @Param bar: TopBarState = new TopBarState();

  private goBack(): void {
    if (Backs.handle()) {
      return;
    }
    if (AppNav.canPop) {
      AppNav.pop();
    }
  }

  @Builder
  private menu() {
    Row({ space: 0 }) {
      if (this.bar.menuKind === 'actions') {
        BarIconButton({ name: 'checklist', onTap: (): void => this.bar.onSelect() })
        BarIconButton({ name: 'more', onTap: (): void => this.bar.onMore() })
      } else if (this.bar.menuKind === 'selectOnly') {
        BarIconButton({ name: 'checklist', onTap: (): void => this.bar.onSelect() })
      } else if (this.bar.menuKind === 'more') {
        BarIconButton({ name: 'more', onTap: (): void => this.bar.onMore() })
      } else if (this.bar.menuKind === 'select') {
        BarTextButton({ label: this.bar.toggleLabel, onTap: (): void => this.bar.onToggle() })
        BarTextButton({ label: '完成', onTap: (): void => this.bar.onDone() })
      }
    }
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      BarSurface()

      Column({ space: 0 }) {
        Row({ space: 0 }) {
          BarIconButton({ name: 'back', onTap: (): void => this.goBack() })
          Column({ space: 0 }) {
            InkText({ text: this.title, style: Typo.titleLarge, color: Theme.ink.ink, lines: 1 })
            if (this.bar.sub.length > 0) {
              InkText({ text: this.bar.sub, style: Typo.bodySmall, color: Theme.ink.inkMuted, lines: 1 })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Center)
          .layoutWeight(1)
          .margin({ left: 2, right: 4 })
          this.menu()
        }
        .width('100%')
        .height(AppTopBar.barHeight)
        .padding({ left: 8, right: 8 })
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ top: AppTopBar.topPad })
    }
    .width('100%')
    .height(AppTopBar.topPad + AppTopBar.barHeight)
  }
}
