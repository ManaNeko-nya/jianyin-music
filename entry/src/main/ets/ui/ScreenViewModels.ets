import { Session, User } from '../data/Session';
import { MusicRepository } from '../data/MusicRepository';
import {
  Album, Track, Playlist, AlbumDetail, PlaylistDetail, HomeData, PageData, SearchResults,
  ArtistDetail, CommentItem, CommentsPage,
} from '../data/Models';
import { LyricLine, parseLrc } from '../data/Lyrics';
import { LoadState, Loading, Success, LoadError } from './Components';
import { errText } from '../data/Json';
import { ProviderKind } from '../data/ProviderTypes';

@ObservedV2
export class HomeViewModel {
  @Trace state: LoadState<HomeData> = new Loading<HomeData>();

  constructor() {
    this.load();
  }

  load(): void {
    MusicRepository.home().then((data: HomeData): void => {
      this.state = new Success<HomeData>(data);
    }).catch((err: Object): void => {
      this.state = new LoadError<HomeData>(errText(err, '加载失败'));
    });
  }
}

@ObservedV2
export class LibraryData {
  @Trace songs: PageData<Track>;
  @Trace albums: PageData<Album>;
  @Trace loadingMoreSongs: boolean = false;
  @Trace loadingMoreAlbums: boolean = false;

  constructor(songs: PageData<Track>, albums: PageData<Album>) {
    this.songs = songs;
    this.albums = albums;
  }

  get hasMoreSongs(): boolean {
    return this.songs.items.length < this.songs.total;
  }

  get hasMoreAlbums(): boolean {
    return this.albums.items.length < this.albums.total;
  }
}

const SONGS_PAGE_SIZE = 50;
const ALBUMS_PAGE_SIZE = 30;

@ObservedV2
export class LibraryViewModel {
  @Trace state: LoadState<LibraryData> = new Loading<LibraryData>();

  constructor() {
    this.load();
  }

  load(): void {
    const songsPromise = MusicRepository.trackPage(1, SONGS_PAGE_SIZE);
    const albumsPromise = MusicRepository.albumPage(1, ALBUMS_PAGE_SIZE);
    songsPromise.then((songs: PageData<Track>): void => {
      albumsPromise.then((albums: PageData<Album>): void => {
        this.state = new Success<LibraryData>(new LibraryData(songs, albums));
      }).catch((err: Object): void => {
        this.state = new LoadError<LibraryData>(errText(err, '加载失败'));
      });
    }).catch((err: Object): void => {
      this.state = new LoadError<LibraryData>(errText(err, '加载失败'));
    });
  }

  /** 曲库歌曲自动翻页；已加载数量达到总数后不再请求。 */
  loadMoreSongs(): void {
    const current = this.state;
    if (!(current instanceof Success)) {
      return;
    }
    const data = (current as Success<LibraryData>).data;
    if (data.loadingMoreSongs || !data.hasMoreSongs) {
      return;
    }
    data.loadingMoreSongs = true;
    const nextPage = data.songs.page + 1;
    MusicRepository.trackPage(nextPage, SONGS_PAGE_SIZE).then((next: PageData<Track>): void => {
      const now = this.state;
      if (!(now instanceof Success)) {
        return;
      }
      const nowData = (now as Success<LibraryData>).data;
      nowData.songs = new PageData<Track>(
        nowData.songs.items.concat(next.items),
        next.total, next.page, next.pageSize, next.totalPages);
      nowData.loadingMoreSongs = false;
    }).catch((_err: Object): void => {
      const now = this.state;
      if (now instanceof Success) {
        (now as Success<LibraryData>).data.loadingMoreSongs = false;
      }
    });
  }

