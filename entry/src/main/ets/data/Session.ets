import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { JObj, parseJson, parseJsonArray, jObjAt, jStr } from './Json';
import { Mutex } from './Json';
import { ProviderKind, PROVIDER_JIANYIN, PROVIDER_SUBSONIC } from './ProviderTypes';

export class User {
  readonly id: string;
  readonly username: string;
  readonly nickname: string;
  readonly avatarUrl: string;
  readonly role: string;

  constructor(id: string, username: string, nickname: string, avatarUrl: string, role: string) {
    this.id = id;
    this.username = username;
    this.nickname = nickname;
    this.avatarUrl = avatarUrl;
    this.role = role;
  }

  get displayName(): string {
    return this.nickname.length > 0 ? this.nickname : this.username;
  }

  static from(json: JObj | null): User | null {
    if (json === null) {
      return null;
    }
    return new User(
      jStr(json, 'id'),
      jStr(json, 'username'),
      jStr(json, 'nickname', jStr(json, 'username')),
      jStr(json, 'avatar_url'),
      jStr(json, 'role', 'user'),
    );
  }

  toJson(): string {
    const obj: Record<string, Object> = {
      'id': this.id,
      'username': this.username,
      'nickname': this.nickname,
      'avatar_url': this.avatarUrl,
      'role': this.role,
    };
    return JSON.stringify(obj);
  }
}

/** 本机缓存的登录：只存服务类型、服务器与用户名，供登录页快捷填充，不含令牌。 */
export class SavedLogin {
  readonly kind: ProviderKind;
  readonly baseUrl: string;
  readonly username: string;
  readonly nickname: string;

  constructor(kind: ProviderKind, baseUrl: string, username: string, nickname: string) {
    this.kind = kind;
    this.baseUrl = baseUrl;
    this.username = username;
    this.nickname = nickname;
  }

  get key(): string {
    return `${this.kind}|${this.baseUrl}|${this.username}`;
  }

  get host(): string {
    try {
      const idx = this.baseUrl.indexOf('://');
      const after = idx >= 0 ? this.baseUrl.substring(idx + 3) : this.baseUrl;
      const trimmed = after.replace(/\/+$/, '');
      return trimmed.length > 0 ? trimmed : this.baseUrl;
    } catch (err) {
      return this.baseUrl;
    }
  }
}

/**
 * 全局登录会话（等价于安卓端 Session 单例 + StateFlow）。
 * @ObservedV2 让 user / accounts 的变化自动刷新所有观察它的 UI。
 */
@ObservedV2
export class SessionStore {
  static readonly DEFAULT_BASE: string = '';

  private static readonly KEY_BASE = 'base_url';
  private static readonly KEY_SUB_BASE = 'subsonic_base_url';
  private static readonly KEY_PROVIDER = 'provider_kind';
  private static readonly KEY_ACCESS = 'access_token';
  private static readonly KEY_REFRESH = 'refresh_token';
  private static readonly KEY_SUB_USER = 'subsonic_username';
  private static readonly KEY_SUB_SALT = 'subsonic_salt';
  private static readonly KEY_SUB_TOKEN = 'subsonic_token';
  private static readonly KEY_GUEST = 'guest_mode';
  private static readonly KEY_USER = 'user';
  private static readonly KEY_ACCOUNTS = 'accounts';

  private prefs: preferences.Preferences | null = null;
  private persistLock = new Mutex();

  @Trace user: User | null = null;
  @Trace savedLogins: SavedLogin[] = [];
  @Trace providerKind: ProviderKind = PROVIDER_JIANYIN;
  @Trace guestMode: boolean = false;
  /** 登录/登出/换服务时自增，根页面据此重建数据视图模型。 */
  @Trace dataVersion: number = 0;

  init(context: common.Context): void {
    this.prefs = preferences.getPreferencesSync(context, { name: 'music_session' });
    const savedKind = this.getString(SessionStore.KEY_PROVIDER, PROVIDER_JIANYIN);
    this.providerKind = savedKind === PROVIDER_SUBSONIC ? PROVIDER_SUBSONIC : PROVIDER_JIANYIN;
    this.guestMode = this.getBool(SessionStore.KEY_GUEST, false);
    this.user = this.guestMode ? null : this.parseUser(this.getString(SessionStore.KEY_USER, ''));
    this.savedLogins = this.parseLogins(this.getString(SessionStore.KEY_ACCOUNTS, ''));
  }

  setProviderKind(kind: ProviderKind): void {
    this.providerKind = kind;
    this.putString(SessionStore.KEY_PROVIDER, kind);
  }

  setGuestMode(value: boolean): void {
    this.guestMode = value;
    this.putBool(SessionStore.KEY_GUEST, value);
  }

