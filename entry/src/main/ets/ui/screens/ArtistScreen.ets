import { Session } from '../../data/Session';
import { Album, ArtistDetail, Track } from '../../data/Models';
import { Player } from '../../playback/PlayerEngine';
import { SongListPage } from '../SongList';
import { Theme, Typo, withAlpha, WHITE, BLACK, TRANSPARENT } from '../Theme';
import {
  InkText, Kicker, AlbumTile, Hairline, LoadingBox, ErrorBox, EmptyBox, AppTopBar,
  Loading, Success, LoadError,
} from '../Components';
import { AppNav } from '../AppNav';
import { ArtistTracksViewModel, ArtistViewModel } from '../ScreenViewModels';
import { TopBarState } from '../AppState';
import { SecondaryTitleBar } from '../TopBar';
import { L10n } from '../../data/L10n';
import { TrackActionsController, TrackActionsHost } from './TrackActions';

/** 歌手头部（300 封面 + 52 标签栏 + 1 分隔线）。 */
const ARTIST_HEADER_HEIGHT: number = 353;

@ComponentV2
export struct ArtistScreen {
  @Param artistId: number = 0;
  @Local vm: ArtistViewModel = new ArtistViewModel(0);
  @Local tracksVm: ArtistTracksViewModel = new ArtistTracksViewModel(0);
  @Local bar: TopBarState = new TopBarState();

  aboutToAppear(): void {
    this.vm = new ArtistViewModel(this.artistId);
    this.tracksVm = new ArtistTracksViewModel(this.artistId);
    this.tracksVm.load(this.artistId);
  }

  private coverOf(detail: ArtistDetail | null): string {
    if (detail === null) {
      return '';
    }
    if (detail.coverUrl.length > 0) {
      return detail.coverUrl;
    }
    if (detail.albums.length > 0) {
      return detail.albums[0].coverUrl;
    }
    return '';
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.vm.state instanceof Loading) {
        LoadingBox()
      } else if (this.vm.state instanceof LoadError) {
        ErrorBox({
          message: (this.vm.state as LoadError<ArtistDetail>).message,
          onRetry: (): void => this.vm.load(this.artistId),
        })
      } else if (this.vm.state instanceof Success) {
        ArtistContent({
          detail: (this.vm.state as Success<ArtistDetail>).data,
          cover: this.coverOf((this.vm.state as Success<ArtistDetail>).data),
          tracksVm: this.tracksVm,
        })
      }

      SecondaryTitleBar({ title: '艺人', bar: this.bar })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.ink.canvas)
  }
}

@ComponentV2
struct ArtistContent {
  @Param detail: ArtistDetail = new ArtistDetail(0, '', '', '', 0, []);
  @Param cover: string = '';
  @Param tracksVm: ArtistTracksViewModel = new ArtistTracksViewModel(0);
  @Local tab: number = 0;
  @Local actions: TrackActionsController = new TrackActionsController();
  @Local headerOffset: number = 0;
  private albumScroll: number = 0;
  private songScroll: number = 0;
  private tabs: TabsController = new TabsController();
  private albumScroller: Scroller = new Scroller();

  private clampOffset(offset: number): number {
    return Math.min(Math.max(offset, 0), ARTIST_HEADER_HEIGHT);
  }

  private selectTab(index: number): void {
    this.tab = index;
    this.tabs.changeIndex(index);
    this.headerOffset = this.clampOffset(index === 0 ? this.albumScroll : this.songScroll);
  }

  private onAlbumsScroll(): void {
    this.albumScroll = this.albumScroller.currentOffset().yOffset;
    if (this.tab === 0) {
      this.headerOffset = this.clampOffset(this.albumScroll);
    }
  }

  private onSongsScroll(offset: number): void {
    this.songScroll = offset;
    if (this.tab === 1) {
      this.headerOffset = this.clampOffset(offset);
    }
  }

