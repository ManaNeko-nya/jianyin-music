import { http } from '@kit.NetworkKit';
import { image } from '@kit.ImageKit';

/** 下载图片并计算 64x64 平均色（跳过半透明像素），失败返回 null。 */
export async function averageColor(url: string): Promise<string | null> {
  const client = http.createHttp();
  try {
    const resp = await client.request(url, {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      connectTimeout: 10000,
      readTimeout: 20000,
      usingCache: true,
    });
    if (resp.responseCode < 200 || resp.responseCode >= 300) {
      return null;
    }
    const buffer = resp.result as ArrayBuffer;
    const source = image.createImageSource(buffer);
    if (source === null || source === undefined) {
      return null;
    }
    const pixelMap = await source.createPixelMap({
      desiredSize: { width: 64, height: 64 },
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
    });
    source.release();
    const info = await pixelMap.getImageInfo();
    const size = info.size.width * info.size.height * 4;
    const data = new ArrayBuffer(size);
    await pixelMap.readPixelsToBuffer(data);
    pixelMap.release();
    const bytes = new Uint8Array(data);
    let red = 0;
    let green = 0;
    let blue = 0;
    let count = 0;
    for (let i = 0; i + 3 < bytes.length; i += 4) {
      const a = bytes[i + 3];
      if (a < 128) {
        continue;
      }
      red += bytes[i];
      green += bytes[i + 1];
      blue += bytes[i + 2];
      count++;
    }
    if (count === 0) {
      return null;
    }
    return argbFromRgb(Math.round(red / count), Math.round(green / count), Math.round(blue / count));
  } catch (err) {
    return null;
  } finally {
    client.destroy();
  }
}

function argbFromRgb(r: number, g: number, b: number): string {
  const hex = (v: number): string => {
    const s = Math.min(Math.max(Math.round(v), 0), 255).toString(16);
    return s.length === 1 ? `0${s}` : s;
  };
  return `#FF${hex(r)}${hex(g)}${hex(b)}`;
}