  /** 进入游客模式：清空凭证与用户，只保留服务类型和地址。 */
  enterGuest(): void {
    this.clearCredentials();
    this.guestMode = true;
    this.putBool(SessionStore.KEY_GUEST, true);
    this.dataVersion = this.dataVersion + 1;
  }

  private getBool(key: string, def: boolean): boolean {
    if (this.prefs === null) {
      return def;
    }
    try {
      const v = this.prefs.getSync(key, def);
      return typeof v === 'boolean' ? v : def;
    } catch (err) {
      return def;
    }
  }

  private putBool(key: string, value: boolean): void {
    if (this.prefs === null) {
      return;
    }
    try {
      this.prefs.putSync(key, value);
      this.prefs.flush();
    } catch (err) {
    }
  }

  private getString(key: string, def: string): string {
    if (this.prefs === null) {
      return def;
    }
    try {
      const v = this.prefs.getSync(key, def);
      return typeof v === 'string' ? v : def;
    } catch (err) {
      return def;
    }
  }

  private putString(key: string, value: string): void {
    if (this.prefs === null) {
      return;
    }
    try {
      this.prefs.putSync(key, value);
      this.prefs.flush();
    } catch (err) {
    }
  }

  get baseUrl(): string {
    return this.baseUrlFor(this.providerKind);
  }

  baseUrlFor(kind: ProviderKind): string {
    if (kind === PROVIDER_SUBSONIC) {
      return this.getString(SessionStore.KEY_SUB_BASE, '');
    }
    const v = this.getString(SessionStore.KEY_BASE, SessionStore.DEFAULT_BASE);
    return v.length > 0 ? v : SessionStore.DEFAULT_BASE;
  }

  setBaseUrl(raw: string): void {
    const key = this.providerKind === PROVIDER_SUBSONIC
      ? SessionStore.KEY_SUB_BASE : SessionStore.KEY_BASE;
    this.putString(key, this.normalizeBase(raw));
  }

  get accessToken(): string {
    return this.getString(SessionStore.KEY_ACCESS, '');
  }

  get refreshToken(): string {
    return this.getString(SessionStore.KEY_REFRESH, '');
  }

  get subsonicUsername(): string {
    return this.getString(SessionStore.KEY_SUB_USER, '');
  }

  get subsonicSalt(): string {
    return this.getString(SessionStore.KEY_SUB_SALT, '');
  }

  get subsonicToken(): string {
    return this.getString(SessionStore.KEY_SUB_TOKEN, '');
  }

  get loggedIn(): boolean {
    if (this.guestMode) {
      return false;
    }
    if (this.providerKind === PROVIDER_SUBSONIC) {
      return this.subsonicToken.length > 0 && this.subsonicUsername.length > 0;
    }
    return this.accessToken.length > 0 || this.refreshToken.length > 0;
  }

  saveTokens(access: string, refresh: string): void {
    this.putString(SessionStore.KEY_ACCESS, access);
    this.putString(SessionStore.KEY_REFRESH, refresh);
  }

  saveUser(user: User | null): void {
    this.putString(SessionStore.KEY_USER, user !== null ? user.toJson() : '');
    this.user = user;
  }

  saveLogin(access: string, refresh: string, user: User | null): void {
    this.putString(SessionStore.KEY_ACCESS, access);
    this.putString(SessionStore.KEY_REFRESH, refresh);
    this.putString(SessionStore.KEY_USER, user !== null ? user.toJson() : '');
    this.user = user;
    this.setGuestMode(false);
    this.dataVersion = this.dataVersion + 1;
    if (user !== null) {
      this.upsertLogin(new SavedLogin(PROVIDER_JIANYIN, this.baseUrl, user.username, user.nickname));
    }
  }

  saveSubsonicLogin(username: string, salt: string, token: string, user: User | null): void {
    this.putString(SessionStore.KEY_SUB_USER, username);
    this.putString(SessionStore.KEY_SUB_SALT, salt);
    this.putString(SessionStore.KEY_SUB_TOKEN, token);
    this.putString(SessionStore.KEY_USER, user !== null ? user.toJson() : '');
    this.user = user;
    this.setGuestMode(false);
    this.dataVersion = this.dataVersion + 1;
    if (user !== null) {
      this.upsertLogin(new SavedLogin(PROVIDER_SUBSONIC, this.baseUrl, user.username, user.nickname));
    }
  }

  /** 删除一条快捷填充记录。 */
  removeSavedLogin(key: string): void {
    this.persistLogins(this.savedLogins.filter((a: SavedLogin): boolean => a.key !== key));
  }

  /** 退出登录：丢弃令牌，只保留服务类型/服务器/用户名，供登录页快捷填充。 */
  clear(): void {
    const current = this.user;
    const kind = this.providerKind;
    this.clearActiveSession();
    if (current !== null) {
      this.upsertLogin(new SavedLogin(kind, this.baseUrl, current.username, current.nickname));
    }
  }

