import { hilog } from '@kit.PerformanceAnalysisKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';
import { Session } from '../data/Session';
import { L10n } from '../data/L10n';
import { Track, Album } from '../data/Models';
import { Typo, TypoStyle, Theme, InkPalette, withAlpha, luminance, WHITE, BLACK, TRANSPARENT } from './Theme';
import { InkGlyph, IconName } from './Icons';

/** 列表加载状态，等价于安卓端 LoadState sealed interface。 */
export abstract class LoadState<T> {
  readonly kind: string;

  constructor(kind: string) {
    this.kind = kind;
  }
}

export class Loading<T> extends LoadState<T> {
  constructor() {
    super('loading');
  }
}

export class Success<T> extends LoadState<T> {
  readonly data: T;

  constructor(data: T) {
    super('success');
    this.data = data;
  }
}

export class LoadError<T> extends LoadState<T> {
  readonly message: string;

  constructor(message: string) {
    super('error');
    this.message = message;
  }
}

export function formatDuration(ms: number): string {
  if (ms <= 0) {
    return '00:00';
  }
  const total = Math.floor(ms / 1000);
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const seconds = total % 60;
  return formatDurationSec(hours, minutes, seconds);
}

export function formatDurationSeconds(seconds: number): string {
  return formatDuration(Math.trunc(seconds * 1000));
}

function p2(n: number): string {
  return n < 10 ? `0${n}` : String(n);
}

function formatDurationSec(hours: number, minutes: number, seconds: number): string {
  if (hours > 0) {
    return `${hours}:${p2(minutes)}:${p2(seconds)}`;
  }
  return `${p2(minutes)}:${p2(seconds)}`;
}

/** 统一文本组件：把安卓端 MaterialTheme.typography 的样式带过来。 */
@ComponentV2
export struct InkText {
  @Param text: string = '';
  @Param style: TypoStyle = Typo.bodyMedium;
  @Param color: string = BLACK;
  @Param lines: number = 999;
  @Param weight: number = 0;
  @Param alignTo: TextAlign = TextAlign.Start;
  @Param maxFontSize: number = 0;

  build() {
    Text(L10n.tr(this.text))
      .fontSize(this.style.size)
      .fontWeight(this.weight > 0 ? this.weight : this.style.weight)
      .lineHeight(this.style.lineHeight)
      .letterSpacing(this.style.letterSpacing)
      .fontColor(this.color)
      .maxLines(this.lines)
      .minFontSize(this.maxFontSize > 0 ? this.maxFontSize : this.style.size)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .textAlign(this.alignTo)
  }
}

/** 小标题（labelSmall + inkMuted）。 */
@ComponentV2
export struct Kicker {
  @Param text: string = '';
  @Param color: string = '';

  build() {
    InkText({
      text: this.text,
      style: Typo.labelSmall,
      color: this.color.length > 0 ? this.color : Theme.ink.inkMuted,
    })
  }
}

/** 封面占位组件：渐变底 + 音符占位，图片加载后覆盖其上。 */
@ComponentV2
export struct Artwork {
  @Param url: string = '';
  @Param desc: string = '';
  @Param corner: number = 10;

  build() {
    Stack() {
      InkGlyph({ name: 'musicNote', boxSize: 24, color: Theme.ink.inkMuted })
      if (this.url.length > 0) {
        Image(Session.mediaUrl(this.url))
          .objectFit(ImageFit.Cover)
          .draggable(false)
          .width('100%')
          .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .borderRadius(this.corner)
    .clip(true)
    .linearGradient({
      angle: 135,
      colors: [[Theme.ink.fillStrong, 0], [Theme.ink.fill, 1]],
    })
    .accessibilityText(L10n.tr(this.desc))
  }
}

@ComponentV2
export struct Hairline {
  build() {
    Row()
      .width('100%')
      .height(1)
      .backgroundColor(Theme.ink.hairline)
  }
}

/** 圆形图标按钮；热区最小 48vp（等价于 sizeInTouch）。 */
@ComponentV2
export struct RoundIconButton {
  @Param icon: IconName = 'musicNote';
  @Param desc: string = '';
  @Event onTap: () => void = () => {
  };
  @Param tint: string = '';
  @Param bgColor: string = TRANSPARENT;
  @Param boxSize: number = 44;
  @Param iconSize: number = 22;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Stack({ alignContent: Alignment.Center }) {
        InkGlyph({
          name: this.icon,
          boxSize: this.iconSize,
          color: this.tint.length > 0 ? this.tint : Theme.ink.ink,
        })
      }
      .width(this.boxSize)
      .height(this.boxSize)
      .borderRadius(this.boxSize / 2)
      .backgroundColor(this.bgColor)
    }
    .width(this.boxSize < 48 ? 48 : this.boxSize)
    .height(this.boxSize < 48 ? 48 : this.boxSize)
    .accessibilityText(L10n.tr(this.desc))
    .onClick((event?: ClickEvent) => {
      this.onTap();
    })
  }
}

