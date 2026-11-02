export type ProviderKind = 'jianyin' | 'subsonic';

export const PROVIDER_JIANYIN: ProviderKind = 'jianyin';
export const PROVIDER_SUBSONIC: ProviderKind = 'subsonic';

export class ProviderCapabilities {
  readonly comments: boolean;
  readonly register: boolean;
  readonly playlistReorder: boolean;
  readonly playlistWrite: boolean;
  readonly lyrics: boolean;

  constructor(comments: boolean, register: boolean, playlistReorder: boolean,
    playlistWrite: boolean, lyrics: boolean) {
    this.comments = comments;
    this.register = register;
    this.playlistReorder = playlistReorder;
    this.playlistWrite = playlistWrite;
    this.lyrics = lyrics;
  }
}

export function providerLabel(kind: ProviderKind): string {
  return kind === PROVIDER_SUBSONIC ? 'Navidrome' : 'GuoBeng';
}
