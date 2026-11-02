import { http } from '@kit.NetworkKit';
import { ApiException } from './Api';
import { JObj, parseJson, jObj, jStr, jInt, errText } from './Json';
import { Session } from './Session';

const API_VERSION: string = '1.16.1';
const CLIENT_NAME: string = 'JianYin';

/** Subsonic/Navidrome 的 HTTP 客户端：负责鉴权参数、JSON 包装和错误转换。 */
export class SubsonicClient {
  private readonly baseUrl: string;
  private readonly username: string;
  private readonly salt: string;
  private readonly token: string;

  constructor(baseUrl: string, username: string, salt: string, token: string) {
    this.baseUrl = trimSlash(baseUrl);
    this.username = username;
    this.salt = salt;
    this.token = token;
  }

  static fromSession(): SubsonicClient {
    if (Session.providerKind !== 'subsonic') {
      throw new ApiException(0, '当前不是 Navidrome/Subsonic 服务');
    }
    if (Session.guestMode) {
      return new SubsonicClient(Session.baseUrl, 'guest', '', '');
    }
    if (Session.subsonicToken.length === 0) {
      throw new ApiException(0, '请先登录 Navidrome/Subsonic 服务');
    }
    return new SubsonicClient(Session.baseUrl, Session.subsonicUsername,
      Session.subsonicSalt, Session.subsonicToken);
  }

  /** 生成带鉴权的媒体 URL，交给 Image/AVPlayer 直接使用。 */
  mediaUrl(method: string, params: Map<string, string>): string {
    return this.buildUrl(method, params);
  }

  async call(method: string, params: Map<string, string> = new Map()): Promise<JObj> {
    const url = this.buildUrl(method, params);
    const response = await this.httpGet(url);
    const root = parseJson(response.text);
    const sub = root !== null ? jObj(root, 'subsonic-response') : null;
    if (sub === null) {
      throw new ApiException(response.status, '服务器返回了非 Subsonic 响应');
    }
    if (jStr(sub, 'status', 'failed') !== 'ok') {
      const error = jObj(sub, 'error');
      const code = error !== null ? jInt(error, 'code') : 0;
      const message = error !== null ? jStr(error, 'message', `Subsonic 错误 ${code}`) : 'Subsonic 请求失败';
      throw new ApiException(response.status >= 400 ? response.status : code, message);
    }
    return sub;
  }

  private buildUrl(method: string, params: Map<string, string>): string {
    let url = `${this.baseUrl}/rest/${method}.view?u=${encodeURIComponent(this.username)}` +
      `&v=${API_VERSION}&c=${CLIENT_NAME}&f=json`;
    if (this.token.length > 0) {
      url += `&t=${encodeURIComponent(this.token)}&s=${encodeURIComponent(this.salt)}`;
    }
    params.forEach((value: string, key: string): void => {
      if (value.length > 0) {
        url += `&${encodeURIComponent(key)}=${encodeURIComponent(value)}`;
      }
    });
    return url;
  }

  private async httpGet(url: string): Promise<SubsonicResponse> {
    const client = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: { 'Accept': 'application/json' },
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 30000,
        usingCache: false,
      };
      const response = await client.request(url, options);
      const text = typeof response.result === 'string' ? response.result as string : '';
      return new SubsonicResponse(response.responseCode, text);
    } catch (error) {
      throw new ApiException(0, `无法连接 ${hostOf(url)}：${errText(error, '网络错误')}`);
    } finally {
      client.destroy();
    }
  }
}

class SubsonicResponse {
  readonly status: number;
  readonly text: string;

  constructor(status: number, text: string) {
    this.status = status;
    this.text = text;
  }
}

function trimSlash(value: string): string {
  let out = value;
  while (out.endsWith('/')) {
    out = out.substring(0, out.length - 1);
  }
  return out;
}

function hostOf(url: string): string {
  const match: RegExpExecArray | null = /^[a-zA-Z]+:\/\/([^/?#]+)/.exec(url);
  return match !== null ? match[1] : url;
}
