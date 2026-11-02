/**
 * 图标映射：安卓端使用 Material Icons（rounded），鸿蒙端改用系统自带
 * SymbolGlyph（sys.symbol.*），语义一一对应，名称均已在本机 SDK 中核实存在。
 */
export type IconName =
  | 'home'
  | 'library'
  | 'queue'
  | 'person'
  | 'search'
  | 'play'
  | 'pause'
  | 'next'
  | 'previous'
  | 'more'
  | 'moreHoriz'
  | 'musicNote'
  | 'checkCircle'
  | 'circle'
  | 'dragHandle'
  | 'close'
  | 'back'
  | 'forward'
  | 'lock'
  | 'refresh'
  | 'cloudOff'
  | 'checklist'
  | 'playlistAdd'
  | 'playlistPlay'
  | 'delete'
  | 'chevronRight'
  | 'myLocation'
  | 'add'
  | 'check'
  | 'darkMode'
  | 'swap'
  | 'server'
  | 'info'
  | 'logout'
  | 'edit'
  | 'album'
  | 'chat'
  | 'lyrics'
  | 'speed'
  | 'orderPlay'
  | 'loopList'
  | 'loopOne'
  | 'shuffle'
  | 'chevronDown'
  | 'send';

export function iconRes(name: IconName): Resource {
  switch (name) {
    case 'home':
      return $r('sys.symbol.house');
    case 'library':
      return $r('sys.symbol.music');
    case 'queue':
      return $r('sys.symbol.list_badge_play');
    case 'person':
      return $r('sys.symbol.person');
    case 'search':
      return $r('sys.symbol.magnifyingglass');
    case 'play':
      return $r('sys.symbol.play_fill');
    case 'pause':
      return $r('sys.symbol.pause_fill');
    case 'next':
      return $r('sys.symbol.forward_end_fill');
    case 'previous':
      return $r('sys.symbol.backward_end_fill');
    case 'more':
      return $r('sys.symbol.more');
    case 'moreHoriz':
      return $r('sys.symbol.more_fill');
    case 'musicNote':
      return $r('sys.symbol.music');
    case 'checkCircle':
      return $r('sys.symbol.checkmark_circle');
    case 'circle':
      return $r('sys.symbol.circle');
    case 'dragHandle':
      return $r('sys.symbol.line_3_horizontal');
    case 'close':
      return $r('sys.symbol.multiply');
    case 'back':
      return $r('sys.symbol.chevron_left');
    case 'forward':
      return $r('sys.symbol.arrowshape_right');
    case 'lock':
      return $r('sys.symbol.lock');
    case 'refresh':
      return $r('sys.symbol.arrow_counterclockwise');
    case 'cloudOff':
      return $r('sys.symbol.icloud_slash');
    case 'checklist':
      return $r('sys.symbol.checkmark_square');
    case 'playlistAdd':
      return $r('sys.symbol.add_songlist');
    case 'playlistPlay':
      return $r('sys.symbol.list_badge_play');
    case 'delete':
      return $r('sys.symbol.trash');
    case 'chevronRight':
      return $r('sys.symbol.chevron_right');
    case 'myLocation':
      return $r('sys.symbol.scope');
    case 'add':
      return $r('sys.symbol.plus');
    case 'check':
      return $r('sys.symbol.checkmark');
    case 'darkMode':
      return $r('sys.symbol.dark_mode');
    case 'swap':
      return $r('sys.symbol.swap');
    case 'server':
      return $r('sys.symbol.cloud');
    case 'info':
      return $r('sys.symbol.info_circle');
    case 'logout':
      return $r('sys.symbol.arrowshape_turn_up_right');
    case 'edit':
      return $r('sys.symbol.square_and_pencil');
    case 'album':
      return $r('sys.symbol.record_circle');
    case 'chat':
      return $r('sys.symbol.ellipsis_bubble');
    case 'lyrics':
      return $r('sys.symbol.lyrics_square');
    case 'speed':
      return $r('sys.symbol.speed_multiple');
    case 'orderPlay':
      return $r('sys.symbol.order_play');
    case 'loopList':
      return $r('sys.symbol.repeat');
    case 'loopOne':
      return $r('sys.symbol.repeat_1');
    case 'shuffle':
      return $r('sys.symbol.shuffle');
    case 'chevronDown':
      return $r('sys.symbol.chevron_down');
    case 'send':
      return $r('sys.symbol.paperplane_fill');
  }
}

/** 系统符号图标；等价于安卓端 Icon(imageVector, tint, size)。 */
@ComponentV2
export struct InkGlyph {
  @Param name: IconName = 'musicNote';
  @Param boxSize: number = 20;
  @Param color: string = '#FF000000';

  private isDots(): boolean {
    return this.name === 'more' || this.name === 'moreHoriz';
  }

  private dotSize(): number {
    return Math.max(2.5, this.boxSize * 0.15);
  }

  private dotGap(): number {
    return Math.max(2, this.boxSize * 0.12);
  }

  @Builder
  private dots() {
    Row({ space: this.dotGap() }) {
      ForEach([0, 1, 2], (_value: number) => {
        Column()
          .width(this.dotSize())
          .height(this.dotSize())
          .borderRadius(this.dotSize() / 2)
          .backgroundColor(this.color)
      }, (value: number) => value.toString())
    }
    .width(this.boxSize)
    .height(this.boxSize)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .draggable(false)
  }

  build() {
    if (this.isDots()) {
      this.dots()
    } else {
      SymbolGlyph(iconRes(this.name))
        .fontSize(this.boxSize)
        .fontColor([this.color])
        .draggable(false)
    }
  }
}