  /** 曲库专辑自动翻页。 */
  loadMoreAlbums(): void {
    const current = this.state;
    if (!(current instanceof Success)) {
      return;
    }
    const data = (current as Success<LibraryData>).data;
    if (data.loadingMoreAlbums || !data.hasMoreAlbums) {
      return;
    }
    data.loadingMoreAlbums = true;
    const nextPage = data.albums.page + 1;
    MusicRepository.albumPage(nextPage, ALBUMS_PAGE_SIZE).then((next: PageData<Album>): void => {
      const now = this.state;
      if (!(now instanceof Success)) {
        return;
      }
      const nowData = (now as Success<LibraryData>).data;
      nowData.albums = new PageData<Album>(
        nowData.albums.items.concat(next.items),
        next.total, next.page, next.pageSize, next.totalPages);
      nowData.loadingMoreAlbums = false;
    }).catch((_err: Object): void => {
      const now = this.state;
      if (now instanceof Success) {
        (now as Success<LibraryData>).data.loadingMoreAlbums = false;
      }
    });
  }
}

@ObservedV2
export class AlbumViewModel {
  @Trace state: LoadState<AlbumDetail> = new Loading<AlbumDetail>();

  constructor(albumId: number) {
    MusicRepository.albumDetail(albumId).then((data: AlbumDetail): void => {
      this.state = new Success<AlbumDetail>(data);
    }).catch((err: Object): void => {
      this.state = new LoadError<AlbumDetail>(errText(err, '加载失败'));
    });
  }

  load(albumId: number): void {
    this.state = new Loading<AlbumDetail>();
    MusicRepository.albumDetail(albumId).then((data: AlbumDetail): void => {
      this.state = new Success<AlbumDetail>(data);
    }).catch((err: Object): void => {
      this.state = new LoadError<AlbumDetail>(errText(err, '加载失败'));
    });
  }
}

@ObservedV2
export class ArtistViewModel {
  @Trace state: LoadState<ArtistDetail> = new Loading<ArtistDetail>();

  constructor(artistId: number) {
    MusicRepository.artistDetail(artistId).then((data: ArtistDetail): void => {
      this.state = new Success<ArtistDetail>(data);
    }).catch((err: Object): void => {
      this.state = new LoadError<ArtistDetail>(errText(err, '加载失败'));
    });
  }

  load(artistId: number): void {
    this.state = new Loading<ArtistDetail>();
    MusicRepository.artistDetail(artistId).then((data: ArtistDetail): void => {
      this.state = new Success<ArtistDetail>(data);
    }).catch((err: Object): void => {
      this.state = new LoadError<ArtistDetail>(errText(err, '加载失败'));
    });
  }
}

@ObservedV2
export class ArtistTracksViewModel {
  @Trace loading: boolean = true;
  @Trace loadingMore: boolean = false;
  @Trace error: string = '';
  @Trace items: Track[] = [];
  @Trace total: number = 0;
  @Trace hasMore: boolean = false;
  private page: number = 1;
  private artistId: number = 0;

  constructor(artistId: number) {
    this.artistId = artistId;
  }

  reload(): void {
    this.load(this.artistId);
  }

  load(artistId: number): void {
    this.artistId = artistId;
    this.page = 1;
    this.loading = true;
    this.error = '';
    this.items = [];
    this.total = 0;
    this.hasMore = false;
    MusicRepository.artistTracks(artistId, 1).then((data: PageData<Track>): void => {
      this.items = data.items;
      this.total = data.total;
      this.page = data.page;
      this.hasMore = data.page < data.totalPages;
      this.loading = false;
    }).catch((err: Object): void => {
      this.error = errText(err, '加载歌曲失败');
      this.loading = false;
    });
  }

  loadMore(): void {
    if (this.loadingMore || !this.hasMore) {
      return;
    }
    this.loadingMore = true;
    MusicRepository.artistTracks(this.artistId, this.page + 1).then((data: PageData<Track>): void => {
      this.items = this.items.concat(data.items);
      this.total = data.total;
      this.page = data.page;
      this.hasMore = data.page < data.totalPages;
      this.loadingMore = false;
    }).catch((err: Object): void => {
      this.error = errText(err, '加载歌曲失败');
      this.loadingMore = false;
    });
  }
}

@ObservedV2
export class PlaylistsViewModel {
  @Trace state: LoadState<Playlist[]> = new Loading<Playlist[]>();