  private trackCount(): number {
    return this.tracksVm.total > 0 ? this.tracksVm.total : this.detail.trackCount;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Tabs({ barPosition: BarPosition.Start, index: this.tab, controller: this.tabs }) {
        TabContent() {
          this.albumsTab()
        }

        TabContent() {
          this.songsTab()
        }
      }
      .barHeight(0)
      .scrollable(false)
      .width('100%')
      .height('100%')
      .onChange((index: number): void => {
        this.tab = index;
        this.headerOffset = this.clampOffset(index === 0 ? this.albumScroll : this.songScroll);
      })

      // 头部在 Tabs 外层：左右滑动只动列表，头像固定；上下滚动时随列表让位。
      Column() {
        this.artistHeader()
      }
      .width('100%')
      .translate({ y: AppTopBar.contentTop() - this.headerOffset })
      .hitTestBehavior(HitTestMode.Transparent)

      TrackActionsHost({ controller: this.actions })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.ink.canvas)
  }

  @Builder
  private artistHeader() {
    ArtistHeader({
      detail: this.detail,
      cover: this.cover,
      tab: this.tab,
      trackCount: this.trackCount(),
      onSelectTab: (index: number): void => this.selectTab(index),
    })
  }

  @Builder
  private albumsTab() {
    List({ scroller: this.albumScroller, space: 0 }) {
      ListItem() {
        Column()
          .width('100%')
          .height(AppTopBar.contentTop() + ARTIST_HEADER_HEIGHT)
      }

      if (this.detail.albums.length === 0) {
        ListItem() {
          Column() {
            EmptyBox({ title: '还没有公开专辑', subtitle: '该艺人名下的专辑会出现在这里' })
          }
          .width('100%')
          .height(320)
        }
      } else {
        ForEach(this.chunkedRows(), (row: Album[], rowIndex?: number) => {
          ListItem() {
            Row({ space: 16 }) {
              ForEach(row, (album: Album) => {
                Column() {
                  AlbumTile({
                    album: album,
                    tileWidth: 0,
                    onTap: (): void => AppNav.openAlbum(album.id),
                  })
                }
                .layoutWeight(1)
              }, (album: Album) => album.id.toString())
              if (row.length === 1) {
                Column().layoutWeight(1)
              }
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 7, bottom: 15 })
            .alignItems(VerticalAlign.Top)
          }
        }, (row: Album[], rowIndex?: number) => `row-${rowIndex}`)

        ListItem() {
          Column()
            .width('100%')
            .height(28 + (Player.state.track !== null ? AppNav.floatClearance : 0))
        }
      }
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .onDidScroll((_offset: number, _state: ScrollState): void => {
      this.onAlbumsScroll();
    })
  }

  @Builder
  private songsTab() {
    SongListPage({
      tracks: this.tracksVm.items,
      currentTrackId: Player.state.track !== null ? Player.state.track.id : -1,
      topPadding: AppTopBar.contentTop() + ARTIST_HEADER_HEIGHT,
      showEmptyState: !this.tracksVm.loading && this.tracksVm.error.length === 0,
      emptyTitle: '暂无参与歌曲',
      emptySubtitle: '该艺人参与的合作曲也会出现在这里',
      pagingEnabled: true,
      hasMore: this.tracksVm.hasMore,
      loadingMore: this.tracksVm.loadingMore,
      hasMoreAction: true,
      footer: (): void => {
        this.tracksStatus()
      },
      onLoadMore: (): void => this.tracksVm.loadMore(),
      onScrollOffset: (offset: number): void => this.onSongsScroll(offset),
      onPlay: (index: number): void => {
        Player.playQueue(this.tracksVm.items, index);
      },
      onMore: (track: Track): void => {
        this.actions.openTrack(track);
      },
    })
  }

  @Builder
  private tracksStatus() {
    if (this.tracksVm.loading && this.tracksVm.items.length === 0) {
      Column() {
        LoadingBox()
      }
      .width('100%')
      .height(240)
    } else if (this.tracksVm.error.length > 0 && this.tracksVm.items.length === 0) {
      Column() {
        ErrorBox({
          message: this.tracksVm.error,
          onRetry: (): void => this.tracksVm.reload(),
        })
      }
      .width('100%')
      .height(320)
    }
  }

  private chunkedRows(): Album[][] {
    const rows: Album[][] = [];
    for (let i = 0; i < this.detail.albums.length; i += 2) {
      rows.push(this.detail.albums.slice(i, i + 2));
    }
    return rows;
  }
}

