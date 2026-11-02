import {
  Album, AlbumDetail, ArtistDetail, ArtistRef, CommentsPage, HomeData, PageData, Playlist,
  PlaylistDetail, SearchResults, Track,
} from './Models';
import { Session, User } from './Session';
import { JObj, JArr, jObj, jObjAt, jStr, jInt, jBool, isNull } from './Json';
import { ApiException } from './Api';
import { md5Hex } from './Md5';
import { SubsonicClient } from './SubsonicClient';
import { MusicProvider } from './MusicProvider';
import {
  ProviderCapabilities, ProviderKind, PROVIDER_SUBSONIC,
} from './ProviderTypes';

function mapParams(entries: string[][]): Map<string, string> {
  const m = new Map<string, string>();
  for (const e of entries) {
    m.set(e[0], e[1]);
  }
  return m;
}

function objList(o: JObj, key: string): JObj[] {
  const v = o[key];
  if (v === undefined || v === null) {
    return [];
  }
  if (v instanceof Array) {
    const arr = v as JArr;
    const out: JObj[] = [];
    for (let i = 0; i < arr.length; i++) {
      const item = jObjAt(arr, i);
      if (item !== null) {
        out.push(item);
      }
    }
    return out;
  }
  if (typeof v === 'object') {
    return [v as JObj];
  }
  return [];
}

function stringList(o: JObj, key: string): string[] {
  const v = o[key];
  const out: string[] = [];
  if (typeof v === 'string' && v.length > 0) {
    out.push(v);
    return out;
  }
  if (v instanceof Array) {
    const arr = v as JArr;
    for (let i = 0; i < arr.length; i++) {
      const item = arr[i];
      if (typeof item === 'string' && item.length > 0) {
        out.push(item);
      }
    }
  }
  return out;
}