  load(keepData: boolean = false): void {
    if (!Session.loggedIn) {
      this.state = new Success<Playlist[]>([]);
      return;
    }
    const previous = this.state;
    if (!keepData || !(previous instanceof Success)) {
      this.state = new Loading<Playlist[]>();
    }
    MusicRepository.playlists().then((data: Playlist[]): void => {
      this.state = new Success<Playlist[]>(data);
    }).catch((err: Object): void => {
      // 静默刷新失败时保留原列表，避免清空当前内容。
      if (!keepData || !(previous instanceof Success)) {
        this.state = new LoadError<Playlist[]>(errText(err, '加载失败'));
      }
    });
  }

  create(name: string, onResult: (error: string | null) => void): void {
    const trimmed = name.trim();
    if (trimmed.length === 0) {
      onResult('歌单名称不能为空');
      return;
    }
    MusicRepository.createPlaylist(trimmed).then((_p: Playlist): void => {
      onResult(null);
      this.load(true);
    }).catch((err: Object): void => {
      onResult(errText(err, '创建歌单失败'));
    });
  }

  /** 采纳拖拽后的完整顺序：数据源是唯一真相，避免同一次移动被应用两遍。 */
  applyOrder(items: Playlist[]): void {
    const current = this.state;
    if (!(current instanceof Success)) {
      return;
    }
    if (items.length !== (current as Success<Playlist[]>).data.length) {
      return;
    }
    this.state = new Success<Playlist[]>(items);
  }

  saveOrder(onResult: (error: string | null) => void): void {
    const current = this.state;
    if (!(current instanceof Success)) {
      return;
    }
    const items = (current as Success<Playlist[]>).data;
    if (items.length === 0) {
      return;
    }
    MusicRepository.reorderPlaylists(items.map((p: Playlist): number => p.id)).then((): void => {
      onResult(null);
    }).catch((err: Object): void => {
      onResult(errText(err, '保存歌单顺序失败'));
      this.load(true);
    });
  }
}

@ObservedV2
export class PlaylistViewModel {
  @Trace state: LoadState<PlaylistDetail> = new Loading<PlaylistDetail>();
  private playlistId: number;

  constructor(playlistId: number) {
    this.playlistId = playlistId;
    this.load(false);
  }

  load(keepData: boolean = false): void {
    const previous = this.state;
    if (!keepData || !(previous instanceof Success)) {
      this.state = new Loading<PlaylistDetail>();
    }
    MusicRepository.playlistDetail(this.playlistId).then((data: PlaylistDetail): void => {
      this.state = new Success<PlaylistDetail>(data);
    }).catch((err: Object): void => {
      // 静默刷新失败时保留原内容，避免列表清空、滚动位置丢失。
      if (!keepData || !(previous instanceof Success)) {
        this.state = new LoadError<PlaylistDetail>(errText(err, '加载失败'));
      }
    });
  }

  rename(name: string, onResult: (error: string | null) => void): void {
    const trimmed = name.trim();
    if (trimmed.length === 0) {
      onResult('歌单名称不能为空');
      return;
    }
    MusicRepository.renamePlaylist(this.playlistId, trimmed).then((_p: Playlist): void => {
      onResult(null);
      this.load(true);
    }).catch((err: Object): void => {
      onResult(errText(err, '重命名失败'));
    });
  }

  delete(onResult: (error: string | null) => void): void {
    MusicRepository.deletePlaylist(this.playlistId).then((): void => {
      onResult(null);
    }).catch((err: Object): void => {
      onResult(errText(err, '删除歌单失败'));
    });
  }

  /** 采纳拖拽后的完整顺序：数据源是唯一真相，避免同一次移动被应用两遍。 */
  applyTrackOrder(tracks: Track[]): void {
    const current = this.state;
    if (!(current instanceof Success)) {
      return;
    }
    const detail = (current as Success<PlaylistDetail>).data;
    if (tracks.length !== detail.tracks.length) {
      return;
    }
    this.state = new Success<PlaylistDetail>(detail.withTracks(tracks));
  }