/** 沉浸光感圆形图标按钮：用于封面等复杂背景上的悬浮操作。 */
@ComponentV2
export struct ImmersiveCircleIconButton {
  @Param icon: IconName = 'search';
  @Param desc: string = '';
  @Event onTap: () => void = () => {
  };
  @Param tint: string = WHITE;
  @Param boxSize: number = 48;
  @Param iconSize: number = 22;

  private material(): uiMaterial.ImmersiveMaterial | undefined {
    try {
      if (!deviceInfo.apiAvailable('26.0.0')) {
        return undefined;
      }
    } catch (err) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      materialColor: withAlpha(BLACK, 0.32),
      interactive: true,
      applyShadow: false,
      lightEffect: { color: WHITE },
    });
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      InkGlyph({ name: this.icon, boxSize: this.iconSize, color: this.tint })
    }
    .width(this.boxSize)
    .height(this.boxSize)
    .borderRadius(this.boxSize / 2)
    .backgroundColor(withAlpha(BLACK, 0.26))
    .systemMaterial(this.material())
    .accessibilityText(L10n.tr(this.desc))
    .onClick((_event?: ClickEvent) => {
      this.onTap();
    })
  }
}

/** 系栏尺寸，由 EntryAbility 注入。 */
export class AppTopBar {
  static topPad: number = 14;
  static screenHeight: number = 800;
  /** 二级页标题栏高度（vp），不含状态栏。 */
  static readonly barHeight: number = 56;

  /**
   * 普通页内容顶部让位。让位必须加在**第一个条目**上而不是滚动容器视口，
   * 否则内容滚不到标题栏底下，渐变模糊就没有可糊的东西。
   */
  static contentTop(): number {
    return AppTopBar.topPad + AppTopBar.barHeight;
  }
}

@ComponentV2
export struct PageHeader {
  @Param title: string = '';
  @BuilderParam trailing: () => void = emptyBuilder;

  build() {
    Column({ space: 0 }) {
      Row() {
        InkText({ text: this.title, style: Typo.displaySmall, color: Theme.ink.ink })
          .layoutWeight(1)
        this.trailing()
      }
      .alignItems(VerticalAlign.Center)
      .width('100%')
      .height(40)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: 20,
      right: 8,
      top: AppTopBar.topPad + 2,
      bottom: 10,
    })
  }
}

@ComponentV2
export struct SectionHeading {
  @Param title: string = '';
  @Param actionText: string = '';
  @Event onAction: () => void = () => {
  };

  build() {
    Row() {
      InkText({ text: this.title, style: Typo.headlineSmall, color: Theme.ink.ink })
        .layoutWeight(1)
      if (this.actionText.length > 0) {
        TextAction({ text: this.actionText, onTap: () => this.onAction() })
      }
    }
    .width('100%')
    .padding({ left: 20, right: 12, top: 26, bottom: 10 })
    .alignItems(VerticalAlign.Center)
  }
}

@ComponentV2
export struct TextAction {
  @Param text: string = '';
  @Event onTap: () => void = () => {
  };
  @Param color: string = '';
  @Param showIcon: boolean = true;

