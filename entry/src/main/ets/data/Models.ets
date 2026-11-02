import { JObj, JArr, jObj, jArr, jObjAt, jInt, jDouble, jBool, jStr, isNull } from './Json';

export class Album {
  readonly id: number;
  readonly artistId: number;
  readonly title: string;
  readonly coverUrl: string;
  readonly artistName: string;
  readonly type: string;
  readonly releaseDate: string;
  readonly year: number | null;
  readonly score: number | null;
  readonly trackCount: number;
  readonly description: string;
  readonly tags: string[];
  readonly externalId: string | null;
  readonly artists: ArtistRef[];

  constructor(id: number, artistId: number, title: string, coverUrl: string, artistName: string,
    type: string, releaseDate: string, year: number | null, score: number | null,
    trackCount: number, description: string, tags: string[], externalId: string | null = null,
    artists: ArtistRef[] = []) {
    this.id = id;
    this.artistId = artistId;
    this.title = title;
    this.coverUrl = coverUrl;
    this.artistName = artistName;
    this.type = type;
    this.releaseDate = releaseDate;
    this.year = year;
    this.score = score;
    this.trackCount = trackCount;
    this.description = description;
    this.tags = tags;
    this.externalId = externalId;
    this.artists = artists;
  }

  /** 有专辑级艺人时按录入顺序显示，否则回退到主艺人。 */
  get artistLabel(): string {
    if (this.artists.length > 0) {
      const names: string[] = [];
      for (const artist of this.artists) {
        if (artist.name.length > 0) {
          names.push(artist.name);
        }
      }
      if (names.length > 0) {
        return names.join(' / ');
      }
    }
    return this.artistName;
  }

  get typeLabel(): string {
    switch (this.type) {
      case 'ep':
        return '迷你专辑';
      case 'single':
        return '单曲';
      case 'compilation':
        return '合辑';
      case 'ost':
        return '原声';
      default:
        return '专辑';
    }
  }

  get metaLine(): string {
    const parts: string[] = [];
    if (this.artistLabel.length > 0) {
      parts.push(this.artistLabel);
    }
    if (this.year !== null) {
      parts.push(String(this.year));
    }
    parts.push(`${this.trackCount} 首`);
    return parts.join(' · ');
  }
}

export class ArtistRef {
  readonly id: number;
  readonly name: string;

  constructor(id: number, name: string) {
    this.id = id;
    this.name = name;
  }
}

export class Track {
  readonly id: number;
  readonly albumId: number;
  readonly albumTitle: string;
  readonly artistId: number;
  readonly artistName: string;
  readonly coverUrl: string;
  readonly title: string;
  readonly audioUrl: string;
  readonly durationSec: number;
  readonly orderIndex: number;
  readonly hasLyrics: boolean;
  readonly commentCount: number;
  readonly artists: ArtistRef[];

  constructor(id: number, albumId: number, albumTitle: string, artistId: number, artistName: string,
    coverUrl: string, title: string, audioUrl: string, durationSec: number, orderIndex: number,
    hasLyrics: boolean, commentCount: number, artists: ArtistRef[] = []) {
    this.id = id;
    this.albumId = albumId;
    this.albumTitle = albumTitle;
    this.artistId = artistId;
    this.artistName = artistName;
    this.coverUrl = coverUrl;
    this.title = title;
    this.audioUrl = audioUrl;
    this.durationSec = durationSec;
    this.orderIndex = orderIndex;
    this.hasLyrics = hasLyrics;
    this.commentCount = commentCount;
    this.artists = artists;
  }

  /** 有歌曲级艺人时按录入顺序显示，否则回退到专辑艺人。 */
  get artistLabel(): string {
    if (this.artists.length > 0) {
      const names: string[] = [];
      for (const artist of this.artists) {
        if (artist.name.length > 0) {
          names.push(artist.name);
        }
      }
      if (names.length > 0) {
        return names.join(' / ');
      }
    }
    return this.artistName;
  }

  /** 歌曲级艺人优先用于艺人页跳转；老数据回退到专辑艺人。 */
  get primaryArtistId(): number {
    for (const artist of this.artists) {
      if (artist.id > 0) {
        return artist.id;
      }
    }
    return this.artistId;
  }

  get durationMs(): number {
    return Math.trunc(this.durationSec * 1000);
  }
}

export class Playlist {
  readonly id: number;
  readonly name: string;
  readonly count: number;
  readonly coverUrl: string;

  constructor(id: number, name: string, count: number, coverUrl: string) {
    this.id = id;
    this.name = name;
    this.count = count;
    this.coverUrl = coverUrl;
  }
}

export class AlbumDetail {
  readonly album: Album;
  readonly tracks: Track[];

