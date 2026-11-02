import { Session } from '../../data/Session';
import { Album, HomeData, Track } from '../../data/Models';
import { averageColor } from '../../data/ArtworkColor';
import { Player } from '../../playback/PlayerEngine';
import { SongListPage } from '../SongList';
import { Theme, Typo, withAlpha, lerpColor, luminance, WHITE, BLACK, TRANSPARENT, InkPalette, DarkInk, LightInk } from '../Theme';
import {
  InkText, Artwork, AlbumTile, ImmersiveCircleIconButton, SectionHeading, LoadingBox, ErrorBox, AppTopBar,
} from '../Components';
import { TrackActionsController, TrackActionsHost } from './TrackActions';
import { LoadState, Loading, Success, LoadError } from '../Components';
import { AppNav } from '../AppNav';
import { HomeViewModel } from '../ScreenViewModels';

@ComponentV2
export struct HomeScreen {
  @Param dataVersion: number = 0;
  @Local vm: HomeViewModel = new HomeViewModel();
  @Local actions: TrackActionsController = new TrackActionsController();

  @Monitor('dataVersion')
  onSessionChanged(): void {
    this.vm = new HomeViewModel();
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      if (this.vm.state instanceof Loading) {
        LoadingBox()
      } else if (this.vm.state instanceof LoadError) {
        ErrorBox({
          message: (this.vm.state as LoadError<HomeData>).message,
          onRetry: (): void => this.vm.load(),
        })
      } else if (this.vm.state instanceof Success) {
        HomeContent({
          data: (this.vm.state as Success<HomeData>).data,
          actions: this.actions,
          dark: Theme.darkTheme,
        })
      }

      Row({ space: 0 }) {
        ImmersiveCircleIconButton({
          icon: 'search',
          desc: '搜索',
          onTap: (): void => AppNav.openSearch(),
          tint: WHITE,
          boxSize: 48,
          iconSize: 22,
        })
      }
      .padding({ right: 12, top: AppTopBar.topPad + 6 })

      TrackActionsHost({ controller: this.actions })
    }
    .width('100%')
    .height('100%')
  }
}

@ComponentV2
struct HomeContent {
  @Param data: HomeData = new HomeData([], [], [], []);
  @Param actions: TrackActionsController = new TrackActionsController();
  @Param dark: boolean = false;

  build() {
    SongListPage({
      tracks: this.data.latest,
      currentTrackId: Player.state.track !== null ? Player.state.track.id : -1,
      showEmptyState: false,
      header: (): void => {
        this.headerItems()
      },
      footer: (): void => {
        this.footerItems()
      },
      onPlay: (index: number): void => {
        Player.playQueue(this.data.latest, index);
      },
      onMore: (track: Track): void => {
        this.actions.openTrack(track);
      },
    })
  }

