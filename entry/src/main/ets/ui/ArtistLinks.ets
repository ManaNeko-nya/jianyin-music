import { ArtistRef } from '../data/Models';
import { Theme, Typo, withAlpha } from './Theme';
import { InkGlyph } from './Icons';

/**
 * 歌手行：左侧 person 图标，右侧横向可滑动的艺人卡片。
 * 播放页“更多”和歌曲列表“更多”共用，避免两套实现。
 */
@ComponentV2
export struct ArtistLinks {
  @Param artists: ArtistRef[] = [];
  @Param fallbackId: number = 0;
  @Param fallbackName: string = '';
  @Param iconColor: string = '';
  @Param chipColor: string = '';
  @Param textColor: string = '';
  @Event onOpenArtist: (artistId: number) => void = (_artistId: number) => {
  };

  private people(): ArtistRef[] {
    if (this.artists.length > 0) {
      return this.artists;
    }
    if (this.fallbackName.length > 0) {
      return [new ArtistRef(this.fallbackId, this.fallbackName)];
    }
    return [new ArtistRef(0, '未知艺人')];
  }

  private iconClr(): string {
    return this.iconColor.length > 0 ? this.iconColor : Theme.ink.inkMuted;
  }

  private chipClr(): string {
    return this.chipColor.length > 0 ? this.chipColor : Theme.ink.fill;
  }

  private textClr(): string {
    return this.textColor.length > 0 ? this.textColor : Theme.ink.ink;
  }

  build() {
    Row({ space: 0 }) {
      InkGlyph({ name: 'person', boxSize: 19, color: this.iconClr() })
      Row().width(13).height(1)

      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.people(), (artist: ArtistRef) => {
            Text(artist.name)
              .fontSize(13)
              .fontColor(this.textClr())
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: 180 })
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .backgroundColor(this.chipClr())
              .borderRadius(16)
              .enabled(artist.id > 0)
              .opacity(artist.id > 0 ? 1 : 0.4)
              .onClick((): void => this.onOpenArtist(artist.id))
          }, (artist: ArtistRef) => `${artist.id}-${artist.name}`)
        }
        .alignItems(VerticalAlign.Center)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .align(Alignment.Start)
      .layoutWeight(1)
      .height(40)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ top: 8, bottom: 8 })
  }
}
