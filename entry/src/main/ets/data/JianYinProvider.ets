import { Api } from './Api';
import { Session, User } from './Session';
import { JObj, jObj, jArr, jInt, jBool, jStr } from './Json';
import {
  Album, Track, Playlist, AlbumDetail, PlaylistDetail, HomeData, PageData, SearchResults,
  ArtistDetail, CommentsPage,
  parseAlbum, parseTrack, parsePlaylist, parseAlbumPage, parseTrackPage, parseArtist,
  parseComments, albumList, playlistList, intIds,
} from './Models';
import { MusicProvider } from './MusicProvider';
import { ProviderCapabilities, ProviderKind, PROVIDER_JIANYIN } from './ProviderTypes';

function params(entries: string[][]): Map<string, string> {
  const m = new Map<string, string>();
  for (const e of entries) {
    m.set(e[0], e[1]);
  }
  return m;
}

/** 简音自有后端。 */
export class JianYinProvider implements MusicProvider {
  readonly kind: ProviderKind = PROVIDER_JIANYIN;
  readonly capabilities: ProviderCapabilities = new ProviderCapabilities(true, true, true, true, true);

  private ensureLoggedIn(): void {
    if (!Session.loggedIn) {
      throw new Error('请先登录');
    }
  }

  async home(): Promise<HomeData> {
    const featuredP = this.albumPage(1, 5, 'updated_at');
    const latestP = this.trackPage(1, 8);
    const recommendedP = Api.getArray(
      '/albums/recommendations', params([['limit', '10']]), false).then(
      (arr: Object[]): Album[] => albumList(arr));
    const rankingP = this.albumPage(1, 8, 'score');
    const featured = await featuredP;
    const latest = await latestP;
    const recommended = await recommendedP;
    const rankingPage = await rankingP;
    const ranking = rankingPage.items.filter((a: Album): boolean => a.score !== null);
    return new HomeData(featured.items, recommended, latest.items, ranking);
  }

  async albumPage(page: number = 1, pageSize: number = 30, sort: string = 'updated_at',
    query: string = ''): Promise<PageData<Album>> {
    const path = query.trim().length === 0 ? '/albums' : '/albums/search';
    const data = await Api.getObject(path, params([
      ['page', String(page)],
      ['page_size', String(pageSize)],
      ['sort', sort],
      ['q', query],
    ]), false);
    return parseAlbumPage(data);
  }

  async trackPage(page: number = 1, pageSize: number = 100, query: string = ''): Promise<PageData<Track>> {
    const data = await Api.getObject('/tracks', params([
      ['page', String(page)],
      ['page_size', String(pageSize)],
      ['q', query],
      ['sort', query.trim().length === 0 ? 'created_at' : 'title'],
    ]), false);
    return parseTrackPage(data);
  }

  async albumDetail(albumId: number): Promise<AlbumDetail> {
    const data = await Api.getObject(`/albums/${albumId}`, new Map(), false);
    const album = parseAlbum(data);
    const tracks: Track[] = [];
    const array = jArr(data, 'tracks');
    for (let i = 0; i < array.length; i++) {
      const raw = array[i];
      if (raw instanceof Object && !(raw instanceof Array)) {
        tracks.push(parseTrack(raw as JObj, album));
      }
    }
    return new AlbumDetail(album, tracks);
  }

  async artistDetail(artistId: number): Promise<ArtistDetail> {
    const data = await Api.getObject(`/artists/${artistId}`, new Map(), false);
    return parseArtist(data);
  }

  async artistTracks(artistId: number, page: number = 1, pageSize: number = 50): Promise<PageData<Track>> {
    const data = await Api.getObject(`/artists/${artistId}/tracks`, params([
      ['page', String(page)],
      ['page_size', String(pageSize)],
      ['sort', 'release'],
    ]), false);
    return parseTrackPage(data);
  }

  async lyrics(trackId: number): Promise<string> {
    const data = await Api.getObject(`/tracks/${trackId}/lyrics`);
    return jStr(data, 'lyrics');
  }

  async comments(trackId: number, page: number = 1, pageSize: number = 50): Promise<CommentsPage> {
    if (!Session.loggedIn) {
      return new CommentsPage([], 0);
    }
    const data = await Api.getObject(`/tracks/${trackId}/comments`, params([
      ['page', String(page)],
      ['page_size', String(pageSize)],
      ['sort', 'time'],
    ]));
    return parseComments(data);
  }

  async postComment(trackId: number, content: string): Promise<void> {
    this.ensureLoggedIn();
    const body: Record<string, Object> = { 'content': content };
    await Api.postObject(`/tracks/${trackId}/comments`, body);
  }

  async playlists(): Promise<Playlist[]> {
    if (!Session.loggedIn) {
      return [];
    }
    const arr = await Api.getArray('/favorite-lists');
    return playlistList(arr);
  }

  async playlistDetail(playlistId: number): Promise<PlaylistDetail> {
    this.ensureLoggedIn();
    const lists = await Api.getArray('/favorite-lists');
    const all = playlistList(lists);
    let matched: Playlist | null = null;
    for (const p of all) {
      if (p.id === playlistId) {
        matched = p;
        break;
      }
    }
    const name = matched !== null ? matched.name : '歌单';
    const tracks: Track[] = [];
    let page = 1;
    let totalPages = 1;
    while (page <= totalPages) {
      const data = await Api.getObject('/favorites', params([
        ['page', String(page)],
        ['page_size', '100'],
        ['list_id', String(playlistId)],
      ]));
      const items = jArr(data, 'items');
      for (let i = 0; i < items.length; i++) {
        const raw = items[i];
        if (!(raw instanceof Object) || raw instanceof Array) {
          continue;
        }
        const item = raw as JObj;
        const track = jObj(item, 'track');
        if (track !== null) {
          tracks.push(parseTrack(track));
        }
      }
      totalPages = jInt(data, 'total_pages', 1);
      page++;
    }
    return new PlaylistDetail(playlistId, name, matched !== null ? matched.coverUrl : '', tracks);
  }

