import { Track, Album } from '../../data/Models';
import { Player } from '../../playback/PlayerEngine';
import { SongListPage } from '../SongList';
import { Theme, Typo } from '../Theme';
import {
  InkText, Kicker, Artwork, AlbumTile, RoundIconButton, TextAction, Hairline, PageHeader,
  LoadingBox, ErrorBox, EmptyBox, TinySpinner, AppTopBar,
  LoadState, Loading, Success, LoadError,
} from '../Components';
import { InkGlyph } from '../Icons';
import { AppUI } from '../AppState';
import { AppNav } from '../AppNav';
import { L10n } from '../../data/L10n';
import { LibraryData, LibraryViewModel } from '../ScreenViewModels';
import { SelectionActionBar, standardSelectionActions, TrackActionsController, TrackActionsHost } from './TrackActions';

@ComponentV2
export struct LibraryScreen {
  @Param dataVersion: number = 0;
  @Local vm: LibraryViewModel = new LibraryViewModel();
  @Local selectionMode: boolean = false;
  @Local selectedIds: Set<number> = new Set<number>();
  @Local actions: TrackActionsController = new TrackActionsController();

  @Monitor('dataVersion')
  onSessionChanged(): void {
    this.selectionMode = false;
    this.selectedIds = new Set<number>();
    this.vm = new LibraryViewModel();
  }

  private enqueueSelected(data: LibraryData): void {
    const tracks = data.songs.items.filter((t: Track): boolean => this.selectedIds.has(t.id));
    if (tracks.length > 0) {
      Player.enqueue(tracks);
      AppUI.toast('已加入播放列表');
    }
    this.exitSelection();
  }

  private exitSelection(): void {
    this.selectionMode = false;
    this.selectedIds = new Set<number>();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: 0 }) {
        PageHeader({
          title: '曲库',
          trailing: (): void => {
            this.headerTrailing()
          },
        })

        Row({ space: 26 }) {
          this.tabButton('歌曲', 0)
          this.tabButton('专辑', 1)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 4 })
        .alignItems(VerticalAlign.Center)

        Hairline()
        Row().height(4)

        if (this.vm.state instanceof Loading) {
          Column() {
            LoadingBox()
          }
          .layoutWeight(1)
        } else if (this.vm.state instanceof LoadError) {
          Column() {
            ErrorBox({
              message: (this.vm.state as LoadError<LibraryData>).message,
              onRetry: (): void => this.vm.load(),
            })
          }
          .layoutWeight(1)
        } else if (this.vm.state instanceof Success) {
          Stack({ alignContent: Alignment.Bottom }) {
            if (AppNav.libraryTab === 0) {
              this.songsPane((this.vm.state as Success<LibraryData>).data)
            } else {
              this.albumsPane((this.vm.state as Success<LibraryData>).data)
            }
          }
          .layoutWeight(1)
          .width('100%')
        }
      }
      .width('100%')
      .height('100%')

      TrackActionsHost({
        controller: this.actions,
        onPicked: (): void => this.exitSelection(),
      })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  headerTrailing() {
    if (this.selectionMode && AppNav.libraryTab === 0) {
      TextAction({
        text: this.allSelected ? '取消全选' : '全选',
        showIcon: false,
        onTap: (): void => this.toggleSelectAll(),
      })
      TextAction({
        text: '完成',
        showIcon: false,
        onTap: (): void => this.exitSelection(),
      })
    } else {
      if (AppNav.libraryTab === 0 && this.songsCount() > 0) {
        RoundIconButton({
          icon: 'checklist',
          desc: '选择歌曲',
          onTap: (): void => {
            this.selectedIds = new Set<number>();
            this.selectionMode = true;
          },
        })
      }
      RoundIconButton({
        icon: 'search',
        desc: '搜索',
        onTap: (): void => AppNav.openSearch(),
      })
    }
  }

  private songsCount(): number {
    const state = this.vm.state;
    if (state instanceof Success) {
      return ((state as Success<never>).data as LibraryData).songs.items.length;
    }
    return 0;
  }

  private songsOf(data: LibraryData): Track[] {
    return data.songs.items;
  }

  private get allSelected(): boolean {
    return this.songsCount() > 0 && this.selectedIds.size >= this.songsCount();
  }

  private toggleSelectAll(): void {
    const state = this.vm.state;
    if (!(state instanceof Success)) {
      return;
    }
    const data = (state as Success<LibraryData>).data;
    if (this.allSelected) {
      this.selectedIds = new Set<number>();
    } else {
      this.selectedIds = new Set<number>(data.songs.items.map((t: Track): number => t.id));
    }
  }

  @Builder
  tabButton(label: string, value: number) {
    InkText({
      text: label,
      style: Typo.titleMedium,
      color: AppNav.libraryTab === value ? Theme.ink.ink : Theme.ink.inkMuted,
    })
      .padding({ top: 11, bottom: 11 })
      .onClick(() => {
        if (value !== 0) {
          this.exitSelection();
        }
        AppNav.libraryTab = value;
      })
  }

  @Builder
  songsPane(stateData: LibraryData) {
    if (stateData.songs.items.length === 0) {
      EmptyBox({ title: '曲库还没有歌曲', subtitle: '等待管理员上架后会自动出现在这里' })
    } else {
      SongListPage({
        tracks: stateData.songs.items,
        currentTrackId: Player.state.track !== null ? Player.state.track.id : -1,
        selectionMode: this.selectionMode,
        selectedIds: this.selectedIds,
        topPadding: 6,
        pagingEnabled: true,
        hasMore: stateData.hasMoreSongs,
        loadingMore: stateData.loadingMoreSongs,
        hasMoreAction: true,
        onLoadMore: (): void => this.vm.loadMoreSongs(),
        header: (): void => {
          this.songsHeader(stateData.songs.total, stateData)
        },
        onPlay: (index: number): void => {
          const track = stateData.songs.items[index];
          if (track === undefined) {
            return;
          }
          if (this.selectionMode) {
            const next = new Set<number>(this.selectedIds);
            if (next.has(track.id)) {
              next.delete(track.id);
            } else {
              next.add(track.id);
            }
            this.selectedIds = next;
          } else {
            Player.playQueue(stateData.songs.items, index);
          }
        },
        onMore: (track: Track): void => {
          this.actions.openTrack(track);
        },
      })
    }
    if (this.selectionMode) {
      SelectionActionBar({
        busy: this.actions.busy,
        count: this.selectedIds.size,
        actions: standardSelectionActions(
          (): void => this.actions.openPicker(Array.from(this.selectedIds)),
          (): void => this.enqueueSelected(stateData),
        ),
      })
    }
  }

  @Builder
  songsHeader(total: number, stateData: LibraryData) {
    Row({ space: 0 }) {
      Kicker({ text: L10n.fmt('fmt_songs_count', [total]) })
        .layoutWeight(1)
      Row({ space: 0 }) {
        InkGlyph({ name: 'play', boxSize: 16, color: Theme.ink.accent })
        Row().width(4).height(1)
        InkText({ text: '播放全部', style: Typo.labelLarge, color: Theme.ink.accent })
      }
      .alignItems(VerticalAlign.Center)
      .padding({ left: 8, right: 8, top: 6, bottom: 6 })
      .onClick(() => {
        const items = stateData.songs.items;
        if (items.length > 0) {
          Player.playQueue(items, 0);
        }
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 20, right: 12, top: 8, bottom: 4 })
  }

  @Builder
  albumsPane(stateData: LibraryData) {
    if (stateData.albums.items.length === 0) {
      EmptyBox({ title: '曲库还没有专辑', subtitle: '管理员上架专辑后会出现在这里' })
    } else {
      AlbumGrid({
        albums: stateData.albums.items,
        loadingMore: stateData.loadingMoreAlbums,
        hasMore: stateData.hasMoreAlbums,
        onLoadMore: (): void => this.vm.loadMoreAlbums(),
      })
    }
  }
}

