import { media } from '@kit.MediaKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Session } from '../data/Session';
import { L10n } from '../data/L10n';
import { AppSettings, PlayMode } from '../data/AppSettings';
import { Track } from '../data/Models';
import { errText } from '../data/Json';
import { SystemSession, normalizeSpeed } from './SystemSession';
import { IS_ANDROID } from '../platform/BridgeClient';

/** 播放器对外状态（等价于安卓端 PlayerState + StateFlow）。 */
@ObservedV2
export class PlayerState {
  @Trace track: Track | null = null;
  @Trace queue: Track[] = [];
  @Trace currentIndex: number = -1;
  @Trace isPlaying: boolean = false;
  @Trace positionMs: number = 0;
  @Trace durationMs: number = 0;
  @Trace speed: number = 1;
  @Trace playMode: PlayMode = PlayMode.Order;
  @Trace error: string | null = null;
}

/**
 * 播放内核：AVPlayer + AVSession + 后台常驻任务。
 * 等价于安卓端 PlaybackService(Media3 MediaSessionService) + MediaController 组合，
 * 单例常驻，界面只读写 state。
 */
export class PlayerEngine {
  readonly state: PlayerState = new PlayerState();
  private queue: Track[] = [];
  private player: media.AVPlayer | null = null;
  private system: SystemSession = new SystemSession();
  private context: common.UIAbilityContext | null = null;
  private trackListeners: Array<(track: Track | null) => void> = [];
  private lastTrackId: number = -1;
  private endHandled: boolean = false;

  addTrackListener(fn: (track: Track | null) => void): void {
    this.trackListeners.push(fn);
  }

  removeTrackListener(fn: (track: Track | null) => void): void {
    this.trackListeners = this.trackListeners.filter((f): boolean => f !== fn);
  }

  private notifyTrack(): void {
    if (this.state.track !== null && this.state.track.id === this.lastTrackId) {
      return;
    }
    this.lastTrackId = this.state.track !== null ? this.state.track.id : -1;
    for (const fn of this.trackListeners) {
      fn(this.state.track);
    }
  }

  /** 绑定 UIAbility 上下文并初始化 AVSession（只在 EntryAbility 里调用一次）。 */
  bind(context: common.UIAbilityContext): void {
    this.context = context;
    const savedSpeed = normalizeSpeed(AppSettings.speed);
    this.state.speed = savedSpeed;
    if (savedSpeed !== AppSettings.speed) {
      AppSettings.setSpeed(savedSpeed);
    }
    this.state.playMode = AppSettings.playMode;
    this.initSession();
  }

  private async initSession(): Promise<void> {
    if (this.context === null) {
      return;
    }
    await this.system.init(this.context,
      (): void => {
        if (!this.state.isPlaying) {
          this.toggle();
        }
      },
      (): void => {
        if (this.state.isPlaying) {
          this.toggle();
        }
      },
      (): void => this.next(),
      (): void => this.previous(),
      (time: number): void => this.seekTo(time),
      (): void => {
        this.pauseInternal();
      });
  }

  private async ensureTask(): Promise<void> {
    if (this.context === null) {
      return;
    }
    await this.system.startBackground(this.context);
  }

  private async stopTask(): Promise<void> {
    if (this.context === null) {
      return;
    }
    await this.system.stopBackground(this.context);
  }

  private async createPlayerIfNeeded(): Promise<media.AVPlayer | null> {
    if (this.player !== null) {
      return this.player;
    }
    try {
      const player = await media.createAVPlayer();
      this.attach(player);
      this.player = player;
      return player;
    } catch (err) {
      this.state.error = '播放器初始化失败：' + errText(err);
      return null;
    }
  }

  private attach(player: media.AVPlayer): void {
    player.on('stateChange', (state: media.AVPlayerState, _reason: media.StateChangeReason) => {
      this.syncPlaybackState();
      if (state === 'completed') {
        this.onTrackEnded();
      }
    });
    // 网络流播放结束只发 endOfStream，completed 不一定到达，两个都接。
    player.on('endOfStream', (): void => {
      this.onTrackEnded();
    });
    player.on('timeUpdate', (time: number) => {
      if (time >= 0) {
        this.state.positionMs = time;
        this.pushSessionPlaybackState();
      }
    });
    player.on('durationUpdate', (duration: number) => {
      if (duration > 0) {
        this.state.durationMs = duration;
        this.pushSessionMetadata();
      }
    });
    player.on('seekDone', (seeked: number) => {
      if (seeked >= 0) {
        this.state.positionMs = seeked;
        this.pushSessionPlaybackState();
      }
    });
    player.on('speedDone', (speed: number) => {
      // Android 回调的是 PlaybackSpeed 档位码（0..4），不是倍速值。
      if (IS_ANDROID) {
        const rates = [0.75, 1, 1.25, 1.75, 2];
        const reported = speed >= 0 && speed < rates.length ? rates[speed] : speed;
        // 换曲/初始化时播放器会回一个默认档位码（0 → 0.75x），但实际倍速是继承下来的；
        // 不能把这种「非用户操作」的回调写进 state，否则 UI 被打回 0.75、下一首才真正应用。
        // 以 state.speed 为准：回调与 UI 不一致时把播放器拉回 UI 的倍速。
        if (reported > 0 && Math.abs(reported - this.state.speed) > 0.01) {
          this.applyPlaybackRate(player, this.state.speed);
        }
        return;
      }
      if (speed > 0) {
        this.state.speed = speed;
      }
    });
    player.on('error', (err: BusinessError) => {
      this.state.error = '播放失败：' + errText(err);
      this.state.isPlaying = false;
      this.pushSessionPlaybackState();
    });
    this.system.attachInterrupt(player, (): void => {
      this.pauseInternal();
    });
  }

