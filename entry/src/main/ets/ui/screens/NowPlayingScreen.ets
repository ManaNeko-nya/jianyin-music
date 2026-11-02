import { Session } from '../../data/Session';
import { CommentItem, Track } from '../../data/Models';
import { Player, PlayerState } from '../../playback/PlayerEngine';
import { LyricLine } from '../../data/Lyrics';
import { Theme, Typo, withAlpha, TRANSPARENT, WHITE, InkPalette } from '../Theme';
import { IS_ANDROID } from '../../platform/BridgeClient';
import {
  InkText, Artwork, RoundIconButton, TinySpinner, EqualizerBars, formatDuration,
  AppTopBar,
} from '../Components';
import { InkGlyph, IconName } from '../Icons';
import { AppModalSheet, SheetController } from '../AppModalSheet';
import { AppUI, Backs, AppMetrics } from '../AppState';
import { AppNav } from '../AppNav';
import { PlayMode, playModeLabel } from '../../data/AppSettings';
import { MusicRepository } from '../../data/MusicRepository';
import { L10n } from '../../data/L10n';
import { SongExtrasViewModel, CommentsUiState } from '../ScreenViewModels';
import { TrackActionsController, TrackActionsHost } from './TrackActions';
import { ArtistLinks } from '../ArtistLinks';

type PlayerSheetKind = 'queue' | 'comments' | 'more' | 'speed';

function playModeIcon(mode: PlayMode): string {
  switch (mode) {
    case PlayMode.LoopList:
      return 'loopList';
    case PlayMode.LoopOne:
      return 'loopOne';
    case PlayMode.Shuffle:
      return 'shuffle';
    default:
      return 'orderPlay';
  }
}

@ComponentV2
export struct NowPlayingScreen {
  @Param state: PlayerState = new PlayerState();
  @Param baseColor: string = '#FF14161B';
  @Event onClose: () => void = () => {
  };
  @Event onCollapseDragStart: () => void = () => {
  };
  @Event onCollapseDrag: (fraction: number) => void = (_f: number) => {
  };
  @Event onCollapseDragEnd: () => void = () => {
  };

  @Local extras: SongExtrasViewModel = new SongExtrasViewModel();
  @Local trackActions: TrackActionsController = new TrackActionsController();
  @Local sheet: PlayerSheetKind | null = null;
  @Local dragMs: number = -1;
  @Local commentDraft: string = '';
  @Local pageIndex: number = 0;
  private moreSheet: SheetController = new SheetController();
  private trackId: number = -1;
  private backHandler: () => boolean = (): boolean => false;

  private deep(): string {
    return lerpHex(this.baseColor, '#FF000000', 0.55);
  }

  /** 当前歌曲（MusicRoot 已保证非空）。 */
  private t(): Track {
    return this.state.track as Track;
  }

  aboutToAppear(): void {
    Theme.pushLightBars();
    this.syncTrack();
    this.backHandler = (): boolean => {
      if (this.sheet !== null) {
        this.sheet = null;
        return true;
      }
      if (this.pageIndex !== 0) {
        this.pageIndex = 0;
        return true;
      }
      this.onClose();
      return true;
    };
    Backs.push(this.backHandler);
  }

  aboutToDisappear(): void {
    Theme.popLightBars();
    Backs.pop(this.backHandler);
  }

  private syncTrack(): void {
    const track = this.state.track;
    if (track === null) {
      return;
    }
    if (track.id !== this.trackId) {
      this.trackId = track.id;
      this.dragMs = -1;
      this.commentDraft = '';
      this.extras.ensureLyrics(track);
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.state.track === null) {
        Column().width('100%').height('100%')
      } else {
        this.playerContent()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.baseColor)
  }

  @Monitor('state.track')
  onTrackChanged(): void {
    this.syncTrack();
  }

