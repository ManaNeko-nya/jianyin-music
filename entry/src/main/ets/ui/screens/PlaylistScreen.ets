import { PlaylistDetail, Track } from '../../data/Models';
import { Player } from '../../playback/PlayerEngine';
import { MusicRepository } from '../../data/MusicRepository';
import { Session } from '../../data/Session';
import { SongListPage, SongListReorder } from '../SongList';
import { Theme, Typo, withAlpha, WHITE, BLACK, TRANSPARENT, InkPalette } from '../Theme';
import {
  InkText, Kicker, Hairline,
  LoadingBox, ErrorBox, PlayAllControl,
  Loading, Success, LoadError, AppTopBar,
} from '../Components';
import { InkGlyph } from '../Icons';
import { AppUI, Backs, TopBarState } from '../AppState';
import { SecondaryTitleBar } from '../TopBar';
import { L10n } from '../../data/L10n';
import { AppNav } from '../AppNav';
import { PlaylistViewModel } from '../ScreenViewModels';
import {
  SelectionActionBar, standardSelectionActions, TrackActionsController, TrackActionsHost,
  PlaylistNameSheet, DeletePlaylistSheet, PlaylistActionsSheet,
} from './TrackActions';

@ComponentV2
export struct PlaylistScreen {
  @Param playlistId: number = 0;
  @Local vm: PlaylistViewModel = new PlaylistViewModel(0);
  @Local selectionMode: boolean = false;
  @Local selectedIds: Set<number> = new Set<number>();
  @Local listBusy: boolean = false;
  @Local actions: TrackActionsController = new TrackActionsController();
  @Local showMore: boolean = false;
  @Local showRename: boolean = false;
  @Local showDelete: boolean = false;
  @Local actionBusy: boolean = false;
  @Local actionError: string = '';
  @Local bar: TopBarState = new TopBarState();
  private reorder: SongListReorder = new SongListReorder(
    (tracks: Track[]): void => {
      this.vm.applyTrackOrder(tracks);
      this.vm.saveTrackOrder((error: string | null): void => {
        if (error !== null) {
          AppUI.toast(error);
        }
      });
    },
  );
  private backHandler: () => boolean = (): boolean => false;

  aboutToAppear(): void {
    this.vm = new PlaylistViewModel(this.playlistId);
    this.backHandler = (): boolean => {
      if (this.selectionMode) {
        this.exitSelection();
        return true;
      }
      return false;
    };
    Backs.push(this.backHandler);
    this.syncBar();
  }

  aboutToDisappear(): void {
    Backs.pop(this.backHandler);
  }

  @Monitor('selectionMode', 'selectedIds', 'vm.state')
  onBarStateChanged(): void {
    this.syncBar();
  }

  /** 标题栏菜单项由本页状态驱动，保证和返回按钮同行同尺寸。 */
  private syncBar(): void {
    this.bar.onSelect = (): void => {
      this.selectedIds = new Set<number>();
      this.selectionMode = true;
    };
    this.bar.onMore = (): void => {
      this.actionError = '';
      this.showMore = true;
    };
    this.bar.onToggle = (): void => this.toggleSelectAll();
    this.bar.onDone = (): void => this.exitSelection();
    if (this.selectionMode) {
      this.bar.menuKind = 'select';
      this.bar.toggleLabel = this.allSelected() ? '取消全选' : '全选';
      this.bar.sub = L10n.fmt('fmt_selected_count', [this.selectedIds.size]);
      return;
    }
    this.bar.sub = '';
    const detail = this.detail();
    this.bar.menuKind = detail !== null && this.d().tracks.length > 0 ? 'actions' : 'more';
  }

  private toggleSelectAll(): void {
    if (this.detail() === null) {
      return;
    }
    this.selectedIds = this.allSelected()
      ? new Set<number>()
      : new Set<number>(this.d().tracks.map((t: Track): number => t.id));
  }

  private exitSelection(): void {
    this.selectionMode = false;
    this.selectedIds = new Set<number>();
  }

  /** 非空访问器：界面仅在 Success 分支渲染。 */
  private d(): PlaylistDetail {
    return this.detail() as PlaylistDetail;
  }

  private detail(): PlaylistDetail | null {
    const state = this.vm.state;
    if (state instanceof Success) {
      return (state as Success<PlaylistDetail>).data;
    }
    return null;
  }

  private removeTracks(ids: number[]): void {
    if (ids.length === 0 || this.listBusy) {
      return;
    }
    this.listBusy = true;
    MusicRepository.removeTracksFromPlaylist(this.playlistId, ids).then((): void => {
      this.exitSelection();
      // 编辑后静默刷新：保留旧列表与滚动位置。
      this.vm.load(true);
    }).catch((err: Object): void => {
      AppUI.toast(err instanceof Error && err.message.length > 0 ? err.message : '移出歌单失败');
    }).finally((): void => {
      this.listBusy = false;
    });
  }

  private enqueueTracks(ids: number[]): void {
    const detail = this.detail();
    if (detail !== null) {
      const tracks = this.d().tracks.filter((t: Track): boolean => ids.indexOf(t.id) >= 0);
      if (tracks.length > 0) {
        Player.enqueue(tracks);
        AppUI.toast('已加入播放列表');
      }
    }
    this.exitSelection();
  }