function newSalt(): string {
  const chars = 'abcdef0123456789';
  let salt = '';
  for (let i = 0; i < 16; i++) {
    salt += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return salt;
}

function pageOf(items: Track[], page: number, pageSize: number, total: number): PageData<Track> {
  return new PageData<Track>(items, total, page, pageSize, Math.max(1, Math.ceil(total / pageSize)));
}

/** Navidrome / Subsonic 协议。UI 仍用数字 ID，这里做字符串 ID 的双向映射。 */
export class SubsonicProvider implements MusicProvider {
  readonly kind: ProviderKind = PROVIDER_SUBSONIC;
  readonly capabilities: ProviderCapabilities = new ProviderCapabilities(false, false, false, true, true);

  private idToNum: Map<string, number> = new Map<string, number>();
  private numToId: Map<number, string> = new Map<number, string>();
  private artistAlbumSongs: Map<number, Track[]> = new Map<number, Track[]>();

  private resetIds(): void {
    this.idToNum = new Map<string, number>();
    this.numToId = new Map<number, string>();
    this.artistAlbumSongs = new Map<number, Track[]>();
  }

  private numId(raw: string): number {
    if (raw.length === 0) {
      return 0;
    }
    const cached = this.idToNum.get(raw);
    if (cached !== undefined) {
      return cached;
    }
    let hash = 2166136261;
    for (let i = 0; i < raw.length; i++) {
      hash ^= raw.charCodeAt(i);
      hash = (hash + ((hash << 1) + (hash << 4) + (hash << 7) + (hash << 8) + (hash << 24))) >>> 0;
    }
    let id = (hash % 2147483646) + 1;
    while (this.numToId.has(id)) {
      id = (id % 2147483646) + 1;
    }
    this.idToNum.set(raw, id);
    this.numToId.set(id, raw);
    return id;
  }

  private rawId(id: number): string {
    if (id <= 0) {
      return '';
    }
    const raw = this.numToId.get(id);
    if (raw === undefined) {
      throw new ApiException(0, '媒体 ID 已失效，请刷新列表');
    }
    return raw;
  }

  private coverUrl(client: SubsonicClient, coverArt: string, size: number = 600): string {
    if (coverArt.length === 0) {
      return '';
    }
    return client.mediaUrl('getCoverArt', mapParams([
      ['id', coverArt],
      ['size', String(size)],
    ]));
  }

  private streamUrl(client: SubsonicClient, trackId: string): string {
    return client.mediaUrl('stream', mapParams([['id', trackId]]));
  }

  private toArtists(json: JObj, fallbackId: number, fallbackName: string): ArtistRef[] {
    const out: ArtistRef[] = [];
    const items = objList(json, 'artists');
    for (const item of items) {
      const name = jStr(item, 'name');
      if (name.length > 0) {
        out.push(new ArtistRef(this.numId(jStr(item, 'id')), name));
      }
    }
    if (out.length === 0 && fallbackName.length > 0) {
      out.push(new ArtistRef(fallbackId, fallbackName));
    }
    return out;
  }

  private toAlbum(client: SubsonicClient, json: JObj): Album {
    const raw = jStr(json, 'id');
    const artistRaw = jStr(json, 'artistId');
    const artistName = jStr(json, 'artist');
    const coverArt = jStr(json, 'coverArt');
    return new Album(
      this.numId(raw),
      this.numId(artistRaw),
      jStr(json, 'name', jStr(json, 'title', jStr(json, 'album'))),
      this.coverUrl(client, coverArt),
      artistName,
      'album',
      jStr(json, 'created'),
      isNull(json, 'year') ? null : jInt(json, 'year'),
      null,
      jInt(json, 'songCount'),
      jStr(json, 'notes'),
      stringList(json, 'genre'),
      null,
      this.toArtists(json, this.numId(artistRaw), artistName),
    );
  }

  private toTrack(client: SubsonicClient, json: JObj, parent?: Album): Track {
    const raw = jStr(json, 'id');
    const albumRaw = jStr(json, 'albumId', jStr(json, 'parent'));
    const albumId = albumRaw.length > 0 ? this.numId(albumRaw) : (parent !== undefined ? parent.id : 0);
    const artistRaw = jStr(json, 'artistId');
    const artistId = artistRaw.length > 0 ? this.numId(artistRaw)
      : (parent !== undefined ? parent.artistId : 0);
    const artistName = jStr(json, 'artist', parent !== undefined ? parent.artistName : '');
    const coverArt = jStr(json, 'coverArt');
    const cover = coverArt.length > 0 ? this.coverUrl(client, coverArt)
      : (parent !== undefined ? parent.coverUrl : '');
    const title = jStr(json, 'title', jStr(json, 'name'));
    return new Track(
      this.numId(raw),
      albumId,
      jStr(json, 'album', parent !== undefined ? parent.title : ''),
      artistId,
      artistName,
      cover,
      title,
      this.streamUrl(client, raw),
      jInt(json, 'duration'),
      jInt(json, 'track'),
      true,
      0,
      this.toArtists(json, artistId, artistName),
    );
  }

  private toPlaylist(client: SubsonicClient, json: JObj): Playlist {
    const coverArt = jStr(json, 'coverArt');
    return new Playlist(
      this.numId(jStr(json, 'id')),
      jStr(json, 'name'),
      jInt(json, 'songCount'),
      this.coverUrl(client, coverArt),
    );
  }

  private async albumList2(client: SubsonicClient, type: string, size: number,
    offset: number): Promise<Album[]> {
    const sub = await client.call('getAlbumList2', mapParams([
      ['type', type],
      ['size', String(size)],
      ['offset', String(offset)],
    ]));
    const root = jObj(sub, 'albumList2');
    if (root === null) {
      return [];
    }
    return objList(root, 'album').map((item: JObj): Album => this.toAlbum(client, item));
  }

  private async randomSongs(client: SubsonicClient, size: number): Promise<Track[]> {
    const sub = await client.call('getRandomSongs', mapParams([['size', String(size)]]));
    const root = jObj(sub, 'randomSongs');
    if (root === null) {
      return [];
    }
    return objList(root, 'song').map((item: JObj): Track => this.toTrack(client, item));
  }

  private async latestTracks(client: SubsonicClient): Promise<Track[]> {
    const albums = await this.albumList2(client, 'newest', 2, 0);
    const out: Track[] = [];
    for (const album of albums) {
      try {
        const detail = await this.albumDetail(album.id);
        out.push(...detail.tracks);
      } catch (err) {
      }
      if (out.length >= 8) {
        break;
      }
    }
    if (out.length === 0) {
      return this.randomSongs(client, 8);
    }
    return out.slice(0, 8);
  }

  async home(): Promise<HomeData> {
    const client = SubsonicClient.fromSession();
    const featured = await this.albumList2(client, 'newest', 5, 0);
    const recommended = await this.albumList2(client, 'random', 10, 0);
    const ranking = await this.albumList2(client, 'frequent', 8, 0);
    const latest = await this.latestTracks(client);
    return new HomeData(featured, recommended, latest, ranking);
  }

  async albumPage(page: number = 1, pageSize: number = 30, sort: string = 'updated_at',
    query: string = ''): Promise<PageData<Album>> {
    const client = SubsonicClient.fromSession();
    let items: Album[] = [];
    if (query.trim().length > 0) {
      const sub = await client.call('search3', mapParams([
        ['query', query],
        ['albumCount', String(pageSize)],
        ['albumOffset', String((page - 1) * pageSize)],
      ]));
      const root = jObj(sub, 'searchResult3');
      if (root !== null) {
        items = objList(root, 'album').map((item: JObj): Album => this.toAlbum(client, item));
      }
    } else {
      const type = sort === 'score' ? 'frequent'
        : (sort === 'updated_at' ? 'newest' : 'alphabeticalByName');
      items = await this.albumList2(client, type, pageSize, (page - 1) * pageSize);
    }
    const full = items.length >= pageSize;
    const total = (page - 1) * pageSize + items.length + (full ? 1 : 0);
    return new PageData<Album>(items, total, page, pageSize, full ? page + 1 : page);
  }

  async trackPage(page: number = 1, pageSize: number = 100, query: string = ''): Promise<PageData<Track>> {
    const client = SubsonicClient.fromSession();
    if (query.trim().length > 0) {
      const sub = await client.call('search3', mapParams([
        ['query', query],
        ['songCount', String(pageSize)],
        ['songOffset', String((page - 1) * pageSize)],
      ]));
      const root = jObj(sub, 'searchResult3');
      const items = root !== null
        ? objList(root, 'song').map((item: JObj): Track => this.toTrack(client, item)) : [];
      const full = items.length >= pageSize;
      const total = (page - 1) * pageSize + items.length + (full ? 1 : 0);
      return new PageData<Track>(items, total, page, pageSize, full ? page + 1 : page);
    }
    try {
      const sub = await client.call('search3', mapParams([
        ['query', ''],
        ['songCount', String(pageSize)],
        ['songOffset', String((page - 1) * pageSize)],
      ]));
      const root = jObj(sub, 'searchResult3');
      const items = root !== null
        ? objList(root, 'song').map((item: JObj): Track => this.toTrack(client, item)) : [];
      const full = items.length >= pageSize;
      const total = (page - 1) * pageSize + items.length + (full ? 1 : 0);
      return new PageData<Track>(items, total, page, pageSize, full ? page + 1 : page);
    } catch (err) {
      if (page > 1) {
        return new PageData<Track>([], (page - 1) * pageSize, page, pageSize, page);
      }
      const items = await this.randomSongs(client, pageSize);
      return new PageData<Track>(items, items.length, 1, pageSize, 1);
    }
  }

  async albumDetail(albumId: number): Promise<AlbumDetail> {
    const client = SubsonicClient.fromSession();
    const sub = await client.call('getAlbum', mapParams([['id', this.rawId(albumId)]]));
    const json = jObj(sub, 'album');
    if (json === null) {
      throw new ApiException(0, '专辑不存在');
    }
    const album = this.toAlbum(client, json);
    const tracks = objList(json, 'song').map((item: JObj): Track => this.toTrack(client, item, album));
    return new AlbumDetail(album, tracks);
  }

  async artistDetail(artistId: number): Promise<ArtistDetail> {
    const client = SubsonicClient.fromSession();
    const sub = await client.call('getArtist', mapParams([['id', this.rawId(artistId)]]));
    const json = jObj(sub, 'artist');
    if (json === null) {
      throw new ApiException(0, '艺人不存在');
    }
    const albums = objList(json, 'album').map((item: JObj): Album => this.toAlbum(client, item));
    let bio = '';
    let image = '';
    try {
      const info = await client.call('getArtistInfo2', mapParams([['id', this.rawId(artistId)]]));
      const data = jObj(info, 'artistInfo2');
      if (data !== null) {
        bio = jStr(data, 'biography');
        image = jStr(data, 'largeImageUrl', jStr(data, 'mediumImageUrl', jStr(data, 'smallImageUrl')));
      }
    } catch (err) {
    }
    let trackCount = 0;
    for (const album of albums) {
      trackCount += album.trackCount;
    }
    const cover = image.length > 0 ? image : (albums.length > 0 ? albums[0].coverUrl : '');
    return new ArtistDetail(
      artistId,
      jStr(json, 'name'),
      cover,
      bio,
      jInt(json, 'albumCount', albums.length),
      albums,
      trackCount,
    );
  }

  async artistTracks(artistId: number, page: number = 1, pageSize: number = 50): Promise<PageData<Track>> {
    let all = this.artistAlbumSongs.get(artistId);
    if (all === undefined) {
      const detail = await this.artistDetail(artistId);
      const tracks: Track[] = [];
      for (let i = 0; i < detail.albums.length; i += 4) {
        const chunk = detail.albums.slice(i, i + 4);
        const details: AlbumDetail[] = await Promise.all(
          chunk.map((album: Album): Promise<AlbumDetail> => this.albumDetail(album.id)));
        for (const albumDetail of details) {
          tracks.push(...albumDetail.tracks);
        }
      }
      all = tracks;
      this.artistAlbumSongs.set(artistId, all);
    }
    const total = all.length;
    const start = (page - 1) * pageSize;
    const items = all.slice(start, start + pageSize);
    return pageOf(items, page, pageSize, total);
  }

  async lyrics(trackId: number): Promise<string> {
    const client = SubsonicClient.fromSession();
    const raw = this.rawId(trackId);
    try {
      const sub = await client.call('getLyricsBySongId', mapParams([['id', raw]]));
      const list = jObj(sub, 'lyricsList');
      if (list !== null) {
        const structured = objList(list, 'structuredLyrics');
        if (structured.length > 0) {
          const lines = objList(structured[0], 'line');
          if (lines.length > 0) {
            let out = '';
            for (const line of lines) {
              const start = jInt(line, 'start');
              const value = jStr(line, 'value');
              const minutes = Math.floor(start / 60000);
              const seconds = Math.floor((start % 60000) / 1000);
              const centis = Math.floor((start % 1000) / 10);
              out += `[${minutes < 10 ? '0' : ''}${minutes}:${seconds < 10 ? '0' : ''}${seconds}.` +
                `${centis < 10 ? '0' : ''}${centis}]${value}\n`;
            }
            return out;
          }
          const value = jStr(structured[0], 'value');
          if (value.length > 0) {
            return value;
          }
        }
      }
    } catch (err) {
    }
    try {
      const song = await client.call('getSong', mapParams([['id', raw]]));
      const json = jObj(song, 'song');
      if (json !== null) {
        const sub = await client.call('getLyrics', mapParams([
          ['artist', jStr(json, 'artist')],
          ['title', jStr(json, 'title')],
        ]));
        const lyrics = jObj(sub, 'lyrics');
        if (lyrics !== null) {
          return jStr(lyrics, 'value', jStr(lyrics, 'lyrics'));
        }
      }
    } catch (err) {
    }
    return '';
  }

  async comments(trackId: number, page: number = 1, pageSize: number = 50): Promise<CommentsPage> {
    return new CommentsPage([], 0);
  }

  async postComment(trackId: number, content: string): Promise<void> {
    throw new ApiException(0, '该服务不支持评论');
  }

  async playlists(): Promise<Playlist[]> {
    const client = SubsonicClient.fromSession();
    const sub = await client.call('getPlaylists');
    const root = jObj(sub, 'playlists');
    if (root === null) {
      return [];
    }
    return objList(root, 'playlist').map((item: JObj): Playlist => this.toPlaylist(client, item));
  }

  async playlistDetail(playlistId: number): Promise<PlaylistDetail> {
    const client = SubsonicClient.fromSession();
    const sub = await client.call('getPlaylist', mapParams([['id', this.rawId(playlistId)]]));
    const json = jObj(sub, 'playlist');
    if (json === null) {
      throw new ApiException(0, '歌单不存在');
    }
    const tracks = objList(json, 'entry').map((item: JObj): Track => this.toTrack(client, item));
    return new PlaylistDetail(
      playlistId,
      jStr(json, 'name'),
      this.coverUrl(client, jStr(json, 'coverArt')),
      tracks,
    );
  }

  async createPlaylist(name: string): Promise<Playlist> {
    const client = SubsonicClient.fromSession();
    const sub = await client.call('createPlaylist', mapParams([['name', name.trim()]]));
    const json = jObj(sub, 'playlist');
    if (json !== null) {
      return this.toPlaylist(client, json);
    }
    const all = await this.playlists();
    for (let i = all.length - 1; i >= 0; i--) {
      if (all[i].name === name.trim()) {
        return all[i];
      }
    }
    return new Playlist(0, name.trim(), 0, '');
  }

  async renamePlaylist(playlistId: number, name: string): Promise<Playlist> {
    const client = SubsonicClient.fromSession();
    await client.call('updatePlaylist', mapParams([
      ['playlistId', this.rawId(playlistId)],
      ['name', name.trim()],
    ]));
    const sub = await client.call('getPlaylist', mapParams([['id', this.rawId(playlistId)]]));
    const json = jObj(sub, 'playlist');
    if (json !== null) {
      return this.toPlaylist(client, json);
    }
    return new Playlist(playlistId, name.trim(), 0, '');
  }

  async deletePlaylist(playlistId: number): Promise<void> {
    const client = SubsonicClient.fromSession();
    await client.call('deletePlaylist', mapParams([['id', this.rawId(playlistId)]]));
  }

  async reorderPlaylists(listIds: number[]): Promise<void> {
    throw new ApiException(0, '该服务不支持歌单排序');
  }

  async reorderPlaylistTracks(playlistId: number, trackIds: number[]): Promise<void> {
    throw new ApiException(0, '该服务不支持歌单内排序');
  }

  async addTracksToPlaylist(playlistId: number, trackIds: number[]): Promise<void> {
    const client = SubsonicClient.fromSession();
    for (const trackId of trackIds) {
      await client.call('updatePlaylist', mapParams([
        ['playlistId', this.rawId(playlistId)],
        ['songIdToAdd', this.rawId(trackId)],
      ]));
    }
  }

  async removeTracksFromPlaylist(playlistId: number, trackIds: number[]): Promise<void> {
    const client = SubsonicClient.fromSession();
    const sub = await client.call('getPlaylist', mapParams([['id', this.rawId(playlistId)]]));
    const json = jObj(sub, 'playlist');
    if (json === null) {
      return;
    }
    const entries = objList(json, 'entry');
    const removeSet: Set<string> = new Set<string>();
    for (const trackId of trackIds) {
      removeSet.add(this.rawId(trackId));
    }
    const indices: number[] = [];
    for (let i = 0; i < entries.length; i++) {
      if (removeSet.has(jStr(entries[i], 'id'))) {
        indices.push(i);
      }
    }
    indices.sort((a: number, b: number): number => b - a);
    for (const index of indices) {
      await client.call('updatePlaylist', mapParams([
        ['playlistId', this.rawId(playlistId)],
        ['songIndexToRemove', String(index)],
      ]));
    }
  }

  async search(query: string): Promise<SearchResults> {
    const client = SubsonicClient.fromSession();
    const sub = await client.call('search3', mapParams([
      ['query', query],
      ['albumCount', '24'],
      ['songCount', '30'],
    ]));
    const root = jObj(sub, 'searchResult3');
    if (root === null) {
      return new SearchResults([], [], 0);
    }
    const albums = objList(root, 'album').map((item: JObj): Album => this.toAlbum(client, item));
    const tracks = objList(root, 'song').map((item: JObj): Track => this.toTrack(client, item));
    return new SearchResults(albums, tracks, tracks.length);
  }

  async searchTracks(query: string, page: number, pageSize: number = 30): Promise<PageData<Track>> {
    const client = SubsonicClient.fromSession();
    const sub = await client.call('search3', mapParams([
      ['query', query],
      ['songCount', String(pageSize)],
      ['songOffset', String((page - 1) * pageSize)],
    ]));
    const root = jObj(sub, 'searchResult3');
    const items = root !== null
      ? objList(root, 'song').map((item: JObj): Track => this.toTrack(client, item)) : [];
    const full = items.length >= pageSize;
    const total = (page - 1) * pageSize + items.length + (full ? 1 : 0);
    return new PageData<Track>(items, total, page, pageSize, full ? page + 1 : page);
  }

  async login(baseUrl: string, account: string, password: string): Promise<User | null> {
    Session.setProviderKind(PROVIDER_SUBSONIC);
    const normalized = Session.normalizeBase(baseUrl, PROVIDER_SUBSONIC);
    if (normalized.length === 0) {
      throw new ApiException(0, '请填写服务器地址');
    }
    Session.setBaseUrl(normalized);
    const username = account.trim();
    const salt = newSalt();
    const token = md5Hex(password + salt);
    const client = new SubsonicClient(normalized, username, salt, token);
    await client.call('ping');
    let user: User | null = null;
    try {
      const sub = await client.call('getUser', mapParams([['username', username]]));
      const json = jObj(sub, 'user');
      if (json !== null) {
        const name = jStr(json, 'username', username);
        user = new User(name, name, name, '', jBool(json, 'adminRole') ? 'admin' : 'user');
      }
    } catch (err) {
    }
    if (user === null) {
      user = new User(username, username, username, '', 'user');
    }
    this.resetIds();
    Session.saveSubsonicLogin(username, salt, token, user);
    return user;
  }

  async guest(baseUrl: string): Promise<void> {
    Session.setProviderKind(PROVIDER_SUBSONIC);
    const normalized = Session.normalizeBase(baseUrl, PROVIDER_SUBSONIC);
    if (normalized.length === 0) {
      throw new ApiException(0, '请填写服务器地址');
    }
    Session.setBaseUrl(normalized);
    const client = new SubsonicClient(normalized, 'guest', '', '');
    await client.call('ping');
    this.resetIds();
    Session.enterGuest();
  }

  async register(baseUrl: string, username: string, password: string, nickname: string): Promise<User | null> {
    throw new ApiException(0, '该服务不支持注册');
  }

  async logout(): Promise<void> {
    Session.clear();
    this.resetIds();
  }
}