  @Builder
  headerItems() {
    // 多个区块必须包进同一个 Column，否则在 ListItem 中会互相叠放。
    Column({ space: 0 }) {
      if (this.data.featured.length > 0) {
        FeaturedPager({ albums: this.data.featured, dark: this.dark })
      }
      if (this.data.recommended.length > 0) {
        SectionHeading({ title: '为你推荐', actionText: '全部专辑', onAction: (): void => AppNav.openAllAlbums() })
        AlbumRail({ albums: this.data.recommended })
      }
      if (this.data.latest.length > 0) {
        SectionHeading({ title: '最近上架' })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  footerItems() {
    Column({ space: 0 }) {
      if (this.data.ranking.length > 0) {
        SectionHeading({ title: '热门专辑' })
        ForEach(this.data.ranking.slice(0, 5), (album: Album) => {
          RankRow({ index: this.data.ranking.indexOf(album), album: album })
        }, (album: Album) => `rank-${album.id}`)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

@ComponentV2
struct FeaturedPager {
  @Param albums: Album[] = [];
  @Param dark: boolean = false;
  @Local page: number = 0;
  @Local dotTick: number = 0;

  private palette(): InkPalette {
    return this.dark ? DarkInk : LightInk;
  }

  build() {
    Column({ space: 0 }) {
      Swiper() {
        ForEach(this.albums, (album: Album) => {
          FeaturedPage({ album: album, dark: this.dark })
        }, (album: Album) => album.id.toString())
      }
      .autoPlay(this.albums.length > 1)
      .interval(6000)
      .duration(650)
      .loop(true)
      .indicator(false)
      .width('100%')
      .height(430)
      .onChange((index: number) => {
        this.page = index;
        this.dotTick++;
      })

      Row({ space: 6 }) {
        ForEach(this.albums, (_album: Album, index?: number) => {
          Row()
            .height(2)
            .width(this.page === index ? 26 : 12)
            .backgroundColor(this.page === index ? this.palette().ink : this.palette().hairline)
        }, (_album: Album, index?: number) => `dot-${index}`)
      }
      .width('100%')
      .padding({ left: 22, right: 22, top: 12, bottom: 12 })
    }
  }
}

@ComponentV2
struct FeaturedPage {
  @Param album: Album = new Album(0, 0, '', '', '', 'album', '', null, null, 0, '', []);
  @Param dark: boolean = false;
  @Local artColor: string = Theme.ink.raised;

  private palette(): InkPalette {
    return this.dark ? DarkInk : LightInk;
  }

  aboutToAppear(): void {
    const url = this.album.coverUrl.length > 0 ? Session.mediaUrl(this.album.coverUrl) : null;
    if (url === null) {
      return;
    }
    averageColor(url).then((rgb: string | null): void => {
      if (rgb !== null) {
        this.artColor = rgb;
      }
    });
  }

  private base(): string {
    const dark = luminance(this.artColor) > 0.55 ? 0.56 : 0.32;
    return lerpColor(this.artColor, BLACK, dark);
  }

  private tint(): string {
    return this.dark ? this.base() : this.palette().canvas;
  }

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Image(Session.mediaUrl(this.album.coverUrl))
        .objectFit(ImageFit.Cover)
        .draggable(false)
        .width('100%')
        .height('100%')
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [
            [withAlpha(this.tint(), 0.82), 0],
            [withAlpha(this.tint(), 0.38), 0.12],
            [TRANSPARENT, 0.32],
            [TRANSPARENT, 0.6],
            [withAlpha(this.tint(), 0.55), 0.8],
            [this.palette().canvas, 1],
          ],
        })
      Column({ space: 0 }) {
        InkText({
          text: this.album.title,
          style: Typo.displayMedium,
          color: this.dark ? WHITE : this.palette().ink,
          lines: 2,
        })
        Row().height(6)
        InkText({
          text: this.album.artistLabel.length > 0 ? this.album.artistLabel : this.album.metaLine,
          style: Typo.bodyMedium,
          color: this.dark ? withAlpha(WHITE, 0.72) : this.palette().inkMuted,
          lines: 1,
        })
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 22, right: 22, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .onClick((event?: ClickEvent) => {
      AppNav.openAlbum(this.album.id);
    })
  }
}

@ComponentV2
struct AlbumRail {
  @Param albums: Album[] = [];

  build() {
    Scroll() {
      Row({ space: 14 }) {
        ForEach(this.albums, (album: Album) => {
          AlbumTile({ album: album, onTap: (): void => AppNav.openAlbum(album.id) })
        }, (album: Album) => album.id.toString())
      }
      .padding({ left: 20, right: 20 })
      .alignItems(VerticalAlign.Top)
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }
}

@ComponentV2
struct RankRow {
  @Param index: number = 0;
  @Param album: Album = new Album(0, 0, '', '', '', 'album', '', null, null, 0, '', []);

  build() {
    Row({ space: 0 }) {
      InkText({
        text: this.index < 9 ? `0${this.index + 1}` : String(this.index + 1),
        style: Typo.headlineSmall,
        color: this.index === 0 ? Theme.ink.accent : withAlpha(Theme.ink.inkMuted, 0.6),
      })
        .width(42)
      Stack() {
        Artwork({ url: this.album.coverUrl, desc: this.album.title, corner: 6 })
      }
      .width(48)
      .height(48)
      Row().width(13).height(1)
      Column({ space: 0 }) {
        InkText({
          text: this.album.title,
          style: Typo.titleSmall,
          color: Theme.ink.ink,
          lines: 1,
        })
        InkText({
          text: this.album.metaLine,
          style: Typo.bodySmall,
          color: Theme.ink.inkMuted,
          lines: 1,
        })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.album.score !== null) {
        InkText({
          text: this.album.score.toFixed(1),
          style: Typo.titleMedium,
          color: Theme.ink.accent,
        })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 20, right: 20, top: 9, bottom: 9 })
    .onClick((event?: ClickEvent) => {
      AppNav.openAlbum(this.album.id);
    })
  }
}