  build() {
    Row() {
      InkText({
        text: this.text,
        style: Typo.labelLarge,
        color: this.color.length > 0 ? this.color : Theme.ink.accent,
      })
      if (this.showIcon) {
        Row().width(4).height(1)
        InkGlyph({
          name: 'chevronRight',
          boxSize: 14,
          color: this.color.length > 0 ? this.color : Theme.ink.accent,
        })
      }
    }
    .alignItems(VerticalAlign.Center)
    .borderRadius(25)
    .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .onClick((event?: ClickEvent) => {
      this.onTap();
    })
  }
}

@ComponentV2
export struct AlbumTile {
  @Param album: Album = emptyAlbum();
  @Event onTap: () => void = () => {
  };
  @Param tileWidth: number = 142;

  build() {
    Column({ space: 0 }) {
      Stack() {
        Artwork({ url: this.album.coverUrl, desc: this.album.title, corner: 8 })
      }
      .width('100%')
      .aspectRatio(1)
      Row().height(8)
      InkText({
        text: this.album.title,
        style: Typo.titleSmall,
        color: Theme.ink.ink,
        lines: 1,
      })
      Row().height(2)
      InkText({
        text: this.album.artistLabel.length > 0 ? this.album.artistLabel : '未知艺人',
        style: Typo.bodySmall,
        color: Theme.ink.inkMuted,
        lines: 1,
      })
    }
    .alignItems(HorizontalAlign.Start)
    .width(this.tileWidth > 0 ? this.tileWidth : '100%')
    .onClick((event?: ClickEvent) => {
      this.onTap();
    })
  }
}

/** 播放全部控件（专辑/歌单详情头部使用）。 */
@ComponentV2
export struct PlayAllControl {
  @Param label: string = '播放全部';
  @Event onTap: () => void = () => {
  };

  build() {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        InkGlyph({ name: 'play', boxSize: 20, color: Theme.ink.onAccent })
      }
      .width(38)
      .height(38)
      .borderRadius(19)
      .backgroundColor(Theme.ink.accent)
      Row().width(9).height(1)
      InkText({ text: this.label, style: Typo.labelLarge, color: Theme.ink.ink })
      Row().width(6).height(1)
    }
    .alignItems(VerticalAlign.Center)
    .borderRadius(25)
    .padding(4)
    .onClick((event?: ClickEvent) => {
      this.onTap();
    })
  }
}

function emptyAlbum(): Album {
  return new Album(0, 0, '', '', '', 'album', '', null, null, 0, '', []);
}

export function emptyTrack(): Track {
  return new Track(0, 0, '', 0, '', '', '', '', 0, 0, false, 0);
}

/** 歌曲行：序号/封面/标题/时长/更多按钮/多选圆圈/拖动排序提示。 */
@ComponentV2
export struct TrackRow {
  @Param track: Track = emptyTrack();
  @Param index: number = -1;
  @Param isCurrent: boolean = false;
  @Param showCover: boolean = true;
  @Param selectionMode: boolean = false;
  @Param selected: boolean = false;
  @Param hasMore: boolean = true;
  @Event onTap: () => void = () => {
  };
  @Event onMore: () => void = () => {
  };

  private isRowEnabled(): boolean {
    return this.track.audioUrl.length > 0;
  }

