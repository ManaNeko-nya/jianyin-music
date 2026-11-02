/**
 * JSON 读取工具，等价于安卓端 org.json 的 opt 系列：
 * 缺键、null、类型不符时返回默认值，绝不让解析崩溃。
 */
export type JObj = Record<string, Object>;
export type JArr = Array<Object>;

export function parseJson(text: string): JObj | null {
  if (text === null || text === undefined || text.length === 0 || text.trim().length === 0) {
    return null;
  }
  try {
    const parsed: Object = JSON.parse(text) as Object;
    if (parsed instanceof Array) {
      return null;
    }
    return parsed as JObj;
  } catch (err) {
    return null;
  }
}

export function parseJsonArray(text: string): JArr | null {
  if (text === null || text === undefined || text.trim().length === 0) {
    return null;
  }
  try {
    const parsed: Object = JSON.parse(text) as Object;
    if (!(parsed instanceof Array)) {
      return null;
    }
    return parsed as JArr;
  } catch (err) {
    return null;
  }
}

export function isNull(o: JObj, key: string): boolean {
  const v = o[key];
  return v === undefined || v === null;
}

export function jObj(o: JObj, key: string): JObj | null {
  const v = o[key];
  if (v === undefined || v === null || v instanceof Array) {
    return null;
  }
  if (typeof v !== 'object') {
    return null;
  }
  return v as JObj;
}

export function jArr(o: JObj, key: string): JArr {
  const v = o[key];
  if (v === undefined || v === null || !(v instanceof Array)) {
    return [];
  }
  return v as JArr;
}

export function jObjAt(a: JArr, index: number): JObj | null {
  if (index < 0 || index >= a.length) {
    return null;
  }
  const v = a[index];
  if (v === undefined || v === null || v instanceof Array || typeof v !== 'object') {
    return null;
  }
  return v as JObj;
}

export function jInt(o: JObj, key: string, def: number = 0): number {
  const v = o[key];
  if (v === undefined || v === null) {
    return def;
  }
  if (typeof v === 'number') {
    return v;
  }
  if (typeof v === 'string') {
    const n = parseInt(v, 10);
    return isNaN(n) ? def : n;
  }
  return def;
}

export function jDouble(o: JObj, key: string, def: number = 0): number {
  const v = o[key];
  if (v === undefined || v === null) {
    return def;
  }
  if (typeof v === 'number') {
    return v;
  }
  if (typeof v === 'string') {
    const n = parseFloat(v);
    return isNaN(n) ? def : n;
  }
  return def;
}

export function jBool(o: JObj, key: string, def: boolean = false): boolean {
  const v = o[key];
  if (typeof v === 'boolean') {
    return v;
  }
  if (typeof v === 'number') {
    return v !== 0;
  }
  if (typeof v === 'string') {
    return v === 'true';
  }
  return def;
}

/** 等价于 cleanString：null、"null"、缺键都回落到默认值。 */
export function jStr(o: JObj, key: string, def: string = ''): string {
  const v = o[key];
  if (v === undefined || v === null) {
    return def;
  }
  if (typeof v === 'string') {
    return v === 'null' ? def : v;
  }
  if (typeof v === 'number' || typeof v === 'boolean') {
    return String(v);
  }
  return def;
}

/** 提取错误信息，兼容 Error 与任意抛出对象。 */
export function errText(err: Object | null | undefined, fallback: string = '网络错误'): string {
  if (err === null || err === undefined) {
    return fallback;
  }
  if (err instanceof Error) {
    return err.message.length > 0 ? err.message : fallback;
  }
  if (typeof err === 'string') {
    return err;
  }
  try {
    const rec = err as Record<string, Object>;
    const msg = rec['message'];
    if (typeof msg === 'string' && msg.length > 0) {
      return msg;
    }
  } catch (ignored) {
  }
  return fallback;
}

/** 协程锁：串行化令牌刷新，等价于 kotlinx Mutex.withLock。 */
export class Mutex {
  private tail: Promise<void> = Promise.resolve();

  lock<T>(fn: () => Promise<T>): Promise<T> {
    const run = this.tail.then(fn);
    this.tail = run.then(() => {
    }, () => {
    });
    return run;
  }
}