  @Builder
  playerContent() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: 0 }) {
        TopPlayerBar({
          track: this.t(),
          onClose: (): void => this.onClose(),
          onMore: (): void => {
            this.sheet = 'more';
          },
          onCollapseDragStart: (): void => this.onCollapseDragStart(),
          onCollapseDrag: (f: number): void => this.onCollapseDrag(f),
          onCollapseDragEnd: (): void => this.onCollapseDragEnd(),
        })

        Stack({ alignContent: Alignment.TopStart }) {
          Swiper() {
            CoverPage({
              track: this.t(),
              base: this.baseColor,
              currentLine: this.currentLyricLine(),
              hasLyric: this.currentLyricLine().length > 0,
              onOpenLyrics: (): void => {
                this.pageIndex = 1;
              },
              onCollapseDragStart: (): void => this.onCollapseDragStart(),
              onCollapseDrag: (f: number): void => this.onCollapseDrag(f),
              onCollapseDragEnd: (): void => this.onCollapseDragEnd(),
            })
            LyricPage({
              track: this.t(),
              extras: this.extras,
              base: this.baseColor,
              positionMs: this.displayPosition(),
              onSeek: (ms: number): void => {
                Player.seekTo(ms);
              },
            })
          }
          .index(this.pageIndex)
          .indicator(false)
          .loop(false)
          .width('100%')
          .height('100%')
          .onChange((index: number) => {
            this.pageIndex = index;
          })
        }
        .width('100%')
        .layoutWeight(1)

        ControlBlock({
          state: this.state,
          base: this.baseColor,
          lyricActive: this.pageIndex === 1,
          dragMs: this.dragMs,
          onToggleLyrics: (): void => {
            const target = this.pageIndex === 0 ? 1 : 0;
            this.pageIndex = target;
          },
          onOpenComments: (): void => {
            this.sheet = 'comments';
            this.extras.loadComments(this.t().id, true);
          },
          onOpenQueue: (): void => {
            this.sheet = 'queue';
          },
          onOpenSpeed: (): void => {
            this.sheet = 'speed';
          },
          onDrag: (ms: number): void => {
            this.dragMs = ms;
          },
          onDragFinished: (ms: number): void => {
            this.dragMs = -1;
            Player.seekTo(ms);
          },
        })
      }
      .width('100%')
      .height('100%')

      if (this.sheet === 'queue') {
        AppModalSheet({
          onDismissRequest: (): void => {
            if (this.sheet === 'queue') {
              this.sheet = null;
            }
          },
          title: '播放列表',
          hint: L10n.fmt('fmt_queue_count', [this.state.queue.length]),
          heightFraction: 0.84,
          containerColor: this.deep(),
          contentColor: WHITE,
          mutedColor: withAlpha(WHITE, 0.5),
          closeTint: withAlpha(WHITE, 0.8),
        }) {
          QueueList({
            state: this.state,
            onPlay: (index: number): void => {
              Player.playAt(index);
              this.sheet = null;
            },
          })
        }
      }

      if (this.sheet === 'comments') {
        AppModalSheet({
          onDismissRequest: (): void => {
            if (this.sheet === 'comments') {
              this.sheet = null;
            }
          },
          title: '评论',
          hint: (this.extras.comments.total > 0
            ? L10n.fmt('fmt_comments_count', [this.extras.comments.total]) : ''),
          heightFraction: 0.88,
          sheetHost: true,
          containerColor: this.deep(),
          contentColor: WHITE,
          mutedColor: withAlpha(WHITE, 0.5),
          closeTint: withAlpha(WHITE, 0.8),
        }) {
          CommentsPane({
            state: this.extras.comments,
            draft: this.commentDraft,
            onDraftChange: (v: string): void => {
              this.commentDraft = v;
            },
            onSend: (): void => {
              this.extras.postComment(this.t().id, this.commentDraft);
            },
            onLoadMore: (): void => {
              this.extras.loadComments(this.t().id, false);
            },
            onRetry: (): void => {
              this.extras.loadComments(this.t().id, true);
            },
          })
        }
      }

      if (this.sheet === 'speed') {
        AppModalSheet({
          onDismissRequest: (): void => {
            if (this.sheet === 'speed') {
              this.sheet = null;
            }
          },
          title: '播放速度',
          hint: formatSpeed(this.state.speed),
          heightFraction: 0.52,
          containerColor: this.deep(),
          contentColor: WHITE,
          mutedColor: withAlpha(WHITE, 0.5),
          closeTint: withAlpha(WHITE, 0.8),
        }) {
          SpeedPane({
            current: this.state.speed,
            onSelect: (value: number): void => {
              Player.setSpeed(value);
            },
          })
        }
      }

      if (this.sheet === 'more') {
        AppModalSheet({
          onDismissRequest: (): void => {
            if (this.sheet === 'more') {
              this.sheet = null;
            }
          },
          sheetHost: true,
          controller: this.moreSheet,
          title: '更多',
          heightFraction: 0.64,
          containerColor: this.deep(),
          contentColor: WHITE,
          mutedColor: withAlpha(WHITE, 0.5),
          closeTint: withAlpha(WHITE, 0.8),
        }) {
          MorePane({
            track: this.t(),
            state: this.state,
            onOpenAlbum: (): void => {
              this.moreSheet.close((): void => {
              });
              this.onClose();
              AppNavOpenAlbum(this.t().albumId);
            },
            onOpenArtist: (artistId: number): void => {
              this.moreSheet.close((): void => {
              });
              this.onClose();
              AppNavOpenArtist(artistId);
            },
            onOpenQueue: (): void => {
              this.sheet = 'queue';
            },
            onAddToPlaylist: (): void => {
              this.moreSheet.close((): void => {
                this.trackActions.openPicker([this.t().id]);
              });
            },
          })
        }
      }

      TrackActionsHost({
        controller: this.trackActions,
        onNavigate: (): void => this.onClose(),
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.baseColor)
  }

  private displayPosition(): number {
    return this.dragMs >= 0 ? this.dragMs : this.state.positionMs;
  }

  private currentLyricLine(): string {
    if (this.extras.lyrics.trackId !== this.trackId) {
      return '';
    }
    const pos = this.displayPosition();
    let text = '';
    for (const line of this.extras.lyrics.lines) {
      if (line.timeMs <= pos) {
        text = line.text;
      } else {
        break;
      }
    }
    return text;
  }
}

// ---- 顶部栏 ----

@ComponentV2
struct TopPlayerBar {
  @Param track: Track = new Track(0, 0, '', 0, '', '', '', '', 0, 0, false, 0);
  @Event onClose: () => void = () => {
  };
  @Event onMore: () => void = () => {
  };
  @Event onCollapseDragStart: () => void = () => {
  };
  @Event onCollapseDrag: (fraction: number) => void = (_f: number) => {
  };
  @Event onCollapseDragEnd: () => void = () => {
  };

  private lastPanY: number = 0;

