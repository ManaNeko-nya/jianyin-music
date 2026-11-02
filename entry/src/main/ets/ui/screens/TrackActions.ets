import { Track, Playlist } from '../../data/Models';
import { MusicRepository } from '../../data/MusicRepository';
import { L10n } from '../../data/L10n';
import { Session } from '../../data/Session';
import { Player } from '../../playback/PlayerEngine';
import { Typo, Theme, withAlpha } from '../Theme';
import {
  InkText, Kicker, Artwork, Hairline, InkButton, TextAction, UnderlinedField,
  TinySpinner, RoundIconButton, AppTopBar, formatDuration,
} from '../Components';
import { InkGlyph, IconName } from '../Icons';
import { AppModalSheet } from '../AppModalSheet';
import { AppUI, BottomBar, AppMetrics } from '../AppState';
import { AppNav } from '../AppNav';
import { ArtistLinks } from '../ArtistLinks';

export class SelectionAction {
  readonly label: string;
  readonly icon: IconName;
  readonly danger: boolean;
  readonly onTap: () => void;

  constructor(label: string, icon: IconName, onTap: () => void, danger: boolean = false) {
    this.label = label;
    this.icon = icon;
    this.danger = danger;
    this.onTap = onTap;
  }
}

/**
 * 多选动作集合：任何页面都提供「添加到歌单 + 加入播放列表」，
 * 只有在歌单内部才额外给出「移出该歌单」。
 */
export function standardSelectionActions(onPick: () => void, onEnqueue: () => void,
  onRemove?: () => void): SelectionAction[] {
  const list: SelectionAction[] = [];
  if (onRemove !== undefined) {
    list.push(new SelectionAction('移出歌单', 'delete', onRemove, true));
  }
  if (Session.user !== null) {
    list.push(new SelectionAction('添加到歌单', 'playlistAdd', onPick));
  }
  list.push(new SelectionAction('加入播放列表', 'playlistPlay', onEnqueue));
  return list;
}

/** 多选状态下优先于迷你播放器与底部分页栏的操作栏。 */
@ComponentV2
export struct SelectionActionBar {
  @Param actions: SelectionAction[] = [];
  @Param busy: boolean = false;
  /** 选中数量：为 0 时整栏置灰不可点，避免"没选也能按"。 */
  @Param count: number = 0;

  aboutToDisappear(): void {
    BottomBar.height = 0;
  }

  build() {
    Column({ space: 0 }) {
      Hairline()
      Row({ space: 0 }) {
        ForEach(this.actions, (action: SelectionAction) => {
          this.actionCell(action)
        }, (action: SelectionAction) => action.label)
      }
      .width('100%')
      .padding({ left: 6, right: 6, top: 10, bottom: 10 })
      .alignItems(VerticalAlign.Center)
      .onAreaChange((_o: Area, n: Area) => {
        // 只上报内容高度：手势条让位由外层 padding 负责，否则迷你播放条会被多顶起一段。
        BottomBar.height = typeof n.height === 'number' ? n.height as number : 0;
      })
    }
    .width('100%')
    .backgroundColor(Theme.ink.raised)
    .padding({ bottom: AppNav.hasDetail ? AppMetrics.navBottom : 0 })
  }

  @Builder
  actionCell(action: SelectionAction) {
    Column({ space: 0 }) {
      InkGlyph({
        name: action.icon,
        boxSize: 22,
        color: this.colorFor(action, false),
      })
      Row().height(4)
      InkText({
        text: action.label,
        style: Typo.labelSmall,
        color: this.colorFor(action, true),
      })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(12)
    .padding({ top: 4, bottom: 4 })
    .opacity(this.actionsEnabled() ? 1 : 0.45)
    .onClick((event?: ClickEvent) => {
      if (this.actionsEnabled()) {
        action.onTap();
      }
    })
  }

  private actionsEnabled(): boolean {
    return this.count > 0 && !this.busy;
  }

  private colorFor(action: SelectionAction, isText: boolean): string {
    const ink = Theme.ink;
    if (!this.actionsEnabled()) {
      return withAlpha(ink.inkMuted, 0.35);
    }
    if (action.danger) {
      return ink.danger;
    }
    return isText ? ink.inkSoft : ink.ink;
  }
}

/** 底部弹窗内的通用操作行。 */
@ComponentV2
export struct SheetActionRow {
  @Param icon: IconName = 'musicNote';
  @Param title: string = '';
  @Param danger: boolean = false;
  @Event onTap: () => void = () => {
  };