  private allSelected(): boolean {
    const detail = this.detail();
    return this.detail() !== null && this.d().tracks.length > 0 && this.selectedIds.size >= this.d().tracks.length;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.vm.state instanceof Loading) {
        LoadingBox()
      } else if (this.vm.state instanceof LoadError) {
        ErrorBox({
          message: (this.vm.state as LoadError<PlaylistDetail>).message,
          onRetry: (): void => this.vm.load(),
        })
      } else if (this.detail() !== null) {
        Stack({ alignContent: Alignment.Bottom }) {
          SongListPage({
            tracks: this.d().tracks,
            currentTrackId: Player.state.track !== null ? Player.state.track.id : -1,
            hasMoreAction: true,
            selectionMode: this.selectionMode,
            selectedIds: this.selectedIds,
            reorder: MusicRepository.capabilities.playlistReorder ? this.reorder : undefined,
            emptyTitle: '这个歌单还没有歌曲',
            emptySubtitle: '在曲库中长按歌曲即可加入歌单',
            topPadding: AppTopBar.contentTop(),
            header: (): void => {
              this.headerItems(this.detail() as PlaylistDetail)
            },
            onPlay: (index: number): void => {
              const track = this.d().tracks[index];
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
                Player.playQueue(this.d().tracks, index);
              }
            },
            onMore: (track: Track): void => {
              this.actions.openTrack(track);
            },
          })

          if (this.selectionMode) {
            SelectionActionBar({
              busy: this.listBusy,
              count: this.selectedIds.size,
              actions: standardSelectionActions(
                (): void => this.actions.openPicker(Array.from(this.selectedIds)),
                (): void => this.enqueueTracks(Array.from(this.selectedIds)),
                (): void => this.removeTracks(Array.from(this.selectedIds)),
              ),
            })
          }

          TrackActionsHost({
            controller: this.actions,
            excludePlaylistId: this.playlistId,
            hasRemove: true,
            onRemoveFromPlaylist: (track: Track): void => {
              this.removeTracks([track.id]);
            },
            onPicked: (): void => this.exitSelection(),
          })
        }
        .width('100%')
        .height('100%')
      }

      if (this.showMore) {
        PlaylistActionsSheet({
          onRename: (): void => {
            this.showMore = false;
            this.actionError = '';
            this.showRename = true;
          },
          onDelete: (): void => {
            this.showMore = false;
            this.actionError = '';
            this.showDelete = true;
          },
          onDismiss: (): void => {
            this.showMore = false;
          },
        })
      }

      if (this.showRename) {
        PlaylistNameSheet({
          title: '重命名歌单',
          initialName: this.detail() !== null ? this.d().name : '',
          confirmText: '保存',
          busy: this.actionBusy,
          error: this.actionError,
          onDismiss: (): void => {
            if (!this.actionBusy) {
              this.showRename = false;
              this.actionError = '';
            }
          },
          onConfirm: (name: string): void => {
            this.actionBusy = true;
            this.actionError = '';
            this.vm.rename(name, (error: string | null): void => {
              this.actionBusy = false;
              if (error === null) {
                this.showRename = false;
              } else {
                this.actionError = error;
              }
            });
          },
        })
      }

      if (this.showDelete) {
        DeletePlaylistSheet({
          name: this.detail() !== null ? this.d().name : '',
          busy: this.actionBusy,
          error: this.actionError,
          onDismiss: (): void => {
            if (!this.actionBusy) {
              this.showDelete = false;
              this.actionError = '';
            }
          },
          onConfirm: (): void => {
            this.actionBusy = true;
            this.actionError = '';
            this.vm.delete((error: string | null): void => {
              this.actionBusy = false;
              if (error === null) {
                AppNav.pop();
              } else {
                this.actionError = error;
              }
            });
          },
        })
      }

      SecondaryTitleBar({ title: '歌单', bar: this.bar })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.ink.canvas)
  }

  @Builder
  headerItems(detail: PlaylistDetail) {
    Column({ space: 0 }) {
      // 封面大图
      Stack({ alignContent: Alignment.BottomStart }) {
        if (this.d().coverUrl.length > 0) {
          Image(Session.mediaUrl(this.d().coverUrl))
            .objectFit(ImageFit.Cover)
            .draggable(false)
            .width('100%')
            .height('100%')
        } else {
          Column()
            .width('100%')
            .height('100%')
            .linearGradient({ angle: 135, colors: [[Theme.ink.raised, 0], [Theme.ink.canvas, 1]] })
        }
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
          InkText({
            text: this.d().name,
            style: Typo.displaySmall,
            color: WHITE,
            lines: 2,
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
            Kicker({ text: L10n.fmt('fmt_songs_count', [this.d().tracks.length]) })
            Row().height(4)
            InkText({
              text: this.selectionMode ? '点击歌曲进行选择' : '长按歌曲可拖动排序',
              style: Typo.bodySmall,
              color: Theme.ink.inkMuted,
            })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          PlayAllControl({
            label: '播放全部',
            onTap: (): void => {
              if (this.d().tracks.length > 0) {
                Player.playQueue(this.d().tracks, 0);
              }
            },
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

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
