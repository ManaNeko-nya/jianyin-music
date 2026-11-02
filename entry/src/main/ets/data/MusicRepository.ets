import { Session, User } from './Session';
import {
  Album, AlbumDetail, ArtistDetail, CommentsPage, HomeData, PageData, Playlist,
  PlaylistDetail, SearchResults, Track,
} from './Models';
import { JianYinProvider } from './JianYinProvider';
import { SubsonicProvider } from './SubsonicProvider';
import { MusicProvider } from './MusicProvider';
import {
  ProviderCapabilities, ProviderKind, PROVIDER_JIANYIN, PROVIDER_SUBSONIC,
} from './ProviderTypes';

/**
 * 全应用唯一的数据门面。
 * 页面只依赖这里；具体协议由当前登录的服务决定。
 */
class MusicRepositoryFacade {
  private jianYin: JianYinProvider = new JianYinProvider();
  private subsonic: SubsonicProvider = new SubsonicProvider();

  private active(): MusicProvider {
    return Session.providerKind === PROVIDER_SUBSONIC ? this.subsonic : this.jianYin;
  }

  get capabilities(): ProviderCapabilities {
    return this.active().capabilities;
  }

  get providerKind(): ProviderKind {
    return Session.providerKind;
  }

  home(): Promise<HomeData> {
    return this.active().home();
  }

  albumPage(page: number = 1, pageSize: number = 30, sort: string = 'updated_at',
    query: string = ''): Promise<PageData<Album>> {
    return this.active().albumPage(page, pageSize, sort, query);
  }

  trackPage(page: number = 1, pageSize: number = 100, query: string = ''): Promise<PageData<Track>> {
    return this.active().trackPage(page, pageSize, query);
  }

  albumDetail(albumId: number): Promise<AlbumDetail> {
    return this.active().albumDetail(albumId);
  }

  artistDetail(artistId: number): Promise<ArtistDetail> {
    return this.active().artistDetail(artistId);
  }

  artistTracks(artistId: number, page: number = 1, pageSize: number = 50): Promise<PageData<Track>> {
    return this.active().artistTracks(artistId, page, pageSize);
  }

  lyrics(trackId: number): Promise<string> {
    return this.active().lyrics(trackId);
  }

  comments(trackId: number, page: number = 1, pageSize: number = 50): Promise<CommentsPage> {
    return this.active().comments(trackId, page, pageSize);
  }

  postComment(trackId: number, content: string): Promise<void> {
    return this.active().postComment(trackId, content);
  }

  playlists(): Promise<Playlist[]> {
    return this.active().playlists();
  }

  playlistDetail(playlistId: number): Promise<PlaylistDetail> {
    return this.active().playlistDetail(playlistId);
  }

  createPlaylist(name: string): Promise<Playlist> {
    return this.active().createPlaylist(name);
  }

  renamePlaylist(playlistId: number, name: string): Promise<Playlist> {
    return this.active().renamePlaylist(playlistId, name);
  }

  deletePlaylist(playlistId: number): Promise<void> {
    return this.active().deletePlaylist(playlistId);
  }

  reorderPlaylists(listIds: number[]): Promise<void> {
    return this.active().reorderPlaylists(listIds);
  }

  reorderPlaylistTracks(playlistId: number, trackIds: number[]): Promise<void> {
    return this.active().reorderPlaylistTracks(playlistId, trackIds);
  }

  addTracksToPlaylist(playlistId: number, trackIds: number[]): Promise<void> {
    return this.active().addTracksToPlaylist(playlistId, trackIds);
  }

  removeTracksFromPlaylist(playlistId: number, trackIds: number[]): Promise<void> {
    return this.active().removeTracksFromPlaylist(playlistId, trackIds);
  }

  search(query: string): Promise<SearchResults> {
    return this.active().search(query);
  }

  searchTracks(query: string, page: number, pageSize: number = 30): Promise<PageData<Track>> {
    return this.active().searchTracks(query, page, pageSize);
  }

  /** 选择服务后登录；页面不再直接碰具体协议。失败时恢复原服务，避免半切换状态。 */
  async login(providerKind: ProviderKind, baseUrl: string, account: string,
    password: string): Promise<User | null> {
    const previous = Session.providerKind;
    Session.setProviderKind(providerKind);
    try {
      return await this.active().login(baseUrl, account, password);
    } catch (err) {
      Session.setProviderKind(previous);
      if (err instanceof Error) {
        throw err;
      }
      throw new Error('登录失败');
    }
  }

  /** 游客模式：只切换服务与地址，不登录；失败时恢复原服务。 */
  async guest(providerKind: ProviderKind, baseUrl: string): Promise<void> {
    const previousKind = Session.providerKind;
    const previousGuest = Session.guestMode;
    Session.setProviderKind(providerKind);
    try {
      await this.active().guest(baseUrl);
    } catch (err) {
      Session.setProviderKind(previousKind);
      Session.setGuestMode(previousGuest);
      if (err instanceof Error) {
        throw err;
      }
      throw new Error('游客模式连接失败');
    }
  }

  /** 注册只属于简音后端；登录页在非简音服务下会隐藏入口。 */
  register(baseUrl: string, username: string, password: string, nickname: string): Promise<User | null> {
    Session.setProviderKind(PROVIDER_JIANYIN);
    return this.jianYin.register(baseUrl, username, password, nickname);
  }

  logout(): Promise<void> {
    return this.active().logout();
  }
}

export const MusicRepository: MusicRepositoryFacade = new MusicRepositoryFacade();