  build() {
    Row() {
      Stack({ alignContent: Alignment.Start }) {
        if (this.index >= 0) {
          InkText({
            text: p2(this.index + 1),
            style: Typo.labelSmall,
            color: this.isCurrent ? Theme.ink.accent : Theme.ink.inkMuted,
          })
            .width(27)
            .opacity(this.selectionMode ? 0 : 1)
        }
        Row({ space: 0 }) {
          Stack({ alignContent: Alignment.Start }) {
            InkGlyph({ name: 'circle', boxSize: 21, color: withAlpha(Theme.ink.inkMuted, 0.7) })
              .opacity(this.selected ? 0 : 1)
            InkGlyph({ name: 'checkCircle', boxSize: 21, color: Theme.ink.accent })
              .opacity(this.selected ? 1 : 0)
          }
          .width(21)
          .height(21)
          Row().width(6).height(1)
        }
        .width(27)
        .opacity(this.selectionMode ? 1 : 0)
      }
      .width(27)
      .height(21)
      if (this.showCover) {
        Stack() {
          Artwork({ url: this.track.coverUrl, desc: this.track.title, corner: 7 })
        }
        .width(46)
        .height(46)
        Row().width(13).height(1)
      }
      Column({ space: 0 }) {
        InkText({
          text: this.track.title,
          style: Typo.titleSmall,
          color: this.isCurrent ? Theme.ink.accent : Theme.ink.ink,
          lines: 1,
          weight: this.isCurrent ? 700 : 500,
        })
        Row().height(2)
        InkText({
          text: subtitleOf(this.track),
          style: Typo.bodySmall,
          color: Theme.ink.inkMuted,
          lines: 1,
        })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row().width(10).height(1)
      if (this.isCurrent) {
        EqualizerBars({ playing: true, color: Theme.ink.accent })
          .width(14)
          .height(16)
        Row().width(8).height(1)
      }
      InkText({
        text: formatDuration(this.track.durationMs),
        style: Typo.labelMedium,
        color: Theme.ink.inkMuted,
      })
      if (this.hasMore) {
        Row().width(2).height(1)
        RoundIconButton({
          icon: 'more',
          desc: '更多',
          onTap: () => this.onMore(),
          tint: Theme.ink.inkMuted,
          boxSize: 34,
          iconSize: 20,
        })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.isCurrent ? Theme.ink.fill : TRANSPARENT)
    .padding({
      left: 20,
      right: this.hasMore ? 6 : 20,
      top: 9,
      bottom: 9,
    })
    .opacity(this.isRowEnabled() ? 1 : 0.4)
    .onClick(() => {
      if (this.isRowEnabled()) {
        this.onTap();
      }
    })
  }
}

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

/** 三条正弦律动的均衡器条。 */
@ComponentV2
export struct EqualizerBars {
  @Param playing: boolean = true;
  @Param color: string = '#FF000000';
  @Local t: number = 0;

  aboutToAppear(): void {
    this.getUIContext().animateTo({
      duration: 900,
      curve: Curve.Linear,
      iterations: -1,
      playMode: PlayMode.Normal,
    }, () => {
      this.t = 1;
    });
  }

  private fraction(i: number): number {
    const value = this.playing ? this.t : 0.35;
    const wave = (Math.sin(value * 2 * Math.PI + i * 1.8) + 1) / 2;
    return 0.32 + 0.68 * wave;
  }

  private bar(i: number): number {
    const f = this.fraction(i);
    return Math.round(f * 1000) / 10;
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Column()
        .width('20%')
        .height(`${this.bar(0)}%`)
        .borderRadius('50%')
        .backgroundColor(this.color)
        .position({ x: '0%', y: `${(100 - this.bar(0)) / 2}%` })
      Column()
        .width('20%')
        .height(`${this.bar(1)}%`)
        .borderRadius('50%')
        .backgroundColor(this.color)
        .position({ x: '40%', y: `${(100 - this.bar(1)) / 2}%` })
      Column()
        .width('20%')
        .height(`${this.bar(2)}%`)
        .borderRadius('50%')
        .backgroundColor(this.color)
        .position({ x: '80%', y: `${(100 - this.bar(2)) / 2}%` })
    }
    .width('100%')
    .height('100%')
  }
}

@ComponentV2
export struct TinySpinner {
  @Param color: string = '#FF000000';
  @Param boxSize: number = 16;
  @Local rotation: number = 0;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  aboutToAppear(): void {
    this.getUIContext().animateTo({
      duration: 800,
      curve: Curve.Linear,
      iterations: -1,
      playMode: PlayMode.Normal,
    }, () => {
      this.rotation = 360;
    });
  }

  private draw(): void {
    const ctx = this.context;
    const w = this.boxSize;
    ctx.clearRect(0, 0, w, w);
    ctx.lineWidth = Math.max(1.5, w * 0.1);
    ctx.lineCap = 'round';
    ctx.strokeStyle = this.color;
    ctx.beginPath();
    ctx.arc(w / 2, w / 2, w / 2 - ctx.lineWidth, 0, 260 * Math.PI / 180);
    ctx.stroke();
  }

