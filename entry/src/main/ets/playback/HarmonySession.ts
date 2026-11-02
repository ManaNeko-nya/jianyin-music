// @ts-nocheck
// 只在鸿蒙端被动态加载；Android 不会执行这里的静态 import。
import { avSession } from '@kit.AVSessionKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { wantAgent } from '@kit.AbilityKit';
import { audio } from '@kit.AudioKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'JianYinSession';

export class HarmonySession {
  private session: ESObject = null;
  private taskRunning: boolean = false;

  async init(context: ESObject, onPlay: () => void, onPause: () => void, onNext: () => void,
    onPrevious: () => void, onSeek: (time: number) => void, onStop: () => void): Promise<void> {
    if (this.session !== null) {
      return;
    }
    try {
      const session = await avSession.createAVSession(context, 'music_playback', 'audio');
      session.on('play', onPlay);
      session.on('pause', onPause);
      session.on('playNext', onNext);
      session.on('playPrevious', onPrevious);
      session.on('seek', onSeek);
      session.on('stop', onStop);
      await session.activate();
      this.session = session;
      hilog.info(DOMAIN, TAG, 'AVSession ready');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'AVSession init failed');
    }
  }

  async startBackground(context: ESObject): Promise<void> {
    if (this.taskRunning) {
      return;
    }
    try {
      const info = {
        wants: [{ bundleName: 'com.uniucy.music', abilityName: 'EntryAbility' }],
        operationType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
      };
      const agent = await wantAgent.getWantAgent(info);
      await backgroundTaskManager.startBackgroundRunning(
        context, backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, agent);
      this.taskRunning = true;
      hilog.info(DOMAIN, TAG, 'background task started');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'background task failed');
    }
  }

  async stopBackground(context: ESObject): Promise<void> {
    if (!this.taskRunning) {
      return;
    }
    try {
      await backgroundTaskManager.stopBackgroundRunning(context);
    } catch (err) {
    }
    this.taskRunning = false;
  }

  setMetadata(metadata: ESObject): void {
    if (this.session === null) {
      return;
    }
    try {
      this.session.setAVMetadata(metadata);
    } catch (err) {
    }
  }

  setPlaybackState(isPlaying: boolean, positionMs: number, speed: number): void {
    if (this.session === null) {
      return;
    }
    try {
      this.session.setAVPlaybackState({
        state: isPlaying ? 1 : 0,
        position: { elapsedTime: positionMs, updateTime: new Date().getTime() },
        speed: speed,
      });
    } catch (err) {
    }
  }

  attachInterrupt(player: ESObject, onPause: () => void): void {
    try {
      player.on('audioInterrupt', (event: ESObject): void => {
        if (event.hintType === audio.InterruptHint.INTERRUPT_HINT_PAUSE) {
          onPause();
        }
      });
    } catch (err) {
    }
  }
}