  build() {
    Row({ space: 0 }) {
      InkGlyph({
        name: this.icon,
        boxSize: 20,
        color: this.danger ? Theme.ink.danger : Theme.ink.inkMuted,
      })
      Row().width(13).height(1)
      InkText({
        text: this.title,
        style: Typo.titleSmall,
        color: this.danger ? Theme.ink.danger : Theme.ink.ink,
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ top: 13, bottom: 13 })
    .onClick(() => this.onTap())
  }
}

/** 选择要加入的目标歌单。 */
@ComponentV2
export struct PlaylistPickerSheet {
  @Param title: string = '';
  @Param excludeId: number = -1;
  @Event onDismiss: () => void = () => {
  };
  @Event onPick: (playlist: Playlist) => void = (_p: Playlist) => {
  };

  @Local loading: boolean = true;
  @Local error: string = '';
  @Local playlists: Playlist[] = [];

  aboutToAppear(): void {
    MusicRepository.playlists().then((all: Playlist[]): void => {
      this.playlists = all.filter((p: Playlist): boolean => p.id !== this.excludeId);
      this.loading = false;
    }).catch((err: Object): void => {
      this.error = err instanceof Error && err.message.length > 0 ? err.message : '加载歌单失败';
      this.loading = false;
    });
  }

  build() {
    AppModalSheet({
      onDismissRequest: () => this.onDismiss(),
      title: this.title,
    }) {
      Column({ space: 0 }) {
        if (this.loading) {
          Row() {
            TinySpinner({ color: Theme.ink.accent, boxSize: 16 })
          }
          .width('100%')
          .height(64)
          .justifyContent(FlexAlign.Center)
        } else if (this.error.length > 0) {
          InkText({ text: this.error, style: Typo.bodySmall, color: Theme.ink.danger })
        } else if (this.playlists.length === 0) {
          InkText({
            text: '没有其他歌单，请先在歌单页创建。',
            style: Typo.bodyMedium,
            color: Theme.ink.inkMuted,
          })
            .padding({ top: 10, bottom: 10 })
        } else {
          List({ space: 0 }) {
            ForEach(this.playlists, (playlist: Playlist) => {
              ListItem() {
                Column({ space: 0 }) {
                  Row({ space: 0 }) {
                    Stack() {
                      Artwork({ url: playlist.coverUrl, desc: playlist.name, corner: 7 })
                    }
                    .width(40)
                    .height(40)
                    Row().width(12).height(1)
                    Column({ space: 0 }) {
                      InkText({
                        text: playlist.name,
                        style: Typo.titleSmall,
                        color: Theme.ink.ink,
                        lines: 1,
                      })
                      InkText({
                        text: L10n.fmt('fmt_songs_count', [playlist.count]),
                        style: Typo.bodySmall,
                        color: Theme.ink.inkMuted,
                      })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Center)
                  .padding({ top: 10, bottom: 10 })
                  .onClick(() => this.onPick(playlist))
                  Hairline()
                }
                .width('100%')
              }
            }, (playlist: Playlist) => playlist.id.toString())
          }
          .width('100%')
          .height(Math.min(this.playlists.length * 61 + 1, 360))
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 18 })
    }
  }
}

/** 歌曲详情与操作。 */
@ComponentV2
export struct TrackMoreSheet {
  @Param track: Track = new Track(0, 0, '', 0, '', '', '', '', 0, 0, false, 0);
  @Param hasRemove: boolean = false;
  @Event onRemoveFromPlaylist: () => void = () => {
  };
  @Event onAddToPlaylist: () => void = () => {
  };
  @Event onEnqueue: () => void = () => {
  };
  @Event onDismiss: () => void = () => {
  };
  @Event onOpenArtist: (artistId: number) => void = (_artistId: number) => {
  };

