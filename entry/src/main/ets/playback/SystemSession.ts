// @ts-nocheck
// 系统级播放能力：鸿蒙用 AVSession/后台任务，Android 用前台媒体服务（Java bridge）。
import {
  IS_ANDROID, IS_HARMONY, callBridge, initBridge, isBridgeReady, setMediaActionHandler, whenBridgeReady,
} from '../platform/BridgeClient';

const ANDROID_SPEEDS: number[] = [0.75, 1, 1.25, 1.75, 2];

/** Android AVPlayer 只支持 0.75/1/1.25/1.75/2 五档，其它值会被退回 1.0。 */
export function normalizeSpeed(rate: number): number {
  if (!IS_ANDROID) {
    return rate;
  }
  let best = 1;
  let distance = 99;
  for (const value of ANDROID_SPEEDS) {
    const delta = Math.abs(value - rate);
    if (delta <= distance) {
      distance = delta;
      best = value;
    }
  }
  return best;
}

export class SystemSession {
  private harmony: ESObject = null;
  private androidStartPending: boolean = false;
  private androidStarted: boolean = false;
  private lastPushedPlaying: boolean = false;
  private lastPushedPos: number = -1;

  private meta: ESObject = null;
  private playing: boolean = false;
  private positionMs: number = 0;
  private speed: number = 1;

  private onPlay: () => void = () => {
  };
  private onPause: () => void = () => {
  };
  private onNext: () => void = () => {
  };
  private onPrev: () => void = () => {
  };
  private onSeek: (time: number) => void = (_time: number) => {
  };

  async init(context: ESObject, onPlay: () => void, onPause: () => void, onNext: () => void,
    onPrevious: () => void, onSeek: (time: number) => void, onStop: () => void): Promise<void> {
    this.onPlay = onPlay;
    this.onPause = onPause;
    this.onNext = onNext;
    this.onPrev = onPrevious;
    this.onSeek = onSeek;

    if (IS_ANDROID) {
      setMediaActionHandler((action: string, position: number): void => {
        this.handleAction(action, position);
      });
      initBridge();
      whenBridgeReady((): void => {
        this.pushAndroid(true);
        if (this.androidStartPending) {
          this.androidStartPending = false;
          callBridge('startMedia');
          this.androidStarted = true;
        }
      });
      return;
    }
    if (!IS_HARMONY) {
      return;
    }
    const harmony = await this.ensureHarmony();
    if (harmony === null) {
      return;
    }
    await harmony.init(context, onPlay, onPause, onNext, onPrevious, onSeek, onStop);
    if (this.meta !== null) {
      harmony.setMetadata(this.meta);
    }
    harmony.setPlaybackState(this.playing, this.positionMs, this.speed);
  }

  private async ensureHarmony(): Promise<ESObject | null> {
    if (!IS_HARMONY) {
      return null;
    }
    if (this.harmony !== null) {
      return this.harmony;
    }
    try {
      const mod = await import('./HarmonySession');
      this.harmony = new mod.HarmonySession();
      return this.harmony;
    } catch (err) {
      return null;
    }
  }

  private handleAction(action: string, position: number): void {
    if (action === 'play') {
      this.onPlay();
    } else if (action === 'pause') {
      this.onPause();
    } else if (action === 'next') {
      this.onNext();
    } else if (action === 'prev') {
      this.onPrev();
    } else if (action === 'seek') {
      this.onSeek(position);
    }
  }

  async startBackground(context: ESObject): Promise<void> {
    if (IS_ANDROID) {
      if (this.androidStarted) {
        return;
      }
      if (isBridgeReady()) {
        callBridge('startMedia');
        this.androidStarted = true;
      } else {
        this.androidStartPending = true;
        initBridge();
      }
      return;
    }
    if (!IS_HARMONY) {
      return;
    }
    const harmony = await this.ensureHarmony();
    if (harmony !== null) {
      await harmony.startBackground(context);
    }
  }

  async stopBackground(context: ESObject): Promise<void> {
    if (IS_ANDROID) {
      if (this.androidStarted) {
        callBridge('stopMedia');
        this.androidStarted = false;
      }
      return;
    }
    if (!IS_HARMONY) {
      return;
    }
    const harmony = await this.ensureHarmony();
    if (harmony !== null) {
      await harmony.stopBackground(context);
    }
  }

  setMetadata(metadata: ESObject): void {
    this.meta = metadata;
    if (IS_ANDROID) {
      this.pushAndroid(true);
      return;
    }
    if (this.harmony !== null) {
      this.harmony.setMetadata(metadata);
    }
  }

  setPlaybackState(isPlaying: boolean, positionMs: number, speed: number): void {
    this.playing = isPlaying;
    this.positionMs = positionMs;
    this.speed = speed;
    if (IS_ANDROID) {
      this.pushAndroid(false);
      return;
    }
    if (this.harmony !== null) {
      this.harmony.setPlaybackState(isPlaying, positionMs, speed);
    }
  }

  /** 进度变化很频繁，最多一秒推一次；切歌/暂停用 force。 */
  private pushAndroid(force: boolean): void {
    if (!IS_ANDROID || !isBridgeReady()) {
      return;
    }
    if (!force && this.playing === this.lastPushedPlaying &&
      Math.abs(this.positionMs - this.lastPushedPos) < 1000) {
      return;
    }
    this.lastPushedPlaying = this.playing;
    this.lastPushedPos = this.positionMs;
    const m = this.meta;
    const title = m !== null && m.title !== undefined ? m.title : '';
    const artist = m !== null && m.artist !== undefined ? m.artist : '';
    const album = m !== null && m.album !== undefined ? m.album : '';
    const artUrl = m !== null && m.mediaImage !== undefined ? m.mediaImage : '';
    const duration = m !== null && m.duration !== undefined ? m.duration : 0;
    const json = JSON.stringify({
      title: title,
      artist: artist,
      album: album,
      artUrl: artUrl,
      duration: duration,
      position: this.positionMs,
      playing: this.playing,
      speed: this.speed,
    });
    callBridge('updateMedia', json);
  }

  attachInterrupt(player: ESObject, onPause: () => void): void {
    if (IS_ANDROID) {
      return;
    }
    this.ensureHarmony().then((harmony: ESObject | null): void => {
      if (harmony !== null) {
        harmony.attachInterrupt(player, onPause);
      }
    });
  }

  /** 鸿蒙优先任意倍率；Android 只支持固定档位，走 setSpeed。 */
  applyRate(player: ESObject, rate: number): void {
    const safe = IS_ANDROID ? normalizeSpeed(rate) : rate;
    if (IS_HARMONY) {
      try {
        player.setPlaybackRate(safe);
        return;
      } catch (err) {
      }
    }
    const table: number[][] = [
      [0.25, 8], [0.5, 5], [0.75, 0], [1, 1], [1.25, 2], [1.5, 6], [1.75, 3], [2, 4], [3, 7],
    ];
    let best = 1;
    let distance = 99;
    for (const row of table) {
      const d = Math.abs(row[0] - safe);
      if (d < distance) {
        distance = d;
        best = row[1];
      }
    }
    try {
      player.setSpeed(best);
    } catch (err) {
    }
  }
}