  build() {
    Row({ space: 0 }) {
      RoundIconButton({
        icon: 'chevronDown',
        desc: '收起',
        onTap: (): void => this.onClose(),
        tint: WHITE,
        bgColor: withAlpha(WHITE, 0.12),
        boxSize: 38,
        iconSize: 24,
      })
      Row().width(12).height(1)
      Column({ space: 0 }) {
        InkText({
          text: this.track.title,
          style: Typo.titleLarge,
          color: WHITE,
          weight: 700,
          lines: 1,
        })
        Row().height(2)
        InkText({
          text: subtitleOf(this.track),
          style: Typo.bodySmall,
          color: withAlpha(WHITE, 0.62),
          lines: 1,
        })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row().width(8).height(1)
      RoundIconButton({
        icon: 'moreHoriz',
        desc: '更多',
        onTap: (): void => this.onMore(),
        tint: withAlpha(WHITE, 0.9),
        bgColor: withAlpha(WHITE, 0.12),
        boxSize: 38,
        iconSize: 22,
      })
    }
    .width('100%')
    .height(64 + AppTopBar.topPad)
    .padding({ left: 8, right: 8, top: AppTopBar.topPad })
    .alignItems(VerticalAlign.Center)
    .gesture(PanGesture({ fingers: 1, direction: PanDirection.Vertical, distance: 5 })
      .onActionStart((_e: GestureEvent): void => {
        this.lastPanY = 0;
        this.onCollapseDragStart();
      })
      .onActionUpdate((e: GestureEvent): void => {
        const dy = e.offsetY - this.lastPanY;
        this.lastPanY = e.offsetY;
        this.onCollapseDrag(dy / AppTopBar.screenHeight);
      })
      .onActionEnd((): void => {
        this.onCollapseDragEnd();
      }))
  }
}

// ---- 封面页 ----

@ComponentV2
struct CoverPage {
  @Param track: Track = new Track(0, 0, '', 0, '', '', '', '', 0, 0, false, 0);
  @Param base: string = '#FF14161B';
  @Param currentLine: string = '';
  @Param hasLyric: boolean = false;
  @Event onOpenLyrics: () => void = () => {
  };
  @Event onCollapseDragStart: () => void = () => {
  };
  @Event onCollapseDrag: (fraction: number) => void = (_f: number) => {
  };
  @Event onCollapseDragEnd: () => void = () => {
  };

  private lastPanY: number = 0;

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: 0 }) {
        Image(Session.mediaUrl(this.track.coverUrl))
          .objectFit(ImageFit.Cover)
          .draggable(false)
          .width('100%')
          .height('100%')
      }
      .width('100%')
      .height('100%')

      Column()
        .width('100%')
        .height('100%')
        .position({ x: 0, y: 0 })
        .linearGradient({
          angle: 180,
          colors: [
            [this.base, 0],
            [withAlpha(this.base, 0.72), 0.16],
            [TRANSPARENT, 0.32],
            [TRANSPARENT, 0.62],
            [withAlpha(this.base, 0.72), 0.82],
            [this.base, 1],
          ],
        })

      Column({ space: 0 }) {
        if (this.hasLyric && this.currentLine.length > 0) {
          InkText({
            text: this.currentLine,
            style: Typo.titleMedium,
            color: withAlpha(WHITE, 0.92),
            alignTo: TextAlign.Center,
            lines: 2,
          })
            .borderRadius(10)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .onClick(() => this.onOpenLyrics())
        } else {
          InkText({
            text: '左右滑动查看歌词',
            style: Typo.labelMedium,
            color: withAlpha(WHITE, 0.45),
          })
        }
      }
      .width('100%')
      .padding({ left: 28, right: 28, top: 24, bottom: 24 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .gesture(PanGesture({ fingers: 1, direction: PanDirection.Vertical, distance: 5 })
      .onActionStart((_e: GestureEvent): void => {
        this.lastPanY = 0;
        this.onCollapseDragStart();
      })
      .onActionUpdate((e: GestureEvent): void => {
        const dy = e.offsetY - this.lastPanY;
        this.lastPanY = e.offsetY;
        this.onCollapseDrag(dy / AppTopBar.screenHeight);
      })
      .onActionEnd((): void => {
        this.onCollapseDragEnd();
      }))
  }
}

// ---- 歌词页 ----

@ComponentV2
struct LyricPage {
  @Param track: Track = new Track(0, 0, '', 0, '', '', '', '', 0, 0, false, 0);
  @Param extras: SongExtrasViewModel = new SongExtrasViewModel();
  @Param base: string = '#FF14161B';
  @Param positionMs: number = 0;
  @Event onSeek: (ms: number) => void = (_ms: number) => {
  };
  private scroller: Scroller = new Scroller();
  private userScrolling: boolean = false;
  /**
   * 当前高亮行：只在"换行"时更新。
   * 若在每一行里直接比较 positionMs，进度每 100ms 一变就会让整张歌词表全部重绘（页面很卡）。
   */
  @Local activeLine: number = -1;

  private lines(): LyricLine[] {
    if (this.extras.lyrics.trackId !== this.track.id) {
      return [];
    }
    return this.extras.lyrics.lines;
  }