  saveTrackOrder(onResult: (error: string | null) => void): void {
    const current = this.state;
    if (!(current instanceof Success)) {
      return;
    }
    const detail = (current as Success<PlaylistDetail>).data;
    if (detail.tracks.length === 0) {
      return;
    }
    MusicRepository.reorderPlaylistTracks(this.playlistId,
      detail.tracks.map((t: Track): number => t.id)).then((): void => {
      onResult(null);
    }).catch((err: Object): void => {
      onResult(errText(err, '保存歌曲顺序失败'));
      this.load(true);
    });
  }
}

@ObservedV2
export class SearchFormState {
  @Trace query: string = '';
  @Trace results: SearchResults | null = null;
  @Trace error: string = '';
  @Trace loading: boolean = false;
  @Trace loadingMore: boolean = false;
  @Trace hasMoreTracks: boolean = false;
}

const SEARCH_PAGE_SIZE = 30;

@ObservedV2
export class SearchViewModel {
  @Trace state: SearchFormState = new SearchFormState();
  private debounceTimer: number = -1;

  updateQuery(query: string): void {
    this.state.query = query;
    if (this.debounceTimer >= 0) {
      clearTimeout(this.debounceTimer);
    }
    this.debounceTimer = setTimeout((): void => {
      this.debounceTimer = -1;
      this.search();
    }, 350);
  }

  search(): void {
    const query = this.state.query.trim();
    if (query.length === 0) {
      this.state.results = null;
      this.state.error = '';
      this.state.loading = false;
      this.state.hasMoreTracks = false;
      return;
    }
    this.state.loading = true;
    this.state.error = '';
    this.state.hasMoreTracks = false;
    MusicRepository.search(query).then((result: SearchResults): void => {
      this.state.loading = false;
      this.state.results = result;
      this.state.hasMoreTracks = result.tracks.length < result.tracksTotal;
    }).catch((err: Object): void => {
      this.state.loading = false;
      this.state.error = errText(err, '搜索失败');
    });
  }

  /** 搜索结果自动翻页：一次只追加一页歌曲，专辑结果不分页。 */
  loadMore(): void {
    const results = this.state.results;
    if (results === null) {
      return;
    }
    const query = this.state.query.trim();
    if (query.length === 0 || this.state.loading || this.state.loadingMore || !this.state.hasMoreTracks) {
      return;
    }
    const nextPage = Math.floor(results.tracks.length / SEARCH_PAGE_SIZE) + 1;
    this.state.loadingMore = true;
    MusicRepository.searchTracks(query, nextPage).then((page: PageData<Track>): void => {
      const base = this.state.results;
      if (base === null) {
        return;
      }
      const merged = base.tracks.concat(page.items);
      this.state.results = new SearchResults(base.albums, merged, base.tracksTotal);
      this.state.loadingMore = false;
      this.state.hasMoreTracks = merged.length < page.total;
    }).catch((_err: Object): void => {
      this.state.loadingMore = false;
    });
  }
}

@ObservedV2
export class AuthFormState {
  @Trace loading: boolean = false;
  @Trace error: string = '';
}

@ObservedV2
export class ProfileViewModel {
  @Trace state: AuthFormState = new AuthFormState();

  login(providerKind: ProviderKind, baseUrl: string, account: string, password: string): void {
    this.state.loading = true;
    this.state.error = '';
    MusicRepository.login(providerKind, baseUrl, account, password).then((_u: User | null): void => {
      this.state = new AuthFormState();
    }).catch((err: Object): void => {
      const state = new AuthFormState();
      state.error = errText(err, '登录失败');
      this.state = state;
    });
  }

  async guest(providerKind: ProviderKind, baseUrl: string): Promise<boolean> {
    this.state.loading = true;
    this.state.error = '';
    try {
      await MusicRepository.guest(providerKind, baseUrl);
      this.state = new AuthFormState();
      return true;
    } catch (err) {
      const state = new AuthFormState();
      state.error = errText(err, '游客模式连接失败');
      this.state = state;
      return false;
    }
  }

  register(baseUrl: string, username: string, password: string, nickname: string): void {
    this.state.loading = true;
    this.state.error = '';
    MusicRepository.register(baseUrl, username, password, nickname).then((_u: User | null): void => {
      this.state = new AuthFormState();
    }).catch((err: Object): void => {
      const state = new AuthFormState();
      state.error = errText(err, '注册失败');
      this.state = state;
    });
  }

