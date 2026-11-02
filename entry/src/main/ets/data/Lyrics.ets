export class LyricLine {
  readonly timeMs: number;
  readonly text: string;

  constructor(timeMs: number, text: string) {
    this.timeMs = timeMs;
    this.text = text;
  }
}

const TIMESTAMP_PATTERN: RegExp = /\[(\d{1,3}):([0-5]?\d)(?:[.:](\d{1,3}))?]/g;
const META_PATTERN: RegExp = /^\[(ti|ar|al|by|offset|re|ve|au|length|tool):[^\]]*]$/i;

export function parseLrc(raw: string): LyricLine[] {
  if (raw.trim().length === 0) {
    return [];
  }
  const result: LyricLine[] = [];
  const lines = raw.split(/\r\n|\r|\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed.length === 0 || META_PATTERN.test(trimmed)) {
      continue;
    }
    TIMESTAMP_PATTERN.lastIndex = 0;
    const stamps: string[][] = [];
    let m: RegExpExecArray | null = TIMESTAMP_PATTERN.exec(trimmed);
    while (m !== null) {
      stamps.push([m[1], m[2], m.length > 3 && m[3] !== undefined ? m[3] : '']);
      m = TIMESTAMP_PATTERN.exec(trimmed);
    }
    if (stamps.length === 0) {
      continue;
    }
    const text = trimmed.replace(TIMESTAMP_PATTERN, '').trim();
    if (text.length === 0) {
      continue;
    }
    for (const stamp of stamps) {
      const minutes = toLong(stamp[0]);
      const seconds = toLong(stamp[1]);
      const fraction = toLong(stamp[2].padEnd(3, '0').slice(0, 3));
      result.push(new LyricLine((minutes * 60 + seconds) * 1000 + fraction, text));
    }
  }
  result.sort((a: LyricLine, b: LyricLine): number => a.timeMs - b.timeMs);
  return result;
}

function toLong(raw: string): number {
  if (raw.length === 0) {
    return 0;
  }
  const n = parseInt(raw, 10);
  return isNaN(n) ? 0 : n;
}
