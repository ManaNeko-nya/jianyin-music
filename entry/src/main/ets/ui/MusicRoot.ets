import { Session } from '../data/Session';
import { Track } from '../data/Models';
import { Player, PlayerState } from '../playback/PlayerEngine';
import { averageColor } from '../data/ArtworkColor';
import { Theme, playerBaseColorFor } from './Theme';
import { MiniPlayer, InkBottomDock, DockTab, AppTopBar } from './Components';
import { PlayerOpen, PlayerOpenRequest, Backs, AppMetrics, BottomBar } from './AppState';
import { AppNav } from './AppNav';
import { HomeScreen } from './screens/HomeScreen';
import { LibraryScreen } from './screens/LibraryScreen';
import { PlaylistsScreen } from './screens/PlaylistsScreen';
import { PlaylistScreen } from './screens/PlaylistScreen';
import { ProfileScreen, LoginScreen } from './screens/ProfileScreen';
import { AboutScreen } from './screens/SettingsScreens';
import { SearchScreen } from './screens/SearchScreen';
import { AlbumScreen } from './screens/AlbumScreen';
import { ArtistScreen } from './screens/ArtistScreen';
import { NowPlayingScreen } from './screens/NowPlayingScreen';

const DOCK_HEIGHT: number = 61;

@ComponentV2
export struct MusicRoot {
  @Local playerState: PlayerState = Player.state;
  @Local showPlayer: boolean = false;
  @Local playerProgress: number = 0;
  @Local rawThemeColor: string = '#FF14161B';
  @Local animatedThemeColor: string = '#FF14161B';
  @Local openReq: PlayerOpenRequest = PlayerOpen;
  private pendingOpen: boolean = false;

  aboutToAppear(): void {
    this.refreshArtColor();
    Player.addTrackListener((track: Track | null) => {
      this.refreshArtColor();
      if (track === null && this.showPlayer) {
        this.closePlayerAnimated();
      }
    });
  }

  @Monitor('openReq.pending')
  onOpenRequest(): void {
    if (this.openReq.pending) {
      this.openReq.pending = false;
      this.openPlayerAnimated();
    }
  }

  private refreshArtColor(): void {
    const track = Player.state.track;
    const fallback = Theme.ink.raised;
    const url = track !== null && track.coverUrl.length > 0 ? Session.mediaUrl(track.coverUrl) : null;
    if (url === null) {
      this.applyThemeColor(fallback);
      return;
    }
    averageColor(url).then((rgb: string | null) => {
      this.applyThemeColor(rgb !== null ? rgb : fallback);
    });
  }

  private applyThemeColor(color: string): void {
    if (color === this.rawThemeColor) {
      return;
    }
    this.rawThemeColor = color;
    this.getUIContext().animateTo({ duration: 500, curve: Curve.FastOutSlowIn }, () => {
      this.animatedThemeColor = color;
    });
  }

  // ---- 播放器开合：整页从底部滑入/滑出 ----

  private animatePlayerTo(target: number, onEnd?: () => void): void {
    this.getUIContext().animateTo({
      duration: 320,
      curve: Curve.FastOutSlowIn,
      onFinish: () => {
        if (onEnd !== undefined) {
          onEnd();
        }
      },
    }, () => {
      this.playerProgress = target;
    });
  }

  private openPlayerAnimated(): void {
    if (this.showPlayer && this.playerProgress > 0.99) {
      return;
    }
    if (this.showPlayer) {
      this.animatePlayerTo(1);
      return;
    }
    // 先挂载播放器（progress=0 时整页在屏幕外），布局完成后再启动滑入动画。
    this.showPlayer = true;
    this.playerProgress = 0;
    this.pendingOpen = true;
    setTimeout(() => {
      if (this.showPlayer && this.pendingOpen) {
        this.pendingOpen = false;
        this.animatePlayerTo(1);
      }
    }, 100);
  }

  private closePlayerAnimated(): void {
    if (!this.showPlayer) {
      return;
    }
    this.animatePlayerTo(0, () => {
      this.showPlayer = false;
    });
  }

  private updateOpenDrag(fraction: number): void {
    if (!this.showPlayer) {
      if (fraction <= 0) {
        return;
      }
      this.showPlayer = true;
      this.playerProgress = 0;
    }
    this.playerProgress = Math.min(Math.max(this.playerProgress + fraction, 0), 1);
  }

  private endOpenDrag(): void {
    if (!this.showPlayer) {
      return;
    }
    if (this.playerProgress >= 0.18) {
      this.animatePlayerTo(1);
    } else {
      this.animatePlayerTo(0, () => {
        this.showPlayer = false;
      });
    }
  }

  private updateCollapseDrag(fraction: number): void {
    if (!this.showPlayer) {
      return;
    }
    this.playerProgress = Math.min(Math.max(this.playerProgress - fraction, 0), 1);
  }

  private endCollapseDrag(): void {
    if (!this.showPlayer) {
      return;
    }
    if (this.playerProgress <= 0.72) {
      this.animatePlayerTo(0, () => {
        this.showPlayer = false;
      });
    } else {
      this.animatePlayerTo(1);
    }
  }

  // ---- 二级页面 ----

  private tabs(): DockTab[] {
    return [
      new DockTab('home', '首页', 'home'),
      new DockTab('library', '曲库', 'library'),
      new DockTab('playlists', '歌单', 'queue'),
      new DockTab('profile', '我的', 'person'),
    ];
  }

