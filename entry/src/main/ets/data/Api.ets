import { http } from '@kit.NetworkKit';
import { Session, User } from './Session';
import { JObj, parseJson, jObj, jStr, Mutex, errText } from './Json';

export class ApiException extends Error {
  readonly status: number;

  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

export class LoginResult {
  readonly user: User | null;
  readonly accessToken: string;
  readonly refreshToken: string;

  constructor(user: User | null, accessToken: string, refreshToken: string) {
    this.user = user;
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }
}

class RawResponse {
  readonly status: number;
  readonly text: string;

  constructor(status: number, text: string) {
    this.status = status;
    this.text = text;
  }
}

/** 全局 HTTP 客户端：统一 /api/v1 前缀、Bearer 鉴权与 401 自动刷新重试。 */
export class ApiClient {
  private refreshMutex = new Mutex();

  async getObject(path: string, params: Map<string, string> = new Map(), auth: boolean = true): Promise<JObj> {
    const data = await this.request('GET', path, params, null, auth);
    return (data instanceof Object && !(data instanceof Array)) ? data as JObj : {} as JObj;
  }

  async getArray(path: string, params: Map<string, string> = new Map(), auth: boolean = true): Promise<Object[]> {
    const data = await this.request('GET', path, params, null, auth);
    return data instanceof Array ? data as Object[] : [];
  }

  async postObject(path: string, body: Record<string, Object> | null = null, auth: boolean = true): Promise<JObj> {
    const data = await this.request('POST', path, new Map(), body, auth);
    return (data instanceof Object && !(data instanceof Array)) ? data as JObj : {} as JObj;
  }

  async patchObject(path: string, body: Record<string, Object> | null = null, auth: boolean = true): Promise<JObj> {
    const data = await this.request('PATCH', path, new Map(), body, auth);
    return (data instanceof Object && !(data instanceof Array)) ? data as JObj : {} as JObj;
  }

  async putObject(path: string, body: Record<string, Object> | null = null, auth: boolean = true): Promise<JObj> {
    const data = await this.request('PUT', path, new Map(), body, auth);
    return (data instanceof Object && !(data instanceof Array)) ? data as JObj : {} as JObj;
  }

  async deleteObject(path: string, auth: boolean = true): Promise<JObj> {
    const data = await this.request('DELETE', path, new Map(), null, auth);
    return (data instanceof Object && !(data instanceof Array)) ? data as JObj : {} as JObj;
  }

  async login(account: string, password: string): Promise<LoginResult> {
    const body: Record<string, Object> = {
      'account': account,
      'password': password,
    };
    const data = await this.postObject('/auth/login', body, false);
    return this.parseLogin(data);
  }

  async register(username: string, password: string, nickname: string): Promise<LoginResult> {
    const body: Record<string, Object> = {
      'username': username,
      'password': password,
    };
    if (nickname.trim().length > 0) {
      body['nickname'] = nickname;
    }
    const data = await this.postObject('/auth/register', body, false);
    return this.parseLogin(data);
  }

  async logout(): Promise<void> {
    try {
      const body: Record<string, Object> = { 'refresh_token': Session.refreshToken };
      await this.postObject('/auth/logout', body);
    } catch (err) {
    }
  }

  private parseLogin(data: JObj): LoginResult {
    const tokenJson = jObj(data, 'tokens');
    return new LoginResult(
      User.from(jObj(data, 'user')),
      tokenJson !== null ? jStr(tokenJson, 'access_token', '') : '',
      tokenJson !== null ? jStr(tokenJson, 'refresh_token', '') : '',
    );
  }

  private async request(method: string, path: string, params: Map<string, string>,
    body: Record<string, Object> | null, auth: boolean, retried: boolean = false): Promise<Object | null> {
    const tokenUsed = auth ? Session.accessToken : '';
    const response = await this.execute(method, this.buildUrl(path, params), tokenUsed, body);
    if (response.status === 401 && auth && !retried && Session.refreshToken.length > 0) {
      await this.refreshAccessToken(tokenUsed);
      return this.request(method, path, params, body, auth, true);
    }
    return this.parse(response);
  }