  build() {
    Canvas(this.context)
      .width(this.boxSize)
      .height(this.boxSize)
      .rotate({
        z: 1,
        angle: this.rotation,
        centerX: '50%',
        centerY: '50%',
      })
      .onReady(() => {
        this.draw();
      })
  }
}

@ComponentV2
export struct InkButton {
  @Param text: string = '';
  @Event onTap: () => void = () => {
  };
  @Param isEnabled: boolean = true;
  @Param loading: boolean = false;
  @Param quiet: boolean = false;

  build() {
    Row() {
      if (this.loading) {
        TinySpinner({ color: this.contentColor() })
        Row().width(10).height(1)
      }
      InkText({
        text: this.text,
        style: Typo.labelLarge,
        color: this.contentColor(),
        weight: 600,
      })
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .width('100%')
    .height(52)
    .borderRadius(26)
    .backgroundColor(this.bgColor())
    .onClick(() => {
      if (this.isEnabled && !this.loading) {
        this.onTap();
      }
    })
  }

  private bgColor(): string {
    if (this.quiet) {
      return TRANSPARENT;
    }
    return this.isEnabled ? Theme.ink.accent : Theme.ink.fill;
  }

  private contentColor(): string {
    if (this.quiet) {
      return Theme.ink.ink;
    }
    return this.isEnabled ? Theme.ink.onAccent : Theme.ink.inkMuted;
  }
}

@ComponentV2
export struct PlayCircleButton {
  @Param isPlaying: boolean = false;
  @Event onTap: () => void = () => {
  };
  @Param boxSize: number = 68;
  @Param bgColor: string = '';
  @Param tint: string = '';
  @Local pressed: boolean = false;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      InkGlyph({
        name: this.isPlaying ? 'pause' : 'play',
        boxSize: Math.round(this.boxSize * 0.42),
        color: this.tint.length > 0 ? this.tint : Theme.ink.onAccent,
      })
    }
    .width(this.boxSize)
    .height(this.boxSize)
    .borderRadius(this.boxSize / 2)
    .backgroundColor(this.bgColor.length > 0 ? this.bgColor : Theme.ink.ink)
    .scale({
      x: this.pressed ? 0.93 : 1,
      y: this.pressed ? 0.93 : 1,
    })
    .animation({ duration: 120, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
    .onClick((event?: ClickEvent) => {
      this.onTap();
    })
  }
}

/** 下划线输入框：label + 无边框输入 + 底部发丝线。 */
@ComponentV2
export struct UnderlinedField {
  @Param value: string = '';
  @Event onValueChange: (v: string) => void = (_v: string) => {
  };
  @Param label: string = '';
  @Param placeholder: string = '';
  @Param isPassword: boolean = false;
  @Param inputType: InputType = InputType.Normal;
  @Param enterKey: EnterKeyType = EnterKeyType.Next;
  @Event onImeAction: () => void = () => {
  };

