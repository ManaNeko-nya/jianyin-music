// @ts-nocheck
// Android 平台桥的唯一入口：媒体会话动作与系统栏外观。
import { deviceInfo } from '@kit.BasicServicesKit';

const OS_NAME: string = deviceInfo.osFullName;
export const IS_ANDROID: boolean = OS_NAME.startsWith('Android');
export const IS_HARMONY: boolean = !IS_ANDROID;

let bridge: ESObject = null;
let initStarted: boolean = false;
let pendingBars: boolean | null = null;
let actionHandler: ((action: string, position: number) => void) | null = null;
let readyCallbacks: Array<() => void> = [];

export function isBridgeReady(): boolean {
  return bridge !== null;
}

export function whenBridgeReady(callback: () => void): void {
  if (bridge !== null) {
    callback();
    return;
  }
  readyCallbacks.push(callback);
}

export function setMediaActionHandler(handler: (action: string, position: number) => void): void {
  actionHandler = handler;
}

function call(method: string, ...args: ESObject[]): boolean {
  if (bridge === null) {
    return false;
  }
  try {
    bridge.callMethod(method, ...args);
    return true;
  } catch (err) {
    return false;
  }
}

export function callBridge(method: string, ...args: ESObject[]): void {
  call(method, ...args);
}

export async function initBridge(): Promise<void> {
  if (!IS_ANDROID || bridge !== null || initStarted) {
    return;
  }
  initStarted = true;
  try {
    const mod = await import('@arkui-x.bridge');
    const Bridge = mod.default !== undefined ? mod.default : mod;
    const instance = Bridge.createBridge('AppBridge');
    instance.registerMethod({
      name: 'onMediaAction',
      method: (action: string, position: number): string => {
        if (actionHandler !== null) {
          actionHandler(action, position);
        }
        return 'ok';
      },
    });
    bridge = instance;
    if (pendingBars !== null) {
      call('setBars', pendingBars);
      pendingBars = null;
    }
    const callbacks = readyCallbacks;
    readyCallbacks = [];
    for (const callback of callbacks) {
      callback();
    }
  } catch (err) {
    initStarted = false;
  }
}

/** 读取 Android 当前系统深色状态；桥不可用时返回 null。 */
export function getAndroidSystemDark(): boolean | null {
  if (!IS_ANDROID || bridge === null) {
    return null;
  }
  try {
    const value = bridge.callMethodSync('isSystemDark');
    return typeof value === 'boolean' ? value : null;
  } catch (err) {
    return null;
  }
}

/** lightContent=true 表示深色背景上的白色图标。 */
export function setAndroidSystemBars(lightContent: boolean): void {
  if (!IS_ANDROID) {
    return;
  }
  if (bridge !== null && call('setBars', lightContent)) {
    return;
  }
  pendingBars = lightContent;
  initBridge();
}