  build() {
    AppModalSheet({
      onDismissRequest: () => this.onDismiss(),
      title: this.track.title,
    }) {
      Column({ space: 0 }) {
        ArtistLinks({
          artists: this.track.artists,
          fallbackId: this.track.primaryArtistId,
          fallbackName: this.track.artistLabel,
          onOpenArtist: (artistId: number): void => this.onOpenArtist(artistId),
        })
        this.infoRow('专辑', this.track.albumTitle.length > 0 ? this.track.albumTitle : '未知专辑')
        this.infoRow('时长', formatDuration(this.track.durationMs))
        Row().height(10)
        Hairline()
        if (this.hasRemove) {
          SheetActionRow({
            icon: 'delete',
            title: '从该歌单移出',
            danger: true,
            onTap: () => this.onRemoveFromPlaylist(),
          })
          Hairline()
        }
        if (Session.user !== null) {
          SheetActionRow({
            icon: 'playlistAdd',
            title: '添加到其他歌单',
            onTap: () => this.onAddToPlaylist(),
          })
          Hairline()
        }
        SheetActionRow({
          icon: 'playlistPlay',
          title: '加入播放列表',
          onTap: () => this.onEnqueue(),
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 18 })
    }
  }

  @Builder
  infoRow(label: string, value: string) {
    Row({ space: 0 }) {
      InkText({ text: label, style: Typo.bodySmall, color: Theme.ink.inkMuted })
        .width(48)
      InkText({ text: value, style: Typo.bodyMedium, color: Theme.ink.inkSoft, lines: 1 })
    }
    .width('100%')
    .padding({ top: 3, bottom: 3 })
  }
}

/** 新建 / 重命名歌单。 */
@ComponentV2
export struct PlaylistNameSheet {
  @Param title: string = '';
  @Param initialName: string = '';
  @Param confirmText: string = '';
  @Param busy: boolean = false;
  @Param error: string = '';
  @Event onDismiss: () => void = () => {
  };
  @Event onConfirm: (name: string) => void = (_n: string) => {
  };

  @Local name: string = '';

  aboutToAppear(): void {
    this.name = this.initialName;
  }

  build() {
    AppModalSheet({
      onDismissRequest: () => this.onDismiss(),
      sheetHost: true,
      title: this.title,
      dismissEnabled: !this.busy,
    }) {
      Column({ space: 0 }) {
        UnderlinedField({
          value: this.name,
          onValueChange: (v: string): void => {
            this.name = v;
          },
          label: '歌单名称',
          placeholder: '给歌单起个名字',
          enterKey: EnterKeyType.Done,
          onImeAction: (): void => {
            if (this.name.trim().length > 0 && !this.busy) {
              this.onConfirm(this.name.trim());
            }
          },
        })
        if (this.error.length > 0) {
          Row().height(10)
          InkText({ text: this.error, style: Typo.bodySmall, color: Theme.ink.danger })
        }
        Row().height(20)
        Row({ space: 0 }) {
          Blank()
          TextAction({
            text: '取消',
            onTap: (): void => {
              if (!this.busy) {
                this.onDismiss();
              }
            },
            color: Theme.ink.inkMuted,
            showIcon: false,
          })
          Row().width(8).height(1)
          InkButton({
            text: this.confirmText,
            onTap: (): void => this.onConfirm(this.name.trim()),
            isEnabled: this.name.trim().length > 0 && !this.busy,
            loading: this.busy,
          })
            .width(124)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 20 })
    }
  }
}

/** 删除歌单确认。 */
@ComponentV2
export struct DeletePlaylistSheet {
  @Param name: string = '';
  @Param busy: boolean = false;
  @Param error: string = '';
  @Event onDismiss: () => void = () => {
  };
  @Event onConfirm: () => void = () => {
  };

