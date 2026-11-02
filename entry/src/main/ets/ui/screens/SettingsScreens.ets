import { Session } from '../../data/Session';
import { Theme, Typo } from '../Theme';
import {
  InkText, Kicker, Hairline, AppTopBar,
} from '../Components';
import { InkGlyph } from '../Icons';
import { AppNav } from '../AppNav';
import { TopBarState } from '../AppState';
import { SecondaryTitleBar } from '../TopBar';
import { L10n } from '../../data/L10n';

@ComponentV2
export struct AboutScreen {
  @Local bar: TopBarState = new TopBarState();

  @Builder
  private backendLink(name: string, url: string) {
    Column({ space: 4 }) {
      Row({ space: 8 }) {
        InkText({ text: name, style: Typo.titleSmall, color: Theme.ink.ink })
        Hyperlink(url, '打开 GitHub')
          .color(Theme.ink.accent)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      InkText({
        text: url,
        style: Typo.bodySmall,
        color: Theme.ink.inkMuted,
        lines: 1,
      })
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: 0 }) {
        Scroll() {
        Column({ space: 0 }) {
          Row().height(AppTopBar.contentTop())
          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width(96)
              .height(96)
              .borderRadius(48)
              .backgroundColor('#FF0C0D11')
            InkGlyph({ name: 'musicNote', boxSize: 44, color: '#FFF3F2EE' })
          }
          .width(96)
          .height(96)
          Row().height(20)
          InkText({ text: '简音', style: Typo.displaySmall, color: Theme.ink.ink })
          InkText({ text: '版本 1.0.0', style: Typo.bodyMedium, color: Theme.ink.inkMuted })
          Row().height(24)
          InkText({
            text: '使用体验更像常规流媒体的音乐前端APP',
            style: Typo.bodyMedium,
            color: Theme.ink.inkSoft,
          })
          Row().height(10)
          InkText({
            text: '简音希望把自托管音乐库的使用体验做得像日常流媒体一样顺手：打开就能看到封面、推荐、专辑和艺人，播放、队列、歌词、搜索、歌单都在熟悉的位置。界面克制、动画流畅、信息层级清楚；音乐数据留在自己的服务器上，不绑定云账号，也不锁定单一后端。GuoBeng 与 Navidrome/Subsonic 都可以接入，未开放登录的服务器也可以用游客模式直接浏览。',
            style: Typo.bodyMedium,
            color: Theme.ink.inkSoft,
          })

          Row().height(24)
          Hairline()
          Row().height(20)
          Kicker({ text: '开源项目' })
          Row().height(10)
          this.backendLink('简音客户端', 'https://github.com/ManaNeko-nya/jianyin-music')
          Row().height(12)
          this.backendLink('GuoBeng 后端', 'https://github.com/ManaNeko-nya/guobeng-music-backend')
          Row().height(12)
          this.backendLink('Navidrome', 'https://github.com/navidrome/navidrome')

          Row().height(24)
          Hairline()
          Row().height(16)
          InkText({
            text: L10n.fmt('fmt_service', [Session.baseUrl]),
            style: Typo.bodySmall,
            color: Theme.ink.inkMuted,
            lines: 1,
          })
          Row().height(24 + AppNav.floatClearance)
        }
        .width('100%')
        .padding({ left: 22, right: 22 })
        .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .width('100%')
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')

      SecondaryTitleBar({ title: '关于', bar: this.bar })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.ink.canvas)
  }
}
