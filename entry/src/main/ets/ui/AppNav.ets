/**
 * 全局导航单例（官方推荐结构）：
 * - 页签切换用 Tabs 组件（TabContent 自带状态保持）；
 * - 所有二级页面共用一个 NavPathStack，由 Navigation 统一管理返回；
 * - activeTab 只记录当前页签，用于底部 Dock 高亮。
 */

import { AppMetrics } from './AppState';

export type TabId = 'home' | 'library' | 'playlists' | 'profile';

export const TAB_ORDER: TabId[] = ['home', 'library', 'playlists', 'profile'];

@ObservedV2
export class AppNavStore {
  /** 当前页签。 */
  @Trace activeTab: TabId = 'home';
  /** 曲库页内子页签：0 歌曲 / 1 专辑。 */
  @Trace libraryTab: number = 0;
  /** 是否处于二级页面；驱动底栏与迷你播放条的布局。 */
  @Trace hasDetail: boolean = false;
  /** 唯一的导航栈，承载全部二级页面。 */
  mainStack: NavPathStack = new NavPathStack();

  get isRootRoute(): boolean {
    // NavPathStack 只保存 NavDestination，Navigation 根内容不在栈中。
    return !this.hasDetail;
  }

  /** 滚动内容底部需要为悬浮迷你播放条让出的高度（vp）。 */
  get floatClearance(): number {
    return AppMetrics.miniBar + (this.hasDetail ? AppMetrics.navBottom : 0);
  }

  private syncDetail(): void {
    this.hasDetail = this.mainStack.size() > 0;
  }

  get canPop(): boolean {
    return this.mainStack.size() > 0;
  }

  tabIndex(): number {
    return TAB_ORDER.indexOf(this.activeTab);
  }

  tabByIndex(index: number): TabId {
    return index >= 0 && index < TAB_ORDER.length ? TAB_ORDER[index] : 'home';
  }

  /** Dock 点击切换页签；若正深处二级页面则先回到根。 */
  selectTab(tab: TabId): void {
    if (this.mainStack.size() > 0) {
      this.mainStack.clear();
    }
    this.syncDetail();
    this.activeTab = tab;
  }

  selectTabByIndex(index: number): void {
    this.selectTab(this.tabByIndex(index));
  }

  pop(): void {
    if (this.mainStack.size() > 0) {
      this.mainStack.pop();
    }
    this.syncDetail();
  }

  private push(route: string): void {
    this.mainStack.pushPathByName(route, undefined);
    this.syncDetail();
  }

  openSearch(): void {
    this.push('search');
  }

  openAlbum(albumId: number): void {
    this.push(`album/${albumId}`);
  }

  openArtist(artistId: number): void {
    this.push(`artist/${artistId}`);
  }

  openPlaylist(playlistId: number): void {
    this.push(`playlist/${playlistId}`);
  }

  /** 首页「全部专辑」：回到曲库页签并切到专辑子页签。 */
  openAllAlbums(): void {
    this.selectTab('library');
    this.libraryTab = 1;
  }

  openAbout(): void {
    this.push('settings/about');
  }

  /** 未登录时点「去登录」跳到我的页签。 */
  openProfileTab(): void {
    this.selectTab('profile');
  }

  openLogin(): void {
    this.push('login');
  }
}

export const AppNav: AppNavStore = new AppNavStore();