  private async refreshAccessToken(failedAccess: string): Promise<void> {
    await this.refreshMutex.lock(async (): Promise<void> => {
      if (Session.accessToken !== failedAccess) {
        return;
      }
      const body: Record<string, Object> = { 'refresh_token': Session.refreshToken };
      const response = await this.execute(
        'POST', this.buildUrl('/auth/refresh', new Map()), '', body);
      const json = parseJson(response.text);
      const data = json !== null ? jObj(json, 'data') : null;
      const access = data !== null ? jStr(data, 'access_token', '') : '';
      const refresh = data !== null ? jStr(data, 'refresh_token', '') : '';
      if (response.status >= 400 || access.length === 0 || refresh.length === 0) {
        Session.clear();
        throw new ApiException(401, '登录已过期，请重新登录');
      }
      Session.saveTokens(access, refresh);
    });
  }

  private parse(response: RawResponse): Object | null {
    if (response.text.trim().length === 0) {
      if (response.status >= 400) {
        throw new ApiException(response.status, `服务器响应异常（HTTP ${response.status}）`);
      }
      return null;
    }
    const json = parseJson(response.text);
    if (json === null) {
      throw new ApiException(response.status, '服务器返回了非 JSON 响应');
    }
    const code = this.optInt(json, 'code', response.status);
    if (response.status >= 400 || code !== 0) {
      if (response.status === 401) {
        Session.clear();
      }
      throw new ApiException(response.status, jStr(json, 'message', '请求失败'));
    }
    const data = json['data'];
    if (data === undefined || data === null) {
      return null;
    }
    return data;
  }

  private optInt(o: JObj, key: string, def: number): number {
    const v = o[key];
    if (typeof v === 'number') {
      return v;
    }
    return def;
  }

  private buildUrl(path: string, params: Map<string, string>): string {
    const normalized = path.startsWith('/') ? path : `/${path}`;
    let builder = `${trimSlash(Session.baseUrl)}/api/v1${normalized}`;
    let first = true;
    params.forEach((value: string, key: string): void => {
      if (value.length === 0) {
        return;
      }
      builder += first ? '?' : '&';
      builder += encodeURIComponent(key);
      builder += '=';
      builder += encodeURIComponent(value);
      first = false;
    });
    return builder;
  }

  private async execute(method: string, url: string, token: string,
    body: Record<string, Object> | null): Promise<RawResponse> {
    const client = http.createHttp();
    try {
      const header: Record<string, string> = {
        'Accept': 'application/json',
      };
      if (token.length > 0) {
        header['Authorization'] = `Bearer ${token}`;
      }
      if (body !== null) {
        header['Content-Type'] = 'application/json; charset=utf-8';
      }
      let requestMethod: http.RequestMethod;
      switch (method) {
        case 'GET':
          requestMethod = http.RequestMethod.GET;
          break;
        case 'POST':
          requestMethod = http.RequestMethod.POST;
          break;
        case 'PATCH':
          requestMethod = http.RequestMethod.PATCH;
          break;
        case 'PUT':
          requestMethod = http.RequestMethod.PUT;
          break;
        case 'DELETE':
          requestMethod = http.RequestMethod.DELETE;
          break;
        default:
          requestMethod = http.RequestMethod.GET;
          break;
      }
      const options: http.HttpRequestOptions = {
        method: requestMethod,
        header: header,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 30000,
        usingCache: false,
      };
      if (body !== null) {
        options.extraData = JSON.stringify(body);
      }
      const resp = await client.request(url, options);
      const text = typeof resp.result === 'string' ? resp.result as string : '';
      return new RawResponse(resp.responseCode, text);
    } catch (error) {
      throw new ApiException(0, `无法连接 ${hostOf(url)}：${errText(error, '网络错误')}`);
    } finally {
      client.destroy();
    }
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
  const m: RegExpExecArray | null = /^[a-zA-Z]+:\/\/([^/?#]+)/.exec(url);
  if (m === null) {
    return url;
  }
  return m[1];
}

export const Api: ApiClient = new ApiClient();