  /** 播放一组歌曲；过滤无可播放地址的项，起点按 id 对齐。 */
  playQueue(tracks: Track[], startIndex: number): void {
    const playable = tracks.filter((t: Track): boolean => t.audioUrl.length > 0);
    if (playable.length === 0) {
      return;
    }
    const target = startIndex >= 0 && startIndex < tracks.length ? tracks[startIndex].id : -1;
    let index = 0;
    for (let i = 0; i < playable.length; i++) {
      if (playable[i].id === target) {
        index = i;
        break;
      }
    }
    this.queue = playable;
    this.loadTrack(index, true);
  }

  playAt(index: number): void {
    if (index < 0 || index >= this.queue.length) {
      return;
    }
    this.loadTrack(index, true);
  }

  /** 把歌曲追加到当前播放队列；队列为空时直接开始播放。 */
  enqueue(tracks: Track[]): void {
    const playable = tracks.filter((t: Track): boolean => t.audioUrl.length > 0);
    if (playable.length === 0) {
      return;
    }
    if (this.queue.length === 0 || this.state.currentIndex < 0) {
      this.playQueue(playable, 0);
      return;
    }
    this.queue = this.queue.concat(playable);
    this.state.queue = this.queue;
  }

  toggle(): void {
    if (this.state.isPlaying) {
      this.pauseInternal();
      return;
    }
    this.resumeInternal();
  }

  private async pauseInternal(): Promise<void> {
    const player = this.player;
    if (player === null) {
      return;
    }
    try {
      await player.pause();
      this.syncPlaybackState();
    } catch (err) {
    }
  }

  private async resumeInternal(): Promise<void> {
    const player = this.player;
    if (player === null) {
      return;
    }
    try {
      if (this.state.positionMs >= this.state.durationMs && this.state.durationMs > 0) {
        await player.seek(0);
      }
      await player.play();
      this.syncPlaybackState();
    } catch (err) {
    }
  }

  next(): void {
    if (this.state.playMode === PlayMode.Shuffle) {
      this.playAt(this.randomIndex());
      return;
    }
    const next = this.state.currentIndex + 1;
    if (next < this.queue.length) {
      this.playAt(next);
    } else if (this.state.playMode === PlayMode.LoopList && this.queue.length > 0) {
      this.playAt(0);
    }
  }

  previous(): void {
    if (this.state.positionMs > 3000) {
      this.seekTo(0);
    } else if (this.state.currentIndex > 0) {
      this.playAt(this.state.currentIndex - 1);
    } else {
      this.seekTo(0);
    }
  }

  seekTo(positionMs: number): void {
    const player = this.player;
    const safe = Math.max(positionMs, 0);
    if (player !== null) {
      try {
        player.seek(safe);
      } catch (err) {
      }
    }
    this.state.positionMs = safe;
    this.pushSessionPlaybackState();
  }

  setSpeed(value: number): void {
    const safe = normalizeSpeed(Math.min(Math.max(value, 0.5), 2.5));
    AppSettings.setSpeed(safe);
    this.state.speed = safe;
    const player = this.player;
    if (player !== null) {
      this.applyPlaybackRate(player, safe);
    }
    this.pushSessionPlaybackState();
  }

  /** setPlaybackRate 支持任意倍率；平台不支持时由 SystemSession 退回固定档位。 */
  private applyPlaybackRate(player: media.AVPlayer, rate: number): void {
    const state = player.state;
    if (state !== 'prepared' && state !== 'playing' && state !== 'paused' && state !== 'completed') {
      return;
    }
    this.system.applyRate(player, rate);
  }

