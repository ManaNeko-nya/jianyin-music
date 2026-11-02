import { Track, Album, SearchResults } from '../../data/Models';
import { Player } from '../../playback/PlayerEngine';
import { SongListPage } from '../SongList';
import { Theme, Typo } from '../Theme';
import {
  InkText, Kicker, EmptyBox, ErrorBox,
  AlbumTile, TinySpinner, AppTopBar,
} from '../Components';
import { InkGlyph } from '../Icons';
import { AppUI, SearchBarState } from '../AppState';
import { AppNav } from '../AppNav';
import { L10n } from '../../data/L10n';
import { SearchViewModel } from '../ScreenViewModels';
import { SearchTopBar } from '../SearchTopBar';
import { TrackActionsController, TrackActionsHost } from './TrackActions';

/** 搜索页内容从搜索栏下方开始。 */
function searchTop(): number {
  return AppTopBar.contentTop();
}

@ComponentV2
export struct SearchScreen {
  @Local vm: SearchViewModel = new SearchViewModel();
  @Local actions: TrackActionsController = new TrackActionsController();
  @Local query: string = '';
  @Local bar: SearchBarState = new SearchBarState();

  /** 搜索框在独立搜索栏里，输入与提交从这里回流。 */
  @Monitor('bar.query', 'bar.submitTick')
  onBarChanged(): void {
    if (this.query === this.bar.query) {
      this.vm.search();
      return;
    }
    this.query = this.bar.query;
    this.vm.updateQuery(this.query);
  }


  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: 0 }) {
        Stack({ alignContent: Alignment.TopStart }) {
          if (this.vm.state.error.length > 0) {
            Column({ space: 0 }) {
              ErrorBox({
                message: this.vm.state.error,
                onRetry: (): void => this.vm.search(),
              })
            }
            .width('100%')
            .padding({ top: searchTop() })
          } else if (this.vm.state.results === null) {
            Column({ space: 0 }) {
              EmptyBox({ title: '搜索你的音乐库', subtitle: '输入歌名、专辑名或艺人名' })
            }
            .width('100%')
            .padding({ top: searchTop() })
          } else if ((this.vm.state.results as SearchResults).albums.length === 0 &&
            (this.vm.state.results as SearchResults).tracks.length === 0) {
            Column({ space: 0 }) {
              EmptyBox({ title: L10n.fmt('fmt_no_results', [this.query]), subtitle: '换一个关键词试试' })
            }
            .width('100%')
            .padding({ top: searchTop() })
          } else {
            SearchResultsList({
              albums: (this.vm.state.results as SearchResults).albums,
              tracks: (this.vm.state.results as SearchResults).tracks,
              hasMore: this.vm.state.hasMoreTracks,
              loadingMore: this.vm.state.loadingMore,
              topPadding: searchTop(),
              onLoadMore: (): void => this.vm.loadMore(),
              actions: this.actions,
            })
          }
        }
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')

      TrackActionsHost({ controller: this.actions })

      SearchTopBar({ bar: this.bar })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.ink.canvas)
  }
}

@ComponentV2
struct SearchResultsList {
  @Param albums: Album[] = [];
  @Param tracks: Track[] = [];
  @Param hasMore: boolean = false;
  @Param loadingMore: boolean = false;
  @Param topPadding: number = 0;
  @Event onLoadMore: () => void = () => {
  };
  @Param actions: TrackActionsController = new TrackActionsController();

  build() {
    SongListPage({
      tracks: this.tracks,
      topPadding: this.topPadding,
      currentTrackId: Player.state.track !== null ? Player.state.track.id : -1,
      pagingEnabled: true,
      hasMore: this.hasMore,
      loadingMore: this.loadingMore,
      hasMoreAction: true,
      emptyTitle: '没有找到歌曲',
      emptySubtitle: '换一个关键词试试',
      onLoadMore: (): void => this.onLoadMore(),
      header: (): void => {
        this.headerItems()
      },
      onPlay: (index: number): void => {
        Player.playQueue(this.tracks, index);
      },
      onMore: (track: Track): void => {
        this.actions.openTrack(track);
      },
    })
  }

  @Builder
  headerItems() {
    // 多区块包进同一 Column，防止在 ListItem 中叠放。
    Column({ space: 0 }) {
      if (this.albums.length > 0) {
        Row({ space: 0 }) {
          InkText({ text: '专辑', style: Typo.headlineSmall, color: Theme.ink.ink })
            .layoutWeight(1)
          Kicker({ text: String(this.albums.length) })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 22, bottom: 10 })
        .alignItems(VerticalAlign.Center)

        Scroll() {
          Row({ space: 14 }) {
            ForEach(this.albums, (album: Album) => {
              AlbumTile({ album: album, onTap: (): void => AppNav.openAlbum(album.id) })
            }, (album: Album) => `s-${album.id}`)
          }
          .padding({ left: 20, right: 20 })
          .alignItems(VerticalAlign.Top)
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      }

      Row({ space: 0 }) {
        InkText({ text: '歌曲', style: Typo.headlineSmall, color: Theme.ink.ink })
          .layoutWeight(1)
        Kicker({ text: String(this.tracks.length) })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 24, bottom: 8 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}


