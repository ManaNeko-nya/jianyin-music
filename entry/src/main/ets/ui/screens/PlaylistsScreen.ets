import { Session } from '../../data/Session';
import { MusicRepository } from '../../data/MusicRepository';
import { Playlist } from '../../data/Models';
import { Player } from '../../playback/PlayerEngine';
import { Theme, Typo, withAlpha, TRANSPARENT, InkPalette } from '../Theme';
import {
  InkText, Kicker, Artwork, Hairline, RoundIconButton, PageHeader,
  LoadingBox, ErrorBox, EmptyBox, LoginPrompt,
  LoadState, Loading, Success, LoadError,
} from '../Components';
import { InkGlyph } from '../Icons';
import { AppUI } from '../AppState';
import { AppNav } from '../AppNav';
import { L10n } from '../../data/L10n';
import { PlaylistsViewModel, PlaylistViewModel } from '../ScreenViewModels';
import {
  SelectionActionBar, SelectionAction, TrackActionsController, TrackActionsHost,
  PlaylistNameSheet, DeletePlaylistSheet, PlaylistActionsSheet,
} from './TrackActions';

/** LazyForEach 数据源：歌单列表 + 拖拽移动通知。 */
class PlaylistSource implements IDataSource {
  private listeners: DataChangeListener[] = [];
  items: Playlist[] = [];
  moved: boolean = false;

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): Playlist {
    return this.items[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    this.listeners.push(listener);
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    this.listeners = this.listeners.filter((l): boolean => l !== listener);
  }

  reload(items: Playlist[]): void {
    // 必须持有副本：否则 move() 会就地改掉视图模型里的数组。
    this.items = items.slice();
    this.moved = false;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }

  snapshot(): Playlist[] {
    return this.items.slice();
  }

  move(from: number, to: number): void {
    if (from < 0 || from >= this.items.length || to < 0 || to >= this.items.length) {
      return;
    }
    const item = this.items[from];
    this.items.splice(from, 1);
    this.items.splice(to, 0, item);
    this.moved = true;
    // onMove 时框架已经移动了 ListItem，这里只同步数据；再发 onDataMove 会被移动第二次。
  }

  sameOrderAs(items: Playlist[]): boolean {
    if (this.items.length !== items.length) {
      return false;
    }
    for (let i = 0; i < items.length; i++) {
      if (this.items[i].id !== items[i].id) {
        return false;
      }
    }
    return true;
  }
}

@ComponentV2
export struct PlaylistsScreen {
  @Param dataVersion: number = 0;
  @Local vm: PlaylistsViewModel = new PlaylistsViewModel();
  @Local showCreate: boolean = false;
  @Local actionBusy: boolean = false;
  @Local actionError: string = '';
  private source: PlaylistSource = new PlaylistSource();

  aboutToAppear(): void {
    this.vm.load(true);
  }

  @Monitor('dataVersion')
  onSessionChanged(): void {
    this.source.reload([]);
    this.vm = new PlaylistsViewModel();
    this.vm.load(true);
  }