  private clearCredentials(): void {
    if (this.prefs !== null) {
      try {
        this.prefs.deleteSync(SessionStore.KEY_ACCESS);
        this.prefs.deleteSync(SessionStore.KEY_REFRESH);
        this.prefs.deleteSync(SessionStore.KEY_SUB_USER);
        this.prefs.deleteSync(SessionStore.KEY_SUB_SALT);
        this.prefs.deleteSync(SessionStore.KEY_SUB_TOKEN);
        this.prefs.deleteSync(SessionStore.KEY_USER);
        this.prefs.flush();
      } catch (err) {
      }
    }
    this.user = null;
  }

  private clearActiveSession(): void {
    this.clearCredentials();
    this.guestMode = false;
    this.putBool(SessionStore.KEY_GUEST, false);
    this.dataVersion = this.dataVersion + 1;
  }

  private upsertLogin(login: SavedLogin): void {
    const next = this.savedLogins.filter((a: SavedLogin): boolean => a.key !== login.key);
    next.push(login);
    this.persistLogins(next);
  }

  private persistLogins(list: SavedLogin[]): void {
    this.savedLogins = list;
    const array: Object[] = [];
    for (const login of list) {
      const item: Record<string, Object> = {
        'provider': login.kind,
        'base_url': login.baseUrl,
        'username': login.username,
        'nickname': login.nickname,
      };
      array.push(item);
    }
    this.putString(SessionStore.KEY_ACCOUNTS, JSON.stringify(array));
  }

  mediaUrl(path: string | null): string {
    if (path === null || path.length === 0) {
      return '';
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return this.baseUrl + (path.startsWith('/') ? path : `/${path}`);
  }

  normalizeBase(raw: string, kind: ProviderKind = this.providerKind): string {
    // 全角字符转半角并去掉所有空格（与安卓端一致）。
    const chars: string[] = [];
    for (const ch of raw.trim()) {
      const code = ch.charCodeAt(0);
      if (code >= 0xFF01 && code <= 0xFF5E) {
        chars.push(String.fromCharCode(code - 0xFEE0));
      } else {
        chars.push(ch);
      }
    }
    let value = chars.join('').split(' ').join('');
    if (value.length === 0) {
      return kind === PROVIDER_SUBSONIC ? '' : SessionStore.DEFAULT_BASE;
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = `http://${value}`;
    }
    const schemeEnd = value.indexOf('://') + 3;
    if (schemeEnd <= 3 || schemeEnd >= value.length) {
      return kind === PROVIDER_SUBSONIC ? '' : SessionStore.DEFAULT_BASE;
    }
    const rest = value.substring(schemeEnd);
    const slash = rest.indexOf('/');
    let authority = slash >= 0 ? rest.substring(0, slash) : rest;
    const tail = slash >= 0 ? rest.substring(slash) : '';
    // 简音后端习惯用 8000；Subsonic/Navidrome 端口由用户自己填，不能擅自补 8000。
    if (kind !== PROVIDER_SUBSONIC && value.startsWith('http://') &&
      /^\d{1,3}(\.\d{1,3}){3}$/.test(authority)) {
      authority += ':8000';
    }
    value = value.substring(0, schemeEnd) + authority + tail;
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (kind !== PROVIDER_SUBSONIC && value.endsWith('/api/v1')) {
      value = value.substring(0, value.length - '/api/v1'.length);
    }
    if (kind === PROVIDER_SUBSONIC && value.endsWith('/rest')) {
      value = value.substring(0, value.length - '/rest'.length);
    }
    return value;
  }

  private parseUser(raw: string): User | null {
    if (raw.length === 0) {
      return null;
    }
    try {
      return User.from(parseJson(raw));
    } catch (err) {
      return null;
    }
  }

  private parseLogins(raw: string): SavedLogin[] {
    if (raw.length === 0) {
      return [];
    }
    try {
      const parsed = parseJsonArray(raw);
      if (parsed === null) {
        return [];
      }
      const list: SavedLogin[] = [];
      for (let index = 0; index < parsed.length; index++) {
        const item = jObjAt(parsed, index);
        if (item === null) {
          continue;
        }
        const baseUrl = jStr(item, 'base_url');
        const username = jStr(item, 'username');
        if (baseUrl.length === 0 || username.length === 0) {
          continue;
        }
        const kind: ProviderKind = jStr(item, 'provider', PROVIDER_JIANYIN) === PROVIDER_SUBSONIC
          ? PROVIDER_SUBSONIC : PROVIDER_JIANYIN;
        list.push(new SavedLogin(kind, baseUrl, username, jStr(item, 'nickname', username)));
      }
      return list;
    } catch (err) {
      return [];
    }
  }
}

export const Session: SessionStore = new SessionStore();