  private parseId(route: string): number {
    const idx = route.indexOf('/');
    if (idx < 0) {
      return 0;
    }
    const n = parseInt(route.substring(idx + 1), 10);
    return isNaN(n) ? 0 : n;
  }

  /** 全部二级页面的统一 NavDestination（标准 Navigation，两端可用）。 */
  @Builder
  pageMap(name: string, _param?: object) {
    NavDestination() {
      Column({ space: 0 }) {
        if (name === 'search') {
          SearchScreen()
        } else if (name.startsWith('album/')) {
          AlbumScreen({ albumId: this.parseId(name) })
        } else if (name.startsWith('artist/')) {
          ArtistScreen({ artistId: this.parseId(name) })
        } else if (name.startsWith('playlist/')) {
          PlaylistScreen({ playlistId: this.parseId(name) })
        } else if (name === 'login') {
          LoginScreen()
        } else if (name === 'settings/about') {
          AboutScreen()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.ink.canvas)
    }
    .hideTitleBar(true)
    .onBackPressed(() => {
      if (Backs.handle()) {
        return true;
      }
      if (AppNav.canPop) {
        AppNav.pop();
        return true;
      }
      return false;
    })
  }

  /** 主页为底栏留位；二级页只让开手势条区域；底部多选操作栏出现时整体上移。 */
  private miniBottomInset(): number {
    const base = AppNav.hasDetail ? AppMetrics.navBottom : DOCK_HEIGHT + AppMetrics.navBottom;
    return base + BottomBar.height;
  }

  private currentTrack(): Track | null {
    return this.playerState.track;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Navigation(AppNav.mainStack) {
        Column({ space: 0 }) {
          Tabs({ barPosition: BarPosition.Start, index: AppNav.tabIndex() }) {
            TabContent() {
              HomeScreen({ dataVersion: Session.dataVersion })
            }
            .tabBar('首页')

            TabContent() {
              LibraryScreen({ dataVersion: Session.dataVersion })
            }
            .tabBar('曲库')

            TabContent() {
              PlaylistsScreen({ dataVersion: Session.dataVersion })
            }
            .tabBar('歌单')

            TabContent() {
              ProfileScreen()
            }
            .tabBar('我的')
          }
          .scrollable(false)
          .barHeight(0)
          .layoutWeight(1)
          .width('100%')
          .onChange((index: number) => {
            AppNav.selectTabByIndex(index);
          })

          Stack({ alignContent: Alignment.Top }) {
            InkBottomDock({
              tabs: this.tabs(),
              selectedRoute: AppNav.activeTab,
              onSelect: (tab: DockTab): void => {
                AppNav.selectTab(tab.route as 'home' | 'library' | 'playlists' | 'profile');
              },
            })
          }
          .width('100%')
          .height(DOCK_HEIGHT)
          .clip(true)

          Column().width('100%').height(AppMetrics.navBottom)
        }
        .width('100%')
        .height('100%')
      }
      .navDestination(this.pageMap)
      .hideTitleBar(true)
      .mode(NavigationMode.Stack)
      .hideToolBar(true)

      // 导航墙：二级页用迷你播放器的底色填充手势条区域，随迷你条一起滑入。
      if (this.currentTrack() !== null) {
        Stack({ alignContent: Alignment.Bottom }) {
          Column()
            .width('100%')
            .height(AppMetrics.navBottom)
            .backgroundColor(playerBaseColorFor(this.animatedThemeColor))
            .translate({ y: AppNav.hasDetail ? 0 : AppMetrics.navBottom })
            .opacity(AppNav.hasDetail ? 1 : 0)
            .animation({ duration: 240, curve: Curve.FastOutSlowIn })
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
      }

      // 迷你播放条：悬浮于导航之上，二级页面同样可见。
      if (this.currentTrack() !== null) {
        Stack({ alignContent: Alignment.Bottom }) {
          MiniPlayer({
            track: this.currentTrack() as Track,
            isPlaying: this.playerState.isPlaying,
            positionMs: this.playerState.positionMs,
            durationMs: this.playerState.durationMs,
            baseColor: playerBaseColorFor(this.animatedThemeColor),
            onOpen: (): void => this.openPlayerAnimated(),
            onToggle: (): void => Player.toggle(),
            onNext: (): void => Player.next(),
            onOpenDragStart: (): void => {
            },
            onOpenDrag: (f: number): void => this.updateOpenDrag(f),
            onOpenDragEnd: (): void => this.endOpenDrag(),
          })
            .margin({ bottom: this.miniBottomInset() })
            .animation({ duration: 240, curve: Curve.FastOutSlowIn })
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)
      }

      // 播放浮层必须直接写在 build 里：@Builder 按值传参不会随状态刷新，
      // 换歌时背景色就会停在第一次渲染那一帧。
      if (this.showPlayer && this.currentTrack() !== null) {
        Column({ space: 0 }) {
          NowPlayingScreen({
            state: this.playerState,
            baseColor: playerBaseColorFor(this.animatedThemeColor),
            onClose: (): void => this.closePlayerAnimated(),
            onCollapseDragStart: (): void => {
            },
            onCollapseDrag: (f: number): void => this.updateCollapseDrag(f),
            onCollapseDragEnd: (): void => this.endCollapseDrag(),
          })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(playerBaseColorFor(this.animatedThemeColor))
        .onAreaChange((_o: Area, _n: Area): void => {
          if (this.pendingOpen) {
            this.pendingOpen = false;
            this.animatePlayerTo(1);
          }
        })
        .translate({ y: (1 - this.playerProgress) * AppTopBar.screenHeight })
        .zIndex(2)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.ink.canvas)
  }
}
