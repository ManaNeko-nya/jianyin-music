import { Track } from '../data/Models';
import { Typo, Theme, withAlpha } from './Theme';
import {
  InkText, TrackRow, TinySpinner,
} from './Components';
import { InkGlyph } from './Icons';
import { AppNav } from './AppNav';
import { Player } from '../playback/PlayerEngine';
import { L10n } from '../data/L10n';

/** 排序模式契约：松手后把数据源的最终顺序整体交回页面保存。 */
export class SongListReorder {
  readonly onCommit: (tracks: Track[]) => void;

  constructor(onCommit: (tracks: Track[]) => void) {
    this.onCommit = onCommit;
  }
}

/** LazyForEach 数据源：歌曲列表 + 拖拽移动通知。 */
export class TrackListSource implements IDataSource {
  private listeners: DataChangeListener[] = [];
  items: Track[] = [];
  moved: boolean = false;

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): Track {
    return this.items[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    this.listeners.push(listener);
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    this.listeners = this.listeners.filter((l): boolean => l !== listener);
  }

  reload(items: Track[]): void {
    // 必须持有副本：否则 move() 会就地改掉页面/视图模型里的数组。
    this.items = items.slice();
    this.moved = false;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }

  snapshot(): Track[] {
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

  sameOrderAs(items: Track[]): boolean {
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

/**
 * 全应用唯一的歌曲列表控件。
 * 统一负责：点击播放、右侧「更多」、多选、自动分页、定位正在播放歌曲、拖动排序。
 */
@ComponentV2
export struct SongListPage {
  @Param tracks: Track[] = [];
  @Param currentTrackId: number = -1;
  @Param showCover: boolean = true;
  @Param indexOffset: number = 0;
  @Param selectionMode: boolean = false;
  @Param selectedIds: Set<number> = new Set<number>();
  @Param emptyTitle: string = '暂无歌曲';
  @Param emptySubtitle: string = '';
  @Param showEmptyState: boolean = true;
  @Param topPadding: number = 0;
  @Param bottomPadding: number = 24;
  @Param showLocate: boolean = true;
  @Param pagingEnabled: boolean = false;
  @Param hasMore: boolean = false;
  @Param loadingMore: boolean = false;
  @Param hasMoreAction: boolean = false;
  @Param reorder: SongListReorder | undefined = undefined;
  @BuilderParam header: () => void = emptyHeader;
  @BuilderParam footer: () => void = emptyHeader;
  @Event onPlay: (index: number) => void = (_i: number) => {
  };
  @Event onMore: (track: Track) => void = (_t: Track) => {
  };
  @Event onLoadMore: () => void = () => {
  };
  @Event onScrollOffset: (offset: number) => void = (_offset: number): void => {
  };

  @Local private source: TrackListSource = new TrackListSource();
  @Local private visibleRange: number[] = [0, 0];
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.source.reload(this.tracks);
  }

  @Monitor('tracks')
  onTracksChanged(): void {
    if (this.source.sameOrderAs(this.tracks)) {
      return;
    }
    this.source.reload(this.tracks);
  }

  private currentIndex(): number {
    if (this.currentTrackId < 0) {
      return -1;
    }
    for (let i = 0; i < this.tracks.length; i++) {
      if (this.tracks[i].id === this.currentTrackId) {
        return i;
      }
    }
    return -1;
  }

  /** 固定的两个前缀项：顶部间距 ListItem + header ListItem。 */
  private leadingItemCount: number = 2;

  private isCurrentVisible(): boolean {
    const idx = this.currentIndex();
    if (idx < 0) {
      return false;
    }
    const target = this.leadingItemCount + idx;
    return this.visibleRange[0] <= target && target <= this.visibleRange[1];
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      List({
        scroller: this.scroller,
        space: 0,
      }) {
        ListItem() {
          Column().width('100%').height(this.topPadding)
        }

        ListItem() {
          Column({ space: 0 }) {
            this.header()
          }
          .width('100%')
        }

        if (this.tracks.length === 0 && this.showEmptyState) {
          ListItem() {
            Column({ space: 0 }) {
              InkText({ text: '—', style: Typo.displayMedium, color: withAlpha(Theme.ink.inkMuted, 0.5) })
              Row().height(10)
              InkText({ text: this.emptyTitle, style: Typo.titleMedium, color: Theme.ink.inkSoft })
              if (this.emptySubtitle.length > 0) {
                Row().height(6)
                InkText({
                  text: this.emptySubtitle,
                  style: Typo.bodySmall,
                  color: Theme.ink.inkMuted,
                  alignTo: TextAlign.Center,
                })
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .padding({ top: 40, bottom: 40 })
          }
        } else if (this.reorder !== undefined) {
          LazyForEach(this.source, (item: Track, index?: number) => {
            this.trackItem(item, index !== undefined ? index : 0)
          }, (item: Track) => item.id.toString())
            .onMove((from: number, to: number): void => {
              this.source.move(from, to);
            }, {
              onDrop: (_index: number): void => {
                setTimeout((): void => {
                  const reorder = this.reorder;
                  if (reorder === undefined || !this.source.moved) {
                    return;
                  }
                  this.source.moved = false;
                  const snapshot = this.source.snapshot();
                  reorder.onCommit(snapshot);
                }, 350);
              },
            })
        } else {
          LazyForEach(this.source, (item: Track, index?: number) => {
            this.trackItem(item, index !== undefined ? index : 0)
          }, (item: Track) => item.id.toString())
        }

        ListItem() {
          this.footer()
        }

        if (this.pagingEnabled) {
          ListItem() {
            Column() {
              if (this.loadingMore) {
                TinySpinner({ color: Theme.ink.accent, boxSize: 16 })
              } else if (!this.hasMore && this.tracks.length > 0) {
                InkText({
                  text: L10n.fmt('fmt_loaded_all_songs', [this.tracks.length]),
                  style: Typo.labelSmall,
                  color: withAlpha(Theme.ink.inkMuted, 0.7),
                })
              }
            }
            .width('100%')
            .height(56)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          }
        }

        ListItem() {
          Column().width('100%')
            .height((this.selectionMode ? 108 : this.bottomPadding) +
              (Player.state.track !== null ? AppNav.floatClearance : 0))
            .animation({ duration: 200, curve: Curve.FastOutSlowIn })
        }
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .onScrollIndex((first: number, last: number) => {
        this.visibleRange = [first, last];
        if (this.pagingEnabled && this.hasMore && !this.loadingMore &&
          last >= this.leadingItemCount + this.tracks.length - 3) {
          this.onLoadMore();
        }
      })
      .onDidScroll((_offset: number, _state: ScrollState): void => {
        this.onScrollOffset(this.scroller.currentOffset().yOffset);
      })

      if (this.showLocate && !this.selectionMode &&
        this.currentIndex() >= 0 && !this.isCurrentVisible()) {
        Stack({ alignContent: Alignment.Center }) {
          InkGlyph({ name: 'myLocation', boxSize: 20, color: Theme.ink.accent })
        }
        .width(42)
        .height(42)
        .borderRadius(21)
        .backgroundColor(Theme.ink.raised)
        .margin({
          right: 16,
          bottom: 16 + (Player.state.track !== null ? AppNav.floatClearance : 0),
        })
        .onClick(() => {
          const idx = this.currentIndex();
          if (idx >= 0) {
            this.scroller.scrollToIndex(this.leadingItemCount + idx, true);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  trackItem(item: Track, index: number) {
    ListItem() {
      TrackRow({
        track: item,
        index: this.indexOffset + index,
        isCurrent: item.id === this.currentTrackId,
        showCover: this.showCover,
        selectionMode: this.selectionMode,
        selected: this.selectedIds.has(item.id),
        hasMore: this.hasMoreAction && !this.selectionMode,
        onTap: (): void => {
          this.onPlay(index);
        },
        onMore: (): void => {
          this.onMore(item);
        },
      })
    }
  }
}

@Builder
function emptyHeader(): void {
}
