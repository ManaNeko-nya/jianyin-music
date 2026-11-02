import { Theme, withAlpha } from './Theme';
import { InkGlyph, IconName } from './Icons';
import { L10n } from '../data/L10n';

/** 标题栏共用的底：恒定模糊，主题色占绝大多数，只留少量透出内容。 */
@ComponentV2
export struct BarSurface {
  build() {
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor(withAlpha(Theme.ink.canvas, 0.82))
      .backdropBlur(40)
  }
}

@ComponentV2
export struct BarIconButton {
  @Param name: IconName = 'back';
  @Param color: string = '';
  @Event onTap: () => void = () => {
  };

  build() {
    Stack({ alignContent: Alignment.Center }) {
      InkGlyph({ name: this.name, boxSize: 20, color: this.color.length > 0 ? this.color : Theme.ink.ink })
    }
    .width(40)
    .height(40)
    .onClick((): void => this.onTap())
  }
}

@ComponentV2
export struct BarTextButton {
  @Param label: string = '';
  @Param color: string = '';
  @Event onTap: () => void = () => {
  };

  build() {
    Text(L10n.tr(this.label))
      .fontSize(14)
      .fontWeight(500)
      .fontColor(this.color.length > 0 ? this.color : Theme.ink.ink)
      .padding({ left: 8, right: 8, top: 8, bottom: 8 })
      .onClick((): void => this.onTap())
  }
}
