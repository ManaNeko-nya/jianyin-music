import { Session } from '../../data/Session';
import { AlbumDetail, Track } from '../../data/Models';
import { Player } from '../../playback/PlayerEngine';
import { SongListPage } from '../SongList';
import { Theme, Typo, withAlpha, WHITE, BLACK, TRANSPARENT, InkPalette } from '../Theme';
import {
  InkText, Kicker, Hairline, LoadingBox, ErrorBox, PlayAllControl, AppTopBar, Loading, Success, LoadError,
} from '../Components';
import { AppNav } from '../AppNav';
import { AlbumViewModel } from '../ScreenViewModels';
import {
  SelectionActionBar, standardSelectionActions, TrackActionsController, TrackActionsHost,
} from './TrackActions';
import { AppUI, Backs, TopBarState } from '../AppState';
import { SecondaryTitleBar } from '../TopBar';
import { L10n } from '../../data/L10n';

@ComponentV2
export struct AlbumScreen {
  @Param albumId: number = 0;
  @Local vm: AlbumViewModel = new AlbumViewModel(0);
  @Local actions: TrackActionsController = new TrackActionsController();
  @Local selectionMode: boolean = false;
  @Local selectedIds: Set<number> = new Set<number>();
  @Local bar: TopBarState = new TopBarState();
  private backHandler: () => boolean = (): boolean => false;

  aboutToAppear(): void {
    this.vm = new AlbumViewModel(this.albumId);
    this.backHandler = (): boolean => {
      if (this.selectionMode) {
        this.exitSelection();
        return true;
      }
      return false;
    };
    Backs.push(this.backHandler);
    this.bar.onSelect = (): void => {
      this.selectedIds = new Set<number>();
      this.selectionMode = true;
    };
    this.bar.onToggle = (): void => this.toggleSelectAll();
    this.bar.onDone = (): void => this.exitSelection();
    this.syncBar();
  }

  aboutToDisappear(): void {
    Backs.pop(this.backHandler);
  }

  @Monitor('selectionMode', 'selectedIds', 'vm.state')
  onBarStateChanged(): void {
    this.syncBar();
  }

  private syncBar(): void {
    if (this.selectionMode) {
      this.bar.menuKind = 'select';
      this.bar.toggleLabel = this.allSelected() ? '取消全选' : '全选';
      this.bar.sub = L10n.fmt('fmt_selected_count', [this.selectedIds.size]);
      return;
    }
    this.bar.sub = '';
    this.bar.menuKind = this.tracks().length > 0 ? 'selectOnly' : 'none';
  }

  private tracks(): Track[] {
    const state = this.vm.state;
    return state instanceof Success ? (state as Success<AlbumDetail>).data.tracks : [];
  }

  private allSelected(): boolean {
    const list = this.tracks();
    return list.length > 0 && this.selectedIds.size === list.length;
  }

  private toggleSelectAll(): void {
    this.selectedIds = this.allSelected()
      ? new Set<number>()
      : new Set<number>(this.tracks().map((t: Track): number => t.id));
  }

  private exitSelection(): void {
    this.selectionMode = false;
    this.selectedIds = new Set<number>();
  }

  private enqueueSelected(): void {
    const picked = this.tracks().filter((t: Track): boolean => this.selectedIds.has(t.id));
    if (picked.length > 0) {
      Player.enqueue(picked);
      AppUI.toast('已加入播放列表');
    }
    this.exitSelection();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.vm.state instanceof Loading) {
        LoadingBox()
      } else if (this.vm.state instanceof LoadError) {
        ErrorBox({
          message: (this.vm.state as LoadError<AlbumDetail>).message,
          onRetry: (): void => this.vm.load(this.albumId),
        })
      } else if (this.vm.state instanceof Success) {
        Stack({ alignContent: Alignment.Bottom }) {
          SongListPage({
            tracks: this.tracks(),
            currentTrackId: Player.state.track !== null ? Player.state.track.id : -1,
            hasMoreAction: true,
            selectionMode: this.selectionMode,
            selectedIds: this.selectedIds,
            emptyTitle: '专辑还没有歌曲',
            emptySubtitle: '在管理端上传音频后即可播放',
            topPadding: AppTopBar.contentTop(),
            header: (): void => {
              this.headerItems((this.vm.state as Success<AlbumDetail>).data)
            },
            onPlay: (index: number): void => {
              const track = this.tracks()[index];
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
                Player.playQueue(this.tracks(), index);
              }
            },
            onMore: (t: Track): void => {
              this.actions.openTrack(t);
            },
          })

          if (this.selectionMode) {
            SelectionActionBar({
              busy: this.actions.busy,
              count: this.selectedIds.size,
              actions: standardSelectionActions(
                (): void => this.actions.openPicker(Array.from(this.selectedIds)),
                (): void => this.enqueueSelected(),
              ),
            })
          }
        }
        .width('100%')
        .height('100%')
      }

      TrackActionsHost({ controller: this.actions })

      SecondaryTitleBar({ title: '专辑', bar: this.bar })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.ink.canvas)
  }

  @Builder
  headerItems(detail: AlbumDetail) {
    Column({ space: 0 }) {
      Stack({ alignContent: Alignment.BottomStart }) {
        Image(Session.mediaUrl(detail.album.coverUrl))
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
              [TRANSPARENT, 0],
              [withAlpha(BLACK, 0.55), 0.78],
              [Theme.ink.canvas, 1],
            ],
          })
        Column({ space: 0 }) {
          Kicker({
            text: L10n.fmt('fmt_album_meta', [
              L10n.tr(detail.album.typeLabel),
              detail.album.year !== null ? String(detail.album.year) : L10n.tr('未知年份'),
            ]),
            color: withAlpha(WHITE, 0.62),
          })
          Row().height(7)
          InkText({ text: detail.album.title, style: Typo.displaySmall, color: WHITE, lines: 2 })
          Row().height(5)
          InkText({
            text: detail.album.artistLabel.length > 0 ? detail.album.artistLabel : '未知艺人',
            style: Typo.bodyMedium,
            color: withAlpha(WHITE, 0.74),
          })
        }
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 22, right: 22, top: 20, bottom: 20 })
      }
      .width('100%')
      .height(382)

      // 标题下方：左侧统计，右侧播放全部。
      Column({ space: 0 }) {
        Row().height(14)
        Row({ space: 0 }) {
          Column({ space: 0 }) {
            Kicker({ text: L10n.fmt('fmt_songs_count', [detail.album.trackCount]) })
            Row().height(4)
            InkText({
              text: detail.album.tags.length > 0 ? detail.album.tags.join('  ·  ') : '未标记曲风',
              style: Typo.bodySmall,
              color: Theme.ink.inkMuted,
              lines: 1,
            })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          PlayAllControl({
            label: '播放全部',
            onTap: (): void => {
              if (detail.tracks.length > 0) {
                Player.playQueue(detail.tracks, 0);
              }
            },
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (detail.album.description.length > 0) {
          Row().height(16)
          InkText({
            text: detail.album.description,
            style: Typo.bodyMedium,
            color: Theme.ink.inkSoft,
            lines: 4,
          })
        }
        Row().height(20)
        Hairline()
        Row().height(18)
        Kicker({ text: '曲目' })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 22, right: 22 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