  private activeIndex(): number {
    const lines = this.lines();
    let idx = -1;
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].timeMs <= this.positionMs) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }

  @Monitor('positionMs')
  onPositionChanged(): void {
    const active = this.activeIndex();
    if (active !== this.activeLine) {
      this.activeLine = active;
    }
    this.maybeAutoScroll();
  }

  private lyricLines(): LyricLine[] {
    return this.lines();
  }

  private isLoading(): boolean {
    return this.extras.lyrics.trackId === this.track.id && this.extras.lyrics.loading;
  }

  private hasError(): boolean {
    return this.extras.lyrics.trackId === this.track.id && this.extras.lyrics.error.length > 0;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.isLoading()) {
        TinySpinner({ color: withAlpha(WHITE, 0.8), boxSize: 22 })
      } else if (this.hasError()) {
        LyricMessage({
          title: '歌词加载失败',
          subtitle: this.extras.lyrics.error,
        })
      } else if (this.lyricLines().length === 0 && this.extras.lyrics.loaded &&
        this.extras.lyrics.trackId === this.track.id) {
        LyricMessage({ title: '暂无歌词', subtitle: '这首歌还没有上传 LRC 歌词' })
      } else if (this.lyricLines().length === 0) {
        TinySpinner({ color: withAlpha(WHITE, 0.6), boxSize: 20 })
      } else {
        List({ scroller: this.scroller, space: 0 }) {
          ListItem() {
            Column().width('100%').height(48)
          }
          ForEach(this.lyricLines(), (line: LyricLine, index?: number) => {
            ListItem() {
              Column() {
                InkText({
                  text: line.text,
                  style: index === this.activeLine ? Typo.titleLarge : Typo.bodyMedium,
                  color: index === this.activeLine ? WHITE : withAlpha(WHITE, 0.45),
                  weight: index === this.activeLine ? 700 : 400,
                  lines: 3,
                })
                  .width('100%')
                  .padding({ top: 8, bottom: 8 })
                  .onClick(() => this.onSeek(line.timeMs))
              }
              .width('100%')
            }
          }, (line: LyricLine) => `${line.timeMs}-${line.text}`)
          ListItem() {
            Column().width('100%').height(48)
          }
        }
        .width('100%')
        .height('100%')
        .padding({ left: 32, right: 32 })
        .scrollBar(BarState.Off)
        .onScrollStart(() => {
          this.userScrolling = true;
        })
        .onScrollStop(() => {
          this.userScrolling = false;
        })
      }

      Column()
        .width('100%')
        .height(46)
        .position({ x: 0, y: 0 })
        .linearGradient({
          angle: 180,
          colors: [[this.base, 0], [withAlpha(this.base, 0), 1]],
        })
      Column()
        .width('100%')
        .height(58)
        .position({ x: 0, y: '100%' })
        .markAnchor({ y: '100%' })
        .linearGradient({
          angle: 180,
          colors: [[withAlpha(this.base, 0), 0], [this.base, 1]],
        })
    }
    .width('100%')
    .height('100%')
  }

  private lastAutoScrollIndex: number = -1;

  private maybeAutoScroll(): void {
    const active = this.activeIndex();
    if (active < 0 || this.userScrolling) {
      return;
    }
    const target = Math.max(active - 2, 0);
    // 目标行没变就不要反复触发滚动动画，否则进度每跳一次都在重启动画。
    if (target === this.lastAutoScrollIndex) {
      return;
    }
    this.lastAutoScrollIndex = target;
    this.scroller.scrollToIndex(target, true);
  }
}

@ComponentV2
struct LyricMessage {
  @Param title: string = '';
  @Param subtitle: string = '';

  build() {
    Column({ space: 0 }) {
      InkText({ text: this.title, style: Typo.titleMedium, color: withAlpha(WHITE, 0.82) })
      Row().height(6)
      InkText({ text: this.subtitle, style: Typo.bodySmall, color: withAlpha(WHITE, 0.45) })
    }
    .alignItems(HorizontalAlign.Center)
  }
}

// ---- 控制区 ----

@ComponentV2
struct ControlBlock {
  @Param state: PlayerState = new PlayerState();
  @Param base: string = '#FF14161B';
  @Param lyricActive: boolean = false;
  @Param dragMs: number = -1;
  @Event onToggleLyrics: () => void = () => {
  };
  @Event onOpenComments: () => void = () => {
  };
  @Event onOpenQueue: () => void = () => {
  };
  @Event onOpenSpeed: () => void = () => {
  };
  @Event onDrag: (ms: number) => void = (_ms: number) => {
  };
  @Event onDragFinished: (ms: number) => void = (_ms: number) => {
  };