  build() {
    AppModalSheet({
      onDismissRequest: () => this.onDismiss(),
      title: L10n.fmt('fmt_delete_playlist', [this.name]),
      dismissEnabled: !this.busy,
    }) {
      Column({ space: 0 }) {
        InkText({
          text: '歌单会被删除，歌曲本身不会从音乐库移除。',
          style: Typo.bodyMedium,
          color: Theme.ink.inkMuted,
        })
        if (this.error.length > 0) {
          Row().height(10)
          InkText({ text: this.error, style: Typo.bodySmall, color: Theme.ink.danger })
        }
        Row().height(20)
        Row({ space: 0 }) {
          Blank()
          TextAction({
            text: '取消',
            onTap: (): void => {
              if (!this.busy) {
                this.onDismiss();
              }
            },
            color: Theme.ink.inkMuted,
            showIcon: false,
          })
          Row().width(10).height(1)
          InkButton({
            text: '删除',
            onTap: (): void => this.onConfirm(),
            isEnabled: !this.busy,
            loading: this.busy,
          })
            .width(110)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 20 })
    }
  }
}

/** 歌单右上角的操作弹窗。 */
@ComponentV2
export struct PlaylistActionsSheet {
  @Event onRename: () => void = () => {
  };
  @Event onDelete: () => void = () => {
  };
  @Event onDismiss: () => void = () => {
  };

  build() {
    AppModalSheet({
      onDismissRequest: () => this.onDismiss(),
      title: '歌单操作',
    }) {
      Column({ space: 0 }) {
        SheetActionRow({ icon: 'edit', title: '重命名歌单', onTap: () => this.onRename() })
        Hairline()
        SheetActionRow({
          icon: 'delete',
          title: '删除歌单',
          danger: true,
          onTap: () => this.onDelete(),
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 8 })
    }
  }
}

/**
 * 歌曲更多操作与「添加到歌单」的唯一状态容器。
 */
@ObservedV2
export class TrackActionsController {
  @Trace track: Track | null = null;
  @Trace pickerIds: number[] | null = null;
  @Trace busy: boolean = false;

  openTrack(track: Track): void {
    this.track = track;
  }

  openPicker(ids: number[]): void {
    this.pickerIds = ids;
  }
}

/**
 * 全应用唯一的歌曲操作弹窗宿主：歌曲详情、加入播放列表、添加到歌单。
 */
@ComponentV2
export struct TrackActionsHost {
  @Param controller: TrackActionsController = new TrackActionsController();
  @Param excludePlaylistId: number = -1;
  @Param hasRemove: boolean = false;
  @Event onRemoveFromPlaylist: (track: Track) => void = (_t: Track) => {
  };
  @Event onPicked: () => void = () => {
  };
  @Event onNavigate: () => void = () => {
  };

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.controller.track !== null) {
        TrackMoreSheet({
          track: this.controller.track,
          hasRemove: this.hasRemove,
          onRemoveFromPlaylist: (): void => {
            const t = this.controller.track;
            this.controller.track = null;
            if (t !== null) {
              this.onRemoveFromPlaylist(t);
            }
          },
          onAddToPlaylist: (): void => {
            const t = this.controller.track;
            this.controller.track = null;
            if (t !== null) {
              this.controller.pickerIds = [t.id];
            }
          },
          onEnqueue: (): void => {
            const t = this.controller.track;
            this.controller.track = null;
            if (t !== null) {
              Player.enqueue([t]);
              AppUI.toast('已加入播放列表');
            }
          },
          onOpenArtist: (artistId: number): void => {
            this.onNavigate();
            this.controller.track = null;
            AppNav.openArtist(artistId);
          },
          onDismiss: (): void => {
            this.controller.track = null;
          },
        })
      }
      if (this.controller.pickerIds !== null) {
        PlaylistPickerSheet({
          title: (this.controller.pickerIds as number[]).length === 1
            ? '添加到其他歌单'
            : L10n.fmt('fmt_add_tracks', [(this.controller.pickerIds as number[]).length]),
          excludeId: this.excludePlaylistId,
          onDismiss: (): void => {
            if (!this.controller.busy) {
              this.controller.pickerIds = null;
            }
          },
          onPick: (target: Playlist): void => {
            const ids = this.controller.pickerIds;
            if (ids === null || this.controller.busy) {
              return;
            }
            this.controller.busy = true;
            MusicRepository.addTracksToPlaylist(target.id, ids).then((): void => {
              AppUI.toast(L10n.fmt('fmt_added_to_playlist', [target.name]));
              this.onPicked();
            }).catch((err: Object): void => {
              AppUI.toast(err instanceof Error && err.message.length > 0 ? err.message : '加入歌单失败');
            }).finally((): void => {
              this.controller.busy = false;
              this.controller.pickerIds = null;
            });
          },
        })
      }
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
  }
}