@ComponentV2
struct AlbumGrid {
  @Param albums: Album[] = [];
  @Param loadingMore: boolean = false;
  @Param hasMore: boolean = false;
  @Event onLoadMore: () => void = () => {
  };
  private scroller: Scroller = new Scroller();

  build() {
    List({ scroller: this.scroller, space: 0 }) {
      ListItem() {
        Kicker({ text: L10n.fmt('fmt_albums_count', [this.albums.length]) })
          .width('100%')
          .padding({ top: 4, bottom: 4 })
      }

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
          .padding({ top: 7, bottom: 15 })
          .alignItems(VerticalAlign.Top)
        }
      }, (row: Album[], rowIndex?: number) => `row-${rowIndex}`)

      ListItem() {
        Column() {
          if (this.loadingMore) {
            TinySpinner({ color: Theme.ink.accent, boxSize: 16 })
          } else if (!this.hasMore) {
            Kicker({ text: L10n.fmt('fmt_loaded_all_albums', [this.albums.length]) })
          }
        }
        .width('100%')
        .height(56)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }

      ListItem() {
        Column().width('100%')
          .height(28 + (Player.state.track !== null ? AppNav.floatClearance : 0))
          .animation({ duration: 200, curve: Curve.FastOutSlowIn })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 8 })
    .scrollBar(BarState.Off)
    .onReachEnd(() => {
      if (this.hasMore && !this.loadingMore) {
        this.onLoadMore();
      }
    })
  }

  private chunkedRows(): Album[][] {
    const rows: Album[][] = [];
    for (let i = 0; i < this.albums.length; i += 2) {
      rows.push(this.albums.slice(i, i + 2));
    }
    return rows;
  }
}