  /** 等待 AVPlayer 进入指定状态；url 赋值后的 initialized 是异步事件。 */
  private waitForState(player: media.AVPlayer, target: media.AVPlayerState,
    timeoutMs: number): Promise<void> {
    if (player.state === target) {
      return Promise.resolve();
    }
    return new Promise<void>((resolve, reject) => {
      let settled = false;
      let timer: number = -1;
      const onState = (state: media.AVPlayerState, _reason: media.StateChangeReason): void => {
        if (settled) {
          return;
        }
        if (state === target) {
          settled = true;
          clearTimeout(timer);
          player.off('stateChange', onState);
          resolve();
        } else if (state === 'error') {
          settled = true;
          clearTimeout(timer);
          player.off('stateChange', onState);
          reject(new Error('播放器进入错误状态'));
        }
      };
      timer = setTimeout(() => {
        if (!settled) {
          settled = true;
          player.off('stateChange', onState);
          reject(new Error(`等待播放器状态 ${target} 超时`));
        }
      }, timeoutMs);
      player.on('stateChange', onState);
    });
  }

  clearError(): void {
    this.state.error = null;
  }

  /** 一曲结束：completed 与 endOfStream 可能都到达，用标志去重。 */
  private onTrackEnded(): void {
    if (this.endHandled) {
      return;
    }
    this.endHandled = true;
    const mode = this.state.playMode;
    if (mode === PlayMode.LoopOne) {
      this.playAt(this.state.currentIndex);
      return;
    }
    if (mode === PlayMode.Shuffle) {
      this.playAt(this.randomIndex());
      return;
    }
    const next = this.state.currentIndex + 1;
    if (next < this.queue.length) {
      this.playAt(next);
      return;
    }
    if (mode === PlayMode.LoopList && this.queue.length > 0) {
      this.playAt(0);
      return;
    }
    this.state.isPlaying = false;
    this.pushSessionPlaybackState();
  }

  private randomIndex(): number {
    if (this.queue.length <= 1) {
      return this.state.currentIndex;
    }
    let pick = this.state.currentIndex;
    while (pick === this.state.currentIndex) {
      pick = Math.floor(Math.random() * this.queue.length);
    }
    return pick;
  }

  /** 播放顺序按钮：顺序 → 列表循环 → 单曲循环 → 随机。 */
  cyclePlayMode(): void {
    const order: PlayMode[] = [PlayMode.Order, PlayMode.LoopList, PlayMode.LoopOne, PlayMode.Shuffle];
    const next = order[(order.indexOf(this.state.playMode) + 1) % order.length];
    this.state.playMode = next;
    AppSettings.setPlayMode(next);
  }

  private async loadTrack(index: number, autoPlay: boolean): Promise<void> {
    const track = this.queue[index];
    if (track === undefined) {
      return;
    }
    this.state.track = track;
    this.state.queue = this.queue;
    this.state.currentIndex = index;
    this.state.positionMs = 0;
    this.state.durationMs = track.durationMs;
    this.state.error = null;
    this.endHandled = false;
    this.notifyTrack();
    this.pushSessionMetadata();

    const player = await this.createPlayerIfNeeded();
    if (player === null) {
      return;
    }
    try {
      await player.reset();
      await this.waitForState(player, 'idle', 5000);
      player.url = Session.mediaUrl(track.audioUrl);
      await this.waitForState(player, 'initialized', 8000);
      await player.prepare();
      await this.waitForState(player, 'prepared', 15000);
      this.applyPlaybackRate(player, this.state.speed);
      if (autoPlay) {
        await player.play();
        await this.ensureTask();
      }
      this.syncPlaybackState();
    } catch (err) {
      this.state.error = '播放失败：' + errText(err);
      this.state.isPlaying = false;
    }
  }

  private syncPlaybackState(): void {
    const player = this.player;
    if (player === null) {
      return;
    }
    try {
      const playing = player.state === 'playing';
      this.state.isPlaying = playing;
      if (player.duration > 0) {
        this.state.durationMs = player.duration;
      }
      if (player.currentTime >= 0) {
        this.state.positionMs = player.currentTime;
      }
      this.pushSessionPlaybackState();
    } catch (err) {
    }
  }

  private pushSessionMetadata(): void {
    const track = this.state.track;
    if (track === null) {
      return;
    }
    this.system.setMetadata({
      assetId: String(track.id),
      title: track.title,
      artist: track.artistLabel.length > 0 ? track.artistLabel : L10n.tr('未知艺人'),
      album: track.albumTitle.length > 0 ? track.albumTitle : L10n.tr('简音'),
      duration: this.state.durationMs,
      mediaImage: track.coverUrl.length > 0 ? Session.mediaUrl(track.coverUrl) : undefined,
    });
  }

  private pushSessionPlaybackState(): void {
    this.system.setPlaybackState(this.state.isPlaying, this.state.positionMs, this.state.speed);
  }
}

export const Player: PlayerEngine = new PlayerEngine();