  constructor(album: Album, tracks: Track[]) {
    this.album = album;
    this.tracks = tracks;
  }
}

export class PlaylistDetail {
  readonly id: number;
  readonly name: string;
  readonly coverUrl: string;
  readonly tracks: Track[];

  constructor(id: number, name: string, coverUrl: string, tracks: Track[]) {
    this.id = id;
    this.name = name;
    this.coverUrl = coverUrl;
    this.tracks = tracks;
  }

  withTracks(tracks: Track[]): PlaylistDetail {
    return new PlaylistDetail(this.id, this.name, this.coverUrl, tracks);
  }
}

export class HomeData {
  readonly featured: Album[];
  readonly recommended: Album[];
  readonly latest: Track[];
  readonly ranking: Album[];

  constructor(featured: Album[], recommended: Album[], latest: Track[], ranking: Album[]) {
    this.featured = featured;
    this.recommended = recommended;
    this.latest = latest;
    this.ranking = ranking;
  }
}

export class PageData<T> {
  readonly items: T[];
  readonly total: number;
  readonly page: number;
  readonly pageSize: number;
  readonly totalPages: number;

  constructor(items: T[], total: number, page: number, pageSize: number, totalPages: number) {
    this.items = items;
    this.total = total;
    this.page = page;
    this.pageSize = pageSize;
    this.totalPages = totalPages;
  }
}

export class SearchResults {
  readonly albums: Album[];
  readonly tracks: Track[];
  readonly tracksTotal: number;

  constructor(albums: Album[], tracks: Track[], tracksTotal: number = 0) {
    this.albums = albums;
    this.tracks = tracks;
    this.tracksTotal = tracksTotal;
  }
}

export class ArtistDetail {
  readonly id: number;
  readonly name: string;
  readonly coverUrl: string;
  readonly bio: string;
  readonly albumCount: number;
  readonly trackCount: number;
  readonly albums: Album[];

  constructor(id: number, name: string, coverUrl: string, bio: string, albumCount: number,
    albums: Album[], trackCount: number = 0) {
    this.id = id;
    this.name = name;
    this.coverUrl = coverUrl;
    this.bio = bio;
    this.albumCount = albumCount;
    this.albums = albums;
    this.trackCount = trackCount;
  }
}

export class CommentItem {
  readonly id: number;
  readonly parentId: number | null;
  readonly content: string;
  readonly createdAt: string;
  readonly author: string;
  readonly avatarUrl: string;
  readonly replies: CommentItem[];

  constructor(id: number, parentId: number | null, content: string, createdAt: string,
    author: string, avatarUrl: string, replies: CommentItem[]) {
    this.id = id;
    this.parentId = parentId;
    this.content = content;
    this.createdAt = createdAt;
    this.author = author;
    this.avatarUrl = avatarUrl;
    this.replies = replies;
  }
}

export class CommentsPage {
  readonly items: CommentItem[];
  readonly total: number;

  constructor(items: CommentItem[], total: number) {
    this.items = items;
    this.total = total;
  }
}

export function parseAlbum(json: JObj): Album {
  const artist = jObj(json, 'artist');
  const tags: string[] = [];
  const tagArray = jArr(json, 'tags');
  for (let i = 0; i < tagArray.length; i++) {
    const tag = tagArray[i];
    if (typeof tag === 'string' && tag.length > 0) {
      tags.push(tag);
    }
  }
  const artists: ArtistRef[] = [];
  const artistArray = jArr(json, 'artists');
  for (let i = 0; i < artistArray.length; i++) {
    const item = jObjAt(artistArray, i);
    if (item === null) {
      continue;
    }
    const name = jStr(item, 'name');
    if (name.length > 0) {
      artists.push(new ArtistRef(jInt(item, 'id'), name));
    }
  }
  return new Album(
    jInt(json, 'id'),
    artist !== null ? jInt(artist, 'id') : jInt(json, 'artist_id'),
    jStr(json, 'title'),
    jStr(json, 'cover_url'),
    artist !== null ? jStr(artist, 'name') : '',
    jStr(json, 'album_type', 'album'),
    jStr(json, 'release_date'),
    isNull(json, 'release_year') ? null : jInt(json, 'release_year'),
    isNull(json, 'score') ? null : jDouble(json, 'score', NaN),
    jInt(json, 'track_count'),
    jStr(json, 'description'),
    tags,
    isNull(json, 'external_id') ? null : jStr(json, 'external_id'),
    artists,
  );
}