  @Monitor('vm.state')
  onStateChange(): void {
    const state = this.vm.state;
    if (state instanceof Success) {
      const items = (state as Success<Playlist[]>).data;
      if (!this.source.sameOrderAs(items)) {
        this.source.reload(items);
      }
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: 0 }) {
        PageHeader({
          title: '歌单',
          trailing: (): void => {
            this.headerTrailing()
          },
        })

        Column({ space: 0 }) {
          if (!Session.loggedIn) {
            LoginPrompt({
              onLogin: (): void => AppNav.openProfileTab(),
            })
          } else if (this.vm.state instanceof Loading) {
            LoadingBox()
          } else if (this.vm.state instanceof LoadError) {
            ErrorBox({
              message: (this.vm.state as LoadError<Playlist[]>).message,
              onRetry: (): void => this.vm.load(),
            })
          } else if (this.vm.state instanceof Success) {
            if ((this.vm.state as Success<Playlist[]>).data.length === 0) {
              EmptyBox({ title: '还没有歌单', subtitle: '点击右上角加号创建你的第一个歌单' })
            } else {
              this.playlistList()
            }
          }
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')

      if (this.showCreate) {
        PlaylistNameSheet({
          title: '新建歌单',
          initialName: '',
          confirmText: '创建',
          busy: this.actionBusy,
          error: this.actionError,
          onDismiss: (): void => {
            if (!this.actionBusy) {
              this.showCreate = false;
              this.actionError = '';
            }
          },
          onConfirm: (name: string): void => {
            this.actionBusy = true;
            this.actionError = '';
            this.vm.create(name, (error: string | null): void => {
              this.actionBusy = false;
              if (error === null) {
                this.showCreate = false;
              } else {
                this.actionError = error;
              }
            });
          },
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  headerTrailing() {
    if (Session.loggedIn) {
      RoundIconButton({
        icon: 'add',
        desc: '新建歌单',
        onTap: (): void => {
          this.actionError = '';
          this.showCreate = true;
        },
      })
    }
  }

  @Builder
  playlistList() {
    List({ space: 0 }) {
      ListItem() {
        Column({ space: 0 }) {
          Kicker({
            text: L10n.fmt('fmt_playlists_count', [this.source.items.length]) +
              (MusicRepository.capabilities.playlistReorder ? ' · ' + L10n.tr('长按可排序') : ''),
          })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 8, bottom: 8 })
        .alignItems(HorizontalAlign.Start)
      }

      if (MusicRepository.capabilities.playlistReorder) {
        LazyForEach(this.source, (item: Playlist) => {
          ListItem() {
            this.playlistItem(item)
          }
        }, (item: Playlist) => item.id.toString())
          .onMove((from: number, to: number): void => {
            this.source.move(from, to);
          }, {
            onDrop: (_index: number): void => {
              setTimeout((): void => {
                if (!this.source.moved) {
                  return;
                }
                this.source.moved = false;
                const snapshot = this.source.snapshot();
                this.vm.applyOrder(snapshot);
                this.vm.saveOrder((error: string | null): void => {
                  if (error !== null) {
                    AppUI.toast(error);
                  }
                });
              }, 350);
            },
          })
      } else {
        LazyForEach(this.source, (item: Playlist) => {
          ListItem() {
            this.playlistItem(item)
          }
        }, (item: Playlist) => item.id.toString())
      }

      ListItem() {
        Column().width('100%').height(24 + AppNav.floatClearance)
      }
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  @Builder
  playlistItem(item: Playlist) {
    Column({ space: 0 }) {
      PlaylistRow({
        playlist: item,
        onOpen: (): void => AppNav.openPlaylist(item.id),
      })
      Hairline()
    }
    .width('100%')
  }
}

@ComponentV2
struct PlaylistRow {
  @Param playlist: Playlist = new Playlist(0, '', 0, '');
  @Event onOpen: () => void = () => {
  };

  build() {
    Row({ space: 0 }) {
      Stack() {
        Artwork({ url: this.playlist.coverUrl, desc: this.playlist.name, corner: 9 })
      }
      .width(72)
      .height(72)
      Row().width(15).height(1)
      Column({ space: 0 }) {
        InkText({
          text: this.playlist.name,
          style: Typo.titleLarge,
          color: Theme.ink.ink,
          lines: 1,
        })
        Row().height(4)
        InkText({
          text: L10n.fmt('fmt_songs_count', [this.playlist.count]),
          style: Typo.bodySmall,
          color: Theme.ink.inkMuted,
        })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      InkGlyph({
        name: 'chevronRight',
        boxSize: 20,
        color: withAlpha(Theme.ink.inkMuted, 0.7),
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 20, right: 20, top: 12, bottom: 12 })
    .onClick((): void => this.onOpen())
  }
}