  build() {
    Column({ space: 0 }) {
      Kicker({ text: this.label })
      Row().height(4)
      TextInput({ text: this.value, placeholder: L10n.tr(this.placeholder) })
        .type(this.isPassword ? InputType.Password : this.inputType)
        .enterKeyType(this.enterKey)
        .backgroundColor(TRANSPARENT)
        .padding({ top: 10, bottom: 10, left: 0, right: 0 })
        .border({ width: { bottom: 0 } })
        .borderRadius(0)
        .placeholderColor(withAlpha(Theme.ink.inkMuted, 0.7))
        .placeholderFont({ size: Typo.bodyLarge.size })
        .fontColor(Theme.ink.ink)
        .fontSize(Typo.bodyLarge.size)
        .caretColor(Theme.ink.accent)
        .onChange((v: string) => this.onValueChange(v))
        .onSubmit((_enterKey: EnterKeyType, _event: SubmitEvent) => {
          this.onImeAction();
        })
        .width('100%')
      Hairline()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

@ComponentV2
export struct LoadingBox {
  build() {
    Stack({ alignContent: Alignment.Center }) {
      EqualizerBars({ playing: true, color: Theme.ink.accent })
        .width(28)
        .height(22)
    }
    .width('100%')
    .height('100%')
  }
}

@ComponentV2
export struct ErrorBox {
  @Param message: string = '';
  @Event onRetry: () => void = () => {
  };

  build() {
    Column({ space: 0 }) {
      InkGlyph({ name: 'cloudOff', boxSize: 34, color: Theme.ink.inkMuted })
      Row().height(16)
      InkText({
        text: this.message,
        style: Typo.bodyMedium,
        color: Theme.ink.inkSoft,
        alignTo: TextAlign.Center,
        lines: 999,
      })
      Row().height(18)
      Row() {
        InkGlyph({ name: 'refresh', boxSize: 16, color: Theme.ink.accent })
        Row().width(6).height(1)
        InkText({ text: '重试', style: Typo.labelLarge, color: Theme.ink.accent })
      }
      .alignItems(VerticalAlign.Center)
      .padding({ left: 18, right: 18, top: 10, bottom: 10 })
      .onClick(() => this.onRetry())
    }
    .width('100%')
    .height('100%')
    .padding(36)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

@ComponentV2
export struct EmptyBox {
  @Param title: string = '';
  @Param subtitle: string = '';

  build() {
    Column({ space: 0 }) {
      InkText({ text: '—', style: Typo.displayMedium, color: withAlpha(Theme.ink.inkMuted, 0.5) })
      Row().height(10)
      InkText({
        text: this.title,
        style: Typo.titleMedium,
        color: Theme.ink.inkSoft,
        alignTo: TextAlign.Center,
      })
      if (this.subtitle.length > 0) {
        Row().height(6)
        InkText({
          text: this.subtitle,
          style: Typo.bodySmall,
          color: Theme.ink.inkMuted,
          alignTo: TextAlign.Center,
        })
      }
    }
    .width('100%')
    .height('100%')
    .padding(36)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

@ComponentV2
export struct LoginPrompt {
  @Event onLogin: () => void = () => {
  };

  build() {
    Column({ space: 0 }) {
      InkText({ text: '登录后查看\n你的歌单', style: Typo.displaySmall, color: Theme.ink.ink })
      Row().height(12)
      InkText({
        text: '登录账号后同步收藏列表与歌单顺序。',
        style: Typo.bodyMedium,
        color: Theme.ink.inkMuted,
      })
      Row().height(26)
      Row() {
        InkGlyph({ name: 'lock', boxSize: 16, color: Theme.ink.onAccent })
        Row().width(8).height(1)
        InkText({ text: '去登录', style: Typo.labelLarge, color: Theme.ink.onAccent, weight: 600 })
      }
      .alignItems(VerticalAlign.Center)
      .borderRadius(25)
      .backgroundColor(Theme.ink.accent)
      .padding({ left: 22, right: 22, top: 13, bottom: 13 })
      .onClick(() => this.onLogin())
    }
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24 })
  }
}

@ComponentV2
export struct LoadingBars {
  @Param color: string = '';

  build() {
    EqualizerBars({ playing: true, color: this.color.length > 0 ? this.color : Theme.ink.accent })
  }
}

/** 迷你播放条：进度线 + 封面 + 标题 + 播放/下一首，上滑展开播放器。 */
@ComponentV2
export struct MiniPlayer {
  @Param track: Track = emptyTrack();
  @Param isPlaying: boolean = false;
  @Param positionMs: number = 0;
  @Param durationMs: number = 0;
  @Param baseColor: string = '#FF14161B';
  @Event onOpen: () => void = () => {
  };
  @Event onToggle: () => void = () => {
  };
  @Event onNext: () => void = () => {
  };
  @Event onOpenDragStart: () => void = () => {
  };
  @Event onOpenDrag: (fraction: number) => void = (_f: number) => {
  };
  @Event onOpenDragEnd: () => void = () => {
  };

  private lastPanY: number = 0;

  private fgColor(): string {
    return luminanceOf(this.baseColor) > 0.45 ? '#FF14161B' : '#FFFFFFFF';
  }

  private progressFraction(): number {
    return this.durationMs > 0
      ? Math.min(Math.max(this.positionMs / this.durationMs, 0), 1)
      : 0;
  }

  build() {
    Column({ space: 0 }) {
      Stack({ alignContent: Alignment.Start }) {
        Column()
          .width(`${this.progressFraction() * 100}%`)
          .height(2)
          .backgroundColor(withAlpha(this.fgColor(), 0.9))
      }
      .width('100%')
      .height(2)
      .backgroundColor(withAlpha(this.fgColor(), 0.16))

      Row() {
        Stack() {
          Artwork({ url: this.track.coverUrl, desc: this.track.title, corner: 6 })
        }
        .width(42)
        .height(42)
        Row().width(12).height(1)
        Column({ space: 0 }) {
          InkText({
            text: this.track.title,
            style: Typo.titleSmall,
            color: this.fgColor(),
            lines: 1,
          })
          InkText({
            text: this.track.artistLabel.length > 0 ? this.track.artistLabel : '未知艺人',
            style: Typo.bodySmall,
            color: withAlpha(this.fgColor(), 0.62),
            lines: 1,
          })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        RoundIconButton({
          icon: this.isPlaying ? 'pause' : 'play',
          desc: this.isPlaying ? '暂停' : '播放',
          onTap: () => this.onToggle(),
          tint: this.fgColor(),
          boxSize: 38,
          iconSize: 24,
        })
        RoundIconButton({
          icon: 'next',
          desc: '下一首',
          onTap: () => this.onNext(),
          tint: this.fgColor(),
          boxSize: 38,
          iconSize: 22,
        })
      }
      .width('100%')
      .height(62)
      .padding({ left: 14, right: 4 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .backgroundColor(this.baseColor)
    .gesture(PanGesture({ fingers: 1, direction: PanDirection.Vertical, distance: 5 })
      .onActionStart((_e: GestureEvent) => {
        this.lastPanY = 0;
        this.onOpenDragStart();
      })
      .onActionUpdate((e: GestureEvent) => {
        const dy = e.offsetY - this.lastPanY;
        this.lastPanY = e.offsetY;
        this.onOpenDrag(-dy / AppTopBar.screenHeight);
      })
      .onActionEnd(() => {
        this.onOpenDragEnd();
      }))
    .onClick((event?: ClickEvent) => {
      this.onOpen();
    })
  }
}

function luminanceOf(color: string): number {
  return luminance(color);
}

@Builder
function emptyBuilder(): void {
}

export class DockTab {
  readonly route: string;
  readonly label: string;
  readonly icon: IconName;

  constructor(route: string, label: string, icon: IconName) {
    this.route = route;
    this.label = label;
    this.icon = icon;
  }
}

@ComponentV2
export struct InkBottomDock {
  @Param tabs: DockTab[] = [];
  @Param selectedRoute: string = '';
  @Event onSelect: (tab: DockTab) => void = (_t: DockTab) => {
  };

  build() {
    Column({ space: 0 }) {
      Hairline()
      Row() {
        ForEach(this.tabs, (tab: DockTab) => {
          this.dockTab(tab)
        }, (tab: DockTab) => tab.route)
      }
      .width('100%')
      .height(60)
    }
    .width('100%')
    .backgroundColor(Theme.ink.canvas)
  }

  @Builder
  dockTab(tab: DockTab) {
    Column({ space: 0 }) {
      InkGlyph({
        name: tab.icon,
        boxSize: 21,
        color: this.selectedRoute === tab.route ? Theme.ink.ink : Theme.ink.inkMuted,
      })
      Row().height(3)
      InkText({
        text: tab.label,
        style: Typo.labelSmall,
        color: this.selectedRoute === tab.route ? Theme.ink.ink : Theme.ink.inkMuted,
      })
      Row().height(3)
      Column()
        .width(12)
        .height(2)
        .backgroundColor(this.selectedRoute === tab.route ? Theme.ink.accent : TRANSPARENT)
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick((event?: ClickEvent) => {
      this.onSelect(tab);
    })
  }
}