  logout(): void {
    MusicRepository.logout();
  }

  clearError(): void {
    this.state.error = '';
  }
}

@ObservedV2
export class LyricsUiState {
  @Trace trackId: number = 0;
  @Trace loading: boolean = false;
  @Trace loaded: boolean = false;
  @Trace lines: LyricLine[] = [];
  @Trace error: string = '';
}

@ObservedV2
export class CommentsUiState {
  @Trace trackId: number = 0;
  @Trace loading: boolean = false;
  @Trace loadingMore: boolean = false;
  @Trace posting: boolean = false;
  @Trace items: CommentItem[] = [];
  @Trace total: number = 0;
  @Trace page: number = 0;
  @Trace error: string = '';
  @Trace notice: string = '';
}

@ObservedV2
export class SongExtrasViewModel {
  @Trace lyrics: LyricsUiState = new LyricsUiState();
  @Trace comments: CommentsUiState = new CommentsUiState();
  private lyricCache: Map<number, LyricLine[]> = new Map();

  ensureLyrics(track: Track): void {
    const cached = this.lyricCache.get(track.id);
    if (cached !== undefined) {
      const state = new LyricsUiState();
      state.trackId = track.id;
      state.loaded = true;
      state.lines = cached;
      this.lyrics = state;
      return;
    }
    const current = this.lyrics;
    if (current.trackId === track.id && (current.loading || current.loaded)) {
      return;
    }
    const state = new LyricsUiState();
    state.trackId = track.id;
    state.loading = true;
    this.lyrics = state;
    MusicRepository.lyrics(track.id).then((raw: string): void => {
      const lines = parseLrc(raw);
      this.lyricCache.set(track.id, lines);
      const done = new LyricsUiState();
      done.trackId = track.id;
      done.loaded = true;
      done.lines = lines;
      this.lyrics = done;
    }).catch((err: Object): void => {
      const failed = new LyricsUiState();
      failed.trackId = track.id;
      failed.loaded = true;
      failed.error = errText(err, '歌词加载失败');
      this.lyrics = failed;
    });
  }

  loadComments(trackId: number, refresh: boolean = false): void {
    const current = this.comments;
    if (!refresh && current.trackId === trackId && (current.loading || current.items.length > 0)) {
      return;
    }
    const page = refresh || current.trackId !== trackId ? 1 : current.page + 1;
    if (page === 1) {
      const state = new CommentsUiState();
      state.trackId = trackId;
      state.loading = true;
      this.comments = state;
    } else {
      current.loadingMore = true;
      current.error = '';
      current.notice = '';
    }
    MusicRepository.comments(trackId, page).then((result: CommentsPage): void => {
      const existing = page === 1 ? [] : this.comments.items;
      const state = new CommentsUiState();
      state.trackId = trackId;
      state.items = existing.concat(result.items);
      state.total = result.total;
      state.page = page;
      this.comments = state;
    }).catch((err: Object): void => {
      const failed = this.comments;
      failed.loading = false;
      failed.loadingMore = false;
      failed.error = errText(err, '评论加载失败');
    });
  }

  postComment(trackId: number, content: string): void {
    const text = content.trim();
    if (text.length === 0 || this.comments.posting) {
      return;
    }
    if (!Session.loggedIn) {
      this.comments.error = '登录后才能发表评论';
      return;
    }
    this.comments.posting = true;
    this.comments.error = '';
    this.comments.notice = '';
    MusicRepository.postComment(trackId, text).then((): Promise<CommentsPage> => {
      return MusicRepository.comments(trackId, 1);
    }).then((result: CommentsPage): void => {
      const state = new CommentsUiState();
      state.trackId = trackId;
      state.items = result.items;
      state.total = result.total;
      state.page = 1;
      state.notice = '评论已发布';
      this.comments = state;
    }).catch((err: Object): void => {
      this.comments.posting = false;
      this.comments.error = errText(err, '评论发送失败');
    });
  }

  clearNotice(): void {
    this.comments.notice = '';
    this.comments.error = '';
  }
}


