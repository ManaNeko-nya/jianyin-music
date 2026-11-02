import {
  Album, AlbumDetail, ArtistDetail, CommentsPage, HomeData, PageData, Playlist,
  PlaylistDetail, SearchResults, Track,
} from './Models';
import { User } from './Session';
import { ProviderCapabilities, ProviderKind } from './ProviderTypes';

/** 一套音乐服务需要提供的能力；页面只依赖这个接口，不关心具体协议。 */
export interface MusicProvider {
  readonly kind: ProviderKind;
  readonly capabilities: ProviderCapabilities;

  home(): Promise<HomeData>;
  albumPage(page: number, pageSize: number, sort: string, query: string): Promise<PageData<Album>>;
  trackPage(page: number, pageSize: number, query: string): Promise<PageData<Track>>;
  albumDetail(albumId: number): Promise<AlbumDetail>;
  artistDetail(artistId: number): Promise<ArtistDetail>;
  artistTracks(artistId: number, page: number, pageSize: number): Promise<PageData<Track>>;
  lyrics(trackId: number): Promise<string>;
  comments(trackId: number, page: number, pageSize: number): Promise<CommentsPage>;
  postComment(trackId: number, content: string): Promise<void>;

  playlists(): Promise<Playlist[]>;
  playlistDetail(playlistId: number): Promise<PlaylistDetail>;
  createPlaylist(name: string): Promise<Playlist>;
  renamePlaylist(playlistId: number, name: string): Promise<Playlist>;
  deletePlaylist(playlistId: number): Promise<void>;
  reorderPlaylists(listIds: number[]): Promise<void>;
  reorderPlaylistTracks(playlistId: number, trackIds: number[]): Promise<void>;
  addTracksToPlaylist(playlistId: number, trackIds: number[]): Promise<void>;
  removeTracksFromPlaylist(playlistId: number, trackIds: number[]): Promise<void>;

  search(query: string): Promise<SearchResults>;
  searchTracks(query: string, page: number, pageSize: number): Promise<PageData<Track>>;

  login(baseUrl: string, account: string, password: string): Promise<User | null>;
  guest(baseUrl: string): Promise<void>;
  register(baseUrl: string, username: string, password: string, nickname: string): Promise<User | null>;
  logout(): Promise<void>;
}