export function parseTrack(json: JObj, parent?: Album): Track {
  const albumJson = jObj(json, 'album');
  let album: Album | null = (parent === undefined) ? null : parent;
  if (album === null && albumJson !== null) {
    album = parseAlbum(albumJson);
  }
  const duration = isNull(json, 'duration_sec') ? 0.0 : jDouble(json, 'duration_sec', 0.0);
  const artists: ArtistRef[] = [];
  const artistArray = jArr(json, 'artists');
  for (let i = 0; i < artistArray.length; i++) {
    const item = jObjAt(artistArray, i);
    if (item === null) {
      continue;
    }
    const name = jStr(item, 'name');
    if (name.length > 0) {
      artists.push(new ArtistRef(jInt(item, 'id'), name));
    }
  }
  return new Track(
    jInt(json, 'id'),
    album !== null ? jInt(json, 'album_id', album.id) : jInt(json, 'album_id'),
    album !== null ? album.title : '',
    album !== null ? album.artistId : 0,
    album !== null ? album.artistName : '',
    album !== null ? album.coverUrl : '',
    jStr(json, 'title'),
    jStr(json, 'audio_url'),
    duration,
    jInt(json, 'order_index'),
    jBool(json, 'has_lyrics', false),
    jInt(json, 'comment_count'),
    artists,
  );
}

export function parsePlaylist(json: JObj): Playlist {
  return new Playlist(
    jInt(json, 'id'),
    jStr(json, 'name'),
    jInt(json, 'count'),
    jStr(json, 'cover_url'),
  );
}

export function parseAlbumPage(data: JObj): PageData<Album> {
  const items: Album[] = [];
  const array = jArr(data, 'items');
  for (let i = 0; i < array.length; i++) {
    const item = jObjAt(array, i);
    if (item !== null) {
      items.push(parseAlbum(item));
    }
  }
  return new PageData<Album>(
    items,
    jInt(data, 'total'),
    jInt(data, 'page', 1),
    jInt(data, 'page_size', items.length >= 1 ? items.length : 1),
    jInt(data, 'total_pages', 1),
  );
}

export function parseTrackPage(data: JObj): PageData<Track> {
  const items: Track[] = [];
  const array = jArr(data, 'items');
  for (let i = 0; i < array.length; i++) {
    const item = jObjAt(array, i);
    if (item !== null) {
      items.push(parseTrack(item));
    }
  }
  return new PageData<Track>(
    items,
    jInt(data, 'total'),
    jInt(data, 'page', 1),
    jInt(data, 'page_size', items.length >= 1 ? items.length : 1),
    jInt(data, 'total_pages', 1),
  );
}

export function albumList(array: JArr): Album[] {
  const items: Album[] = [];
  for (let i = 0; i < array.length; i++) {
    const item = jObjAt(array, i);
    if (item !== null) {
      items.push(parseAlbum(item));
    }
  }
  return items;
}

export function playlistList(array: JArr): Playlist[] {
  const items: Playlist[] = [];
  for (let i = 0; i < array.length; i++) {
    const item = jObjAt(array, i);
    if (item !== null) {
      items.push(parsePlaylist(item));
    }
  }
  return items;
}

export function parseArtist(json: JObj): ArtistDetail {
  const albums: Album[] = [];
  const array = jArr(json, 'albums');
  for (let i = 0; i < array.length; i++) {
    const item = jObjAt(array, i);
    if (item !== null) {
      albums.push(parseAlbum(item));
    }
  }
  return new ArtistDetail(
    jInt(json, 'id'),
    jStr(json, 'name'),
    jStr(json, 'cover_url'),
    jStr(json, 'bio'),
    jInt(json, 'album_count', albums.length),
    albums,
    jInt(json, 'track_count', 0),
  );
}

function parseComment(json: JObj): CommentItem {
  const replies: CommentItem[] = [];
  const array = jArr(json, 'replies');
  for (let i = 0; i < array.length; i++) {
    const item = jObjAt(array, i);
    if (item !== null) {
      replies.push(parseComment(item));
    }
  }
  return new CommentItem(
    jInt(json, 'id'),
    isNull(json, 'parent_id') ? null : jInt(json, 'parent_id'),
    jStr(json, 'content'),
    jStr(json, 'created_at'),
    jStr(json, 'author', '听众'),
    jStr(json, 'author_avatar'),
    replies,
  );
}

export function parseComments(data: JObj): CommentsPage {
  const items: CommentItem[] = [];
  const array = jArr(data, 'items');
  for (let i = 0; i < array.length; i++) {
    const item = jObjAt(array, i);
    if (item !== null) {
      items.push(parseComment(item));
    }
  }
  return new CommentsPage(items, jInt(data, 'total', items.length));
}

export function intIds(array: JArr): number[] {
  const ids: number[] = [];
  for (let i = 0; i < array.length; i++) {
    const v = array[i];
    if (typeof v === 'number') {
      ids.push(v);
    }
  }
  return ids;
}

export type JArrAlias = JArr;
export type JObjAlias = JObj;