  async createPlaylist(name: string): Promise<Playlist> {
    this.ensureLoggedIn();
    const body: Record<string, Object> = { 'name': name.trim() };
    const data = await Api.postObject('/favorite-lists', body);
    return parsePlaylist(data);
  }

  async renamePlaylist(playlistId: number, name: string): Promise<Playlist> {
    this.ensureLoggedIn();
    const body: Record<string, Object> = { 'name': name.trim() };
    const data = await Api.patchObject(`/favorite-lists/${playlistId}`, body);
    return parsePlaylist(data);
  }

  async deletePlaylist(playlistId: number): Promise<void> {
    this.ensureLoggedIn();
    await Api.deleteObject(`/favorite-lists/${playlistId}`);
  }

  async reorderPlaylists(listIds: number[]): Promise<void> {
    this.ensureLoggedIn();
    const body: Record<string, Object> = { 'list_ids': listIds };
    await Api.putObject('/favorite-lists/order', body);
  }

  async reorderPlaylistTracks(playlistId: number, trackIds: number[]): Promise<void> {
    this.ensureLoggedIn();
    const body: Record<string, Object> = { 'track_ids': trackIds };
    await Api.putObject(`/favorite-lists/${playlistId}/order`, body);
  }

  async addTracksToPlaylist(playlistId: number, trackIds: number[]): Promise<void> {
    this.ensureLoggedIn();
    for (const trackId of trackIds) {
      const check = await Api.getObject(`/favorites/check/${trackId}`);
      const existing = intIds(jArr(check, 'list_ids'));
      if (jBool(check, 'favorited')) {
        const merged = Array.from(new Set<number>([...existing, playlistId]));
        const body: Record<string, Object> = { 'list_ids': merged };
        await Api.patchObject(`/favorites/${trackId}`, body);
      } else {
        const body: Record<string, Object> = {
          'track_id': trackId,
          'list_ids': [playlistId],
        };
        await Api.postObject('/favorites', body);
      }
    }
  }

  async removeTracksFromPlaylist(playlistId: number, trackIds: number[]): Promise<void> {
    this.ensureLoggedIn();
    for (const trackId of trackIds) {
      const check = await Api.getObject(`/favorites/check/${trackId}`);
      if (!jBool(check, 'favorited')) {
        continue;
      }
      const existing = intIds(jArr(check, 'list_ids'));
      const remaining = existing.filter((id: number): boolean => id !== playlistId);
      if (remaining.length === 0) {
        await Api.deleteObject(`/favorites/${trackId}`);
      } else {
        const body: Record<string, Object> = { 'list_ids': remaining };
        await Api.patchObject(`/favorites/${trackId}`, body);
      }
    }
  }

  async search(query: string): Promise<SearchResults> {
    const albumsP = Api.getObject('/albums/search', params([
      ['q', query],
      ['page', '1'],
      ['page_size', '24'],
    ]), false).then((data: JObj): Album[] => parseAlbumPage(data).items);
    const tracksP = this.searchTracks(query, 1);
    const albums = await albumsP;
    const tracks = await tracksP;
    return new SearchResults(albums, tracks.items, tracks.total);
  }

  async searchTracks(query: string, page: number, pageSize: number = 30): Promise<PageData<Track>> {
    const data = await Api.getObject('/tracks', params([
      ['q', query],
      ['page', String(page)],
      ['page_size', String(pageSize)],
      ['sort', 'title'],
    ]), false);
    return parseTrackPage(data);
  }

  async login(baseUrl: string, account: string, password: string): Promise<User | null> {
    Session.setProviderKind(PROVIDER_JIANYIN);
    const normalized = Session.normalizeBase(baseUrl, PROVIDER_JIANYIN);
    if (normalized !== Session.baseUrl) {
      Session.setBaseUrl(normalized);
    }
    const result = await Api.login(account.trim(), password);
    if (result.accessToken.length === 0) {
      throw new Error('服务器未返回登录令牌');
    }
    Session.saveLogin(result.accessToken, result.refreshToken, result.user);
    return result.user;
  }

  async guest(baseUrl: string): Promise<void> {
    Session.setProviderKind(PROVIDER_JIANYIN);
    const normalized = Session.normalizeBase(baseUrl, PROVIDER_JIANYIN);
    if (normalized.length === 0) {
      throw new Error('请填写服务器地址');
    }
    Session.setBaseUrl(normalized);
    await Api.getObject('/albums', params([
      ['page', '1'],
      ['page_size', '1'],
    ]), false);
    Session.enterGuest();
  }

  async register(baseUrl: string, username: string, password: string, nickname: string): Promise<User | null> {
    Session.setProviderKind(PROVIDER_JIANYIN);
    const normalized = Session.normalizeBase(baseUrl, PROVIDER_JIANYIN);
    if (normalized !== Session.baseUrl) {
      Session.setBaseUrl(normalized);
    }
    const result = await Api.register(username.trim(), password, nickname.trim());
    if (result.accessToken.length === 0) {
      throw new Error('服务器未返回注册令牌');
    }
    Session.saveLogin(result.accessToken, result.refreshToken, result.user);
    return result.user;
  }

  /** 退出登录立即生效：本地会话先清，服务端登出放后台，不等网络返回。 */
  async logout(): Promise<void> {
    const pending = Api.logout();
    Session.clear();
    try {
      await pending;
    } catch (err) {
    }
  }
}