@ComponentV2
struct ArtistHeader {
  @Param detail: ArtistDetail = new ArtistDetail(0, '', '', '', 0, []);
  @Param cover: string = '';
  @Param tab: number = 0;
  @Param trackCount: number = 0;
  @Event onSelectTab: (index: number) => void = (_index: number) => {
  };

  private countLine(): string {
    const albums = this.detail.albumCount;
    const tracks = this.trackCount;
    return L10n.fmt('fmt_artist_counts', [albums, tracks]);
  }

  build() {
    Column({ space: 0 }) {
      Stack({ alignContent: Alignment.BottomStart }) {
        if (this.cover.length > 0) {
          Image(Session.mediaUrl(this.cover))
            .objectFit(ImageFit.Cover)
            .draggable(false)
            .width('100%')
            .height('100%')
        } else {
          Column()
            .width('100%')
            .height('100%')
            .linearGradient({ angle: 180, colors: [[Theme.ink.raised, 0], [Theme.ink.canvas, 1]] })
        }
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 180,
            colors: [
              [TRANSPARENT, 0],
              [withAlpha(BLACK, 0.2), 0.52],
              [withAlpha(BLACK, 0.55), 0.8],
              [Theme.ink.canvas, 1],
            ],
          })
        Column({ space: 0 }) {
          Kicker({
            text: this.countLine(),
            color: withAlpha(WHITE, 0.6),
          })
          Row().height(7)
          InkText({
            text: this.detail.name.length > 0 ? this.detail.name : '未知艺人',
            style: Typo.displayMedium,
            color: WHITE,
            lines: 2,
          })
          if (this.detail.bio.length > 0) {
            Row().height(8)
            InkText({
              text: this.detail.bio,
              style: Typo.bodySmall,
              color: withAlpha(WHITE, 0.68),
              lines: 3,
            })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 22, right: 22, bottom: 22 })
      }
      .width('100%')
      .height(300)

      Row({ space: 0 }) {
        this.tabButton('专辑', 0, this.detail.albumCount)
        this.tabButton('歌曲', 1, this.trackCount)
        Blank()
      }
      .width('100%')
      .height(52)
      .padding({ left: 20, right: 20 })
      .alignItems(VerticalAlign.Center)

      Hairline()
    }
    .width('100%')
  }

  @Builder
  private tabButton(label: string, index: number, count: number) {
    Column({ space: 0 }) {
      Row({ space: 6 }) {
        InkText({
          text: label,
          style: Typo.titleMedium,
          color: this.tab === index ? Theme.ink.ink : Theme.ink.inkMuted,
        })
        InkText({
          text: String(count),
          style: Typo.labelMedium,
          color: this.tab === index ? Theme.ink.inkMuted : withAlpha(Theme.ink.inkMuted, 0.6),
        })
      }
      .height(50)
      .alignItems(VerticalAlign.Center)

      Row()
        .width(this.tab === index ? 26 : 0)
        .height(2)
        .borderRadius(1)
        .backgroundColor(this.tab === index ? Theme.ink.accent : TRANSPARENT)
        .animation({ duration: 180, curve: Curve.FastOutSlowIn })
    }
    .padding({ right: 24 })
    .alignItems(HorizontalAlign.Start)
    .onClick((): void => this.onSelectTab(index))
  }
}