  build() {
    Column({ space: 0 }) {
      Row().height(10)
      PlayerSeekBar({
        positionMs: this.dragMs >= 0 ? this.dragMs : this.state.positionMs,
        durationMs: this.state.durationMs,
        onDrag: (ms: number): void => this.onDrag(ms),
        onFinished: (ms: number): void => this.onDragFinished(ms),
      })
      Row({ space: 0 }) {
        InkText({
          text: formatDuration(this.dragMs >= 0 ? this.dragMs : this.state.positionMs),
          style: Typo.labelMedium,
          color: withAlpha(WHITE, 0.55),
        })
        Blank()
        InkText({
          text: formatDuration(this.state.durationMs),
          style: Typo.labelMedium,
          color: withAlpha(WHITE, 0.55),
        })
      }
      .width('100%')

      Row().height(8)
      Row({ space: 0 }) {
        Blank()
        RoundIconButton({
          icon: 'previous',
          desc: '上一首',
          onTap: (): void => Player.previous(),
          tint: withAlpha(WHITE, 0.92),
          boxSize: 44,
          iconSize: 26,
        })
        Row().width(34).height(1)
        CenterPlayButton({
          isPlaying: this.state.isPlaying,
          onTap: (): void => Player.toggle(),
        })
        Row().width(34).height(1)
        RoundIconButton({
          icon: 'next',
          desc: '下一首',
          onTap: (): void => Player.next(),
          tint: withAlpha(WHITE, 0.92),
          boxSize: 44,
          iconSize: 26,
        })
        Blank()
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row().height(12)
      Row({ space: 0 }) {
        PlayerAction({
          icon: 'lyrics',
          label: '歌词',
          active: this.lyricActive,
          onTap: (): void => this.onToggleLyrics(),
        })
          .layoutWeight(1)
        if (MusicRepository.capabilities.comments && Session.user !== null) {
          PlayerAction({
            icon: 'chat',
            label: '评论',
            onTap: (): void => this.onOpenComments(),
          })
            .layoutWeight(1)
        }
        PlayerAction({
          icon: 'queue',
          label: '列表',
          onTap: (): void => this.onOpenQueue(),
        })
          .layoutWeight(1)
        PlayerAction({
          icon: 'speed',
          label: formatSpeed(this.state.speed),
          onTap: (): void => this.onOpenSpeed(),
        })
          .layoutWeight(1)
        PlayerAction({
          icon: playModeIcon(this.state.playMode),
          label: playModeLabel(this.state.playMode),
          onTap: (): void => Player.cyclePlayMode(),
        })
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row().height(10)
    }
    .width('100%')
    .backgroundColor(this.base)
    .padding({ left: 24, right: 24, bottom: AppMetrics.navBottom + 10 })
  }
}

@ComponentV2
struct PlayerAction {
  @Param icon: string = 'musicNote';
  @Param label: string = '';
  @Param active: boolean = false;
  @Event onTap: () => void = () => {
  };

  build() {
    Column({ space: 0 }) {
      InkGlyph({
        name: this.icon as IconName,
        boxSize: 21,
        color: this.active ? WHITE : withAlpha(WHITE, 0.58),
      })
      Row().height(4)
      InkText({
        text: this.label,
        style: Typo.labelSmall,
        color: this.active ? WHITE : withAlpha(WHITE, 0.58),
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .borderRadius(12)
    .padding({ top: 4, bottom: 4 })
    .onClick(() => this.onTap())
  }
}

@ComponentV2
struct CenterPlayButton {
  @Param isPlaying: boolean = false;
  @Event onTap: () => void = () => {
  };
  @Local pressed: boolean = false;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      InkGlyph({
        name: this.isPlaying ? 'pause' : 'play',
        boxSize: 34,
        color: WHITE,
      })
    }
    .width(72)
    .height(72)
    .borderRadius(36)
    .border({ width: 1, color: withAlpha(WHITE, 0.18) })
    .backgroundColor(withAlpha(WHITE, 0.14))
    .scale({
      x: this.pressed ? 0.93 : 1,
      y: this.pressed ? 0.93 : 1,
    })
    .animation({ duration: 120, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent): void => {
      if (event.type === TouchType.Down) {
        this.pressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
    .onClick((event?: ClickEvent): void => {
      this.onTap();
    })
  }
}

@ComponentV2
struct PlayerSeekBar {
  @Param positionMs: number = 0;
  @Param durationMs: number = 0;
  @Event onDrag: (ms: number) => void = (_ms: number) => {
  };
  @Event onFinished: (ms: number) => void = (_ms: number) => {
  };
  @Local private trackWidth: number = 0;

  private fraction(): number {
    const duration = Math.max(this.durationMs, 1);
    return Math.min(Math.max(this.positionMs / duration, 0), 1);
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Column()
        .width('100%')
        .height(2)
        .borderRadius(1)
        .backgroundColor(withAlpha(WHITE, 0.22))
      Column()
        .width(`${this.fraction() * 100}%`)
        .height(2)
        .borderRadius(1)
        .backgroundColor(withAlpha(WHITE, 0.92))
      Column()
        .width(11)
        .height(11)
        .borderRadius(5.5)
        .backgroundColor(WHITE)
        .markAnchor({ x: '50%', y: '50%' })
        .position({
          x: `${this.fraction() * 100}%`,
          y: '50%',
        })
    }
    .width('100%')
    .height(36)
    .onAreaChange((_o: Area, n: Area): void => {
      const w = n.width;
      this.trackWidth = typeof w === 'number' ? w as number : 0;
    })
    .onTouch((event: TouchEvent): void => {
      const duration = Math.max(this.durationMs, 1);
      const touch = event.changedTouches.length > 0
        ? event.changedTouches[0]
        : (event.touches.length > 0 ? event.touches[0] : undefined);
      if (touch === undefined || this.trackWidth <= 0) {
        return;
      }
      const value = Math.trunc(Math.min(Math.max(touch.x / this.trackWidth, 0), 1) * duration);
      if (event.type === TouchType.Down || event.type === TouchType.Move) {
        this.onDrag(value);
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.onFinished(value);
      }
    })
  }
}

// ---- 队列 ----

@ComponentV2
struct QueueList {
  @Param state: PlayerState = new PlayerState();
  @Event onPlay: (index: number) => void = (_i: number) => {
  };

  build() {
    List({ space: 0 }) {
      ListItem() {
        Column().width('100%').height(4)
      }
      ForEach(this.state.queue, (item: Track, index?: number) => {
        ListItem() {
          QueueTrackRow({
            track: item,
            index: index !== undefined ? index : 0,
            isCurrent: index === this.state.currentIndex,
            onTap: (): void => {
              if (index !== undefined) {
                this.onPlay(index);
              }
            },
          })
        }
      }, (item: Track) => `q-${item.id}`)
      ListItem() {
        Column().width('100%').height(12)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 12, right: 12 })
    .scrollBar(BarState.Off)
  }
}

@ComponentV2
struct QueueTrackRow {
  @Param track: Track = new Track(0, 0, '', 0, '', '', '', '', 0, 0, false, 0);
  @Param index: number = 0;
  @Param isCurrent: boolean = false;
  @Event onTap: () => void = () => {
  };

  build() {
    Row({ space: 0 }) {
      InkText({
        text: this.index < 9 ? `0${this.index + 1}` : String(this.index + 1),
        style: Typo.labelSmall,
        color: this.isCurrent ? withAlpha(WHITE, 0.9) : withAlpha(WHITE, 0.35),
      })
        .width(27)
      Stack() {
        Artwork({ url: this.track.coverUrl, desc: this.track.title, corner: 5 })
      }
      .width(42)
      .height(42)
      Row().width(12).height(1)
      Column({ space: 0 }) {
        InkText({
          text: this.track.title,
          style: Typo.titleSmall,
          color: this.isCurrent ? WHITE : withAlpha(WHITE, 0.9),
          lines: 1,
          weight: this.isCurrent ? 700 : 500,
        })
        InkText({
          text: this.track.artistLabel.length > 0 ? this.track.artistLabel : '未知艺人',
          style: Typo.bodySmall,
          color: withAlpha(WHITE, 0.48),
          lines: 1,
        })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.isCurrent) {
        EqualizerBars({ playing: true, color: withAlpha(WHITE, 0.9) })
          .width(14)
          .height(16)
        Row().width(8).height(1)
      }
      InkText({
        text: formatDuration(this.track.durationMs),
        style: Typo.labelMedium,
        color: withAlpha(WHITE, 0.42),
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.isCurrent ? withAlpha(WHITE, 0.08) : TRANSPARENT)
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .onClick(() => this.onTap())
  }
}

// ---- 评论 ----

@ComponentV2
struct CommentsPane {
  @Param state: CommentsUiState = new CommentsUiState();
  @Param draft: string = '';
  @Event onDraftChange: (v: string) => void = (_v: string) => {
  };
  @Event onSend: () => void = () => {
  };
  @Event onLoadMore: () => void = () => {
  };
  @Event onRetry: () => void = () => {
  };

  build() {
    Column({ space: 0 }) {
      if (this.state.loading) {
        Stack({ alignContent: Alignment.Center }) {
          TinySpinner({ color: withAlpha(WHITE, 0.8), boxSize: 22 })
        }
        .width('100%')
        .layoutWeight(1)
      } else if (this.state.error.length > 0 && this.state.items.length === 0) {
        Stack({ alignContent: Alignment.Center }) {
          Column({ space: 0 }) {
            InkText({ text: this.state.error, style: Typo.bodyMedium, color: withAlpha(WHITE, 0.65) })
            Row().height(10)
            InkText({ text: '重试', style: Typo.labelLarge, color: WHITE })
              .borderRadius(20)
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
              .onClick(() => this.onRetry())
          }
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
      } else if (this.state.items.length === 0) {
        Stack({ alignContent: Alignment.Center }) {
          Column({ space: 0 }) {
            InkText({ text: '还没有评论', style: Typo.titleMedium, color: withAlpha(WHITE, 0.82) })
            Row().height(6)
            InkText({
              text: '说说你听完这首歌的感受',
              style: Typo.bodySmall,
              color: withAlpha(WHITE, 0.45),
            })
          }
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        List({ space: 0 }) {
          ListItem() {
            Column().width('100%').height(6)
          }
          ForEach(this.state.items, (item: CommentItem) => {
            ListItem() {
              Column() {
                CommentRow({ comment: item })
              }
              .padding({ left: 24, right: 24 })
            }
          }, (item: CommentItem) => `c-${item.id}`)
          if (this.state.items.length < this.state.total) {
            ListItem() {
              InkText({
                text: this.state.loadingMore ? '加载中…' : '查看更多评论',
                style: Typo.labelLarge,
                color: withAlpha(WHITE, 0.6),
                alignTo: TextAlign.Center,
              })
                .width('100%')
                .padding({ top: 16, bottom: 16 })
                .onClick((): void => {
                  if (!this.state.loadingMore) {
                    this.onLoadMore();
                  }
                })
            }
          }
          ListItem() {
            Column().width('100%').height(12)
          }
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }

      if (this.state.error.length > 0 && this.state.items.length > 0) {
        InkText({
          text: this.state.error,
          style: Typo.bodySmall,
          color: '#FFFFB4AB',
        })
          .padding({ left: 24, right: 24, top: 4, bottom: 4 })
      }
      if (this.state.notice.length > 0) {
        InkText({
          text: this.state.notice,
          style: Typo.bodySmall,
          color: withAlpha(WHITE, 0.6),
        })
          .padding({ left: 24, right: 24, top: 4, bottom: 4 })
      }

      if (Session.user === null) {
        InkText({
          text: '登录后可以发表评论',
          style: Typo.bodySmall,
          color: withAlpha(WHITE, 0.5),
        })
          .padding({ left: 24, right: 24, top: 18, bottom: 18 })
      } else {
        Row({ space: 0 }) {
          TextInput({ text: this.draft, placeholder: L10n.tr('说点什么…') })
            .placeholderColor(withAlpha(WHITE, 0.35))
            .placeholderFont({ size: Typo.bodyMedium.size })
            .fontColor(WHITE)
            .fontSize(Typo.bodyMedium.size)
            .caretColor(WHITE)
            .backgroundColor(withAlpha(WHITE, 0.09))
            .borderRadius(18)
            .padding({ left: 16, right: 16, top: 11, bottom: 11 })
            .constraintSize({ maxHeight: 120 })
            .enterKeyType(EnterKeyType.Send)
            .layoutWeight(1)
            .onChange((v: string): void => this.onDraftChange(v))
            .onSubmit((_k: EnterKeyType, _e: SubmitEvent): void => {
              if (this.draft.trim().length > 0 && !this.state.posting) {
                this.onSend();
              }
            })

          Row().width(10).height(1)
          Stack({ alignContent: Alignment.Center }) {
            if (this.state.posting) {
              TinySpinner({ color: withAlpha(WHITE, 0.7), boxSize: 16 })
            } else {
              InkGlyph({
                name: 'send',
                boxSize: 18,
                color: this.draft.trim().length === 0 ? withAlpha(WHITE, 0.35) : '#FF14161B',
              })
            }
          }
          .width(42)
          .height(42)
          .borderRadius(21)
          .backgroundColor(this.draft.trim().length === 0 || this.state.posting
            ? withAlpha(WHITE, 0.1) : WHITE)
          .onClick((): void => {
            if (this.draft.trim().length > 0 && !this.state.posting) {
              AppUI.keyboardHide();
              this.onSend();
            }
          })
        }
        .width('100%')
        .padding({ left: 20, right: 14, top: 10, bottom: 12 })
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }
}

@ComponentV2
struct CommentRow {
  @Param comment: CommentItem = new CommentItem(0, null, '', '', '', '', []);

  build() {
    Row({ space: 0 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.comment.avatarUrl.length > 0) {
          Image(Session.mediaUrl(this.comment.avatarUrl))
            .objectFit(ImageFit.Cover)
            .draggable(false)
            .width('100%')
            .height('100%')
        } else {
          InkText({
            text: this.comment.author.trim().length > 0
              ? this.comment.author.trim().substring(0, 1) : '听',
            style: Typo.labelLarge,
            color: withAlpha(WHITE, 0.7),
          })
        }
      }
      .width(32)
      .height(32)
      .borderRadius(16)
      .backgroundColor(withAlpha(WHITE, 0.12))
      .clip(true)

      Row().width(11).height(1)
      Column({ space: 0 }) {
        Row({ space: 0 }) {
          InkText({
            text: this.comment.author,
            style: Typo.titleSmall,
            color: withAlpha(WHITE, 0.88),
            lines: 1,
          })
            .constraintSize({ maxWidth: '60%' })
          Row().width(8).height(1)
          InkText({
            text: formatCommentTime(this.comment.createdAt),
            style: Typo.labelSmall,
            color: withAlpha(WHITE, 0.32),
          })
        }
        .alignItems(VerticalAlign.Center)

        Row().height(4)
        InkText({
          text: this.comment.content,
          style: Typo.bodyMedium,
          color: withAlpha(WHITE, 0.82),
        })
        ForEach(this.comment.replies, (reply: CommentItem) => {
          Column({ space: 0 }) {
            InkText({
              text: reply.author,
              style: Typo.labelMedium,
              color: withAlpha(WHITE, 0.6),
            })
            Row().height(3)
            InkText({
              text: reply.content,
              style: Typo.bodySmall,
              color: withAlpha(WHITE, 0.72),
            })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .borderRadius(8)
          .backgroundColor(withAlpha(WHITE, 0.05))
          .padding({ left: 10, right: 10, top: 8, bottom: 8 })
          .margin({ top: 8 })
        }, (reply: CommentItem) => `r-${reply.id}`)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .alignItems(VerticalAlign.Top)
  }
}

// ---- 更多 ----

@ComponentV2
struct MorePane {
  @Param track: Track = new Track(0, 0, '', 0, '', '', '', '', 0, 0, false, 0);
  @Param state: PlayerState = new PlayerState();
  @Event onOpenAlbum: () => void = () => {
  };
  @Event onOpenArtist: (artistId: number) => void = (_artistId: number) => {
  };
  @Event onOpenQueue: () => void = () => {
  };
  @Event onAddToPlaylist: () => void = () => {
  };

  build() {
    Column({ space: 0 }) {
      Row({ space: 0 }) {
        Stack() {
          Artwork({ url: this.track.coverUrl, desc: this.track.title, corner: 8 })
        }
        .width(62)
        .height(62)
        Row().width(14).height(1)
        Column({ space: 0 }) {
          InkText({
            text: this.track.title,
            style: Typo.titleMedium,
            color: WHITE,
            lines: 1,
          })
          Row().height(3)
          InkText({
            text: this.track.artistLabel.length > 0 ? this.track.artistLabel : '未知艺人',
            style: Typo.bodySmall,
            color: withAlpha(WHITE, 0.55),
            lines: 1,
          })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row().height(16)
      SheetHairline()
      this.infoLine('专辑', this.track.albumTitle.length > 0 ? this.track.albumTitle : '未知专辑')
      this.infoLine('时长', formatDuration(this.state.durationMs > 0
        ? this.state.durationMs : this.track.durationMs))
      SheetHairline()
      Row().height(6)
      ArtistLinks({
        artists: this.track.artists,
        fallbackId: this.track.primaryArtistId,
        fallbackName: this.track.artistLabel,
        iconColor: withAlpha(WHITE, 0.7),
        chipColor: withAlpha(WHITE, 0.08),
        textColor: WHITE,
        onOpenArtist: (artistId: number): void => this.onOpenArtist(artistId),
      })

      MoreAction({
        icon: 'album',
        title: '查看专辑',
        subtitle: this.track.albumTitle.length > 0 ? this.track.albumTitle : '未知专辑',
        isEnabled: this.track.albumId > 0,
        onTap: (): void => this.onOpenAlbum(),
      })
      MoreAction({
        icon: 'playlistAdd',
        title: '添加到歌单',
        subtitle: '选择目标歌单',
        onTap: (): void => this.onAddToPlaylist(),
      })
      MoreAction({
        icon: 'queue',
        title: '播放列表',
        subtitle: L10n.fmt('fmt_songs_count', [this.state.queue.length]),
        onTap: (): void => this.onOpenQueue(),
      })
    }
    .width('100%')
    .padding({ left: 24, right: 24 })
  }

  @Builder
  infoLine(label: string, value: string) {
    Row({ space: 0 }) {
      InkText({
        text: label,
        style: Typo.labelMedium,
        color: withAlpha(WHITE, 0.4),
      })
        .width(54)
      InkText({
        text: value,
        style: Typo.bodyMedium,
        color: withAlpha(WHITE, 0.78),
        lines: 2,
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ top: 10, bottom: 10 })
  }
}

@Builder
function SheetHairline() {
  Row()
    .width('100%')
    .height(1)
    .backgroundColor(withAlpha(WHITE, 0.09))
}

@ComponentV2
struct MoreAction {
  @Param icon: string = 'musicNote';
  @Param title: string = '';
  @Param subtitle: string = '';
  @Param isEnabled: boolean = true;
  @Event onTap: () => void = () => {
  };

  build() {
    Row({ space: 0 }) {
      InkGlyph({
        name: this.icon as IconName,
        boxSize: 19,
        color: withAlpha(WHITE, this.isEnabled ? 0.7 : 0.3),
      })
      Row().width(13).height(1)
      Column({ space: 0 }) {
        InkText({
          text: this.title,
          style: Typo.titleSmall,
          color: withAlpha(WHITE, this.isEnabled ? 0.9 : 0.35),
        })
        InkText({
          text: this.subtitle,
          style: Typo.bodySmall,
          color: withAlpha(WHITE, this.isEnabled ? 0.42 : 0.2),
          lines: 1,
        })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .borderRadius(10)
    .scale({
      x: this.isEnabled ? 1 : 0.98,
      y: this.isEnabled ? 1 : 0.98,
    })
    .padding({ top: 11, bottom: 11 })
    .onClick((): void => {
      if (this.isEnabled) {
        this.onTap();
      }
    })
  }
}

@ComponentV2
struct SpeedPane {
  @Param current: number = 1;
  @Event onSelect: (value: number) => void = (_v: number) => {
  };

  private options(): number[] {
    return IS_ANDROID ? [0.75, 1, 1.25, 1.75, 2] : [0.75, 1, 1.25, 1.5, 2];
  }

  build() {
    Column({ space: 0 }) {
      ForEach(this.options(), (value: number) => {
        Row({ space: 0 }) {
          InkText({
            text: formatSpeed(value),
            style: Typo.titleMedium,
            color: Math.abs(this.current - value) < 0.01 ? WHITE : withAlpha(WHITE, 0.65),
          })
            .layoutWeight(1)
          if (Math.abs(this.current - value) < 0.01) {
            Stack({ alignContent: Alignment.Center }) {
              InkGlyph({ name: 'check', boxSize: 14, color: '#FF14161B' })
            }
            .width(20)
            .height(20)
            .borderRadius(10)
            .backgroundColor(WHITE)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .borderRadius(10)
        .backgroundColor(Math.abs(this.current - value) < 0.01 ? withAlpha(WHITE, 0.09) : TRANSPARENT)
        .padding({ left: 14, right: 14, top: 14, bottom: 14 })
        .onClick((): void => this.onSelect(value))
      }, (value: number) => String(value))
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 8, bottom: 8 })
  }
}

// ---- 工具函数 ----

function subtitleOf(track: Track): string {
  const parts: string[] = [];
  if (track.artistLabel.length > 0) {
    parts.push(track.artistLabel);
  }
  if (track.albumTitle.length > 0) {
    parts.push(track.albumTitle);
  }
  return parts.length > 0 ? parts.join(' · ') : '未知艺人';
}

function lerpHex(from: string, to: string, fraction: number): string {
  const pa = parseHex(from);
  const pb = parseHex(to);
  const mix = (a: number, b: number): number => Math.round(a + (b - a) * fraction);
  const hex2 = (v: number): string => {
    const s = Math.min(Math.max(v, 0), 255).toString(16);
    return s.length === 1 ? `0${s}` : s;
  };
  return `#${hex2(mix(pa[0], pb[0]))}${hex2(mix(pa[1], pb[1]))}${hex2(mix(pa[2], pb[2]))}${hex2(mix(pa[3], pb[3]))}`;
}

function parseHex(color: string): number[] {
  let hex = color.startsWith('#') ? color.substring(1) : color;
  if (hex.length === 6) {
    hex = `FF${hex}`;
  }
  const v = parseInt(hex, 16);
  return [(v >>> 24) & 0xFF, (v >>> 16) & 0xFF, (v >>> 8) & 0xFF, v & 0xFF];
}

function formatSpeed(value: number): string {
  const isInt = Math.abs(value % 1) < 0.0001;
  const number = isInt ? value.toFixed(1) : String(value);
  return `${number}×`;
}

function formatCommentTime(raw: string): string {
  if (raw.trim().length === 0) {
    return '';
  }
  const m: RegExpExecArray | null =
    /(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/.exec(raw);
  if (m === null) {
    return raw.substring(0, Math.min(10, raw.length));
  }
  const utcMs = Date.UTC(
    parseInt(m[1], 10),
    parseInt(m[2], 10) - 1,
    parseInt(m[3], 10),
    parseInt(m[4], 10),
    parseInt(m[5], 10),
    parseInt(m[6], 10),
  );
  const diff = Math.max(new Date().getTime() - utcMs, 0);
  if (diff < 60000) {
    return L10n.tr('刚刚');
  }
  if (diff < 3600000) {
    return L10n.fmt('fmt_minutes_ago', [Math.floor(diff / 60000)]);
  }
  if (diff < 86400000) {
    return L10n.fmt('fmt_hours_ago', [Math.floor(diff / 3600000)]);
  }
  if (diff < 7 * 86400000) {
    return L10n.fmt('fmt_days_ago', [Math.floor(diff / 86400000)]);
  }
  const month = parseInt(m[2], 10);
  const day = parseInt(m[3], 10);
  return `${month < 10 ? '0' + month : month}-${day < 10 ? '0' + day : day}`;
}

// 转发到全局导航
function AppNavOpenAlbum(albumId: number): void {
  AppNav.openAlbum(albumId);
}

function AppNavOpenArtist(artistId: number): void {
  AppNav.openArtist(artistId);
}


