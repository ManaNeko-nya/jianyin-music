import { Session, User, SavedLogin } from '../../data/Session';
import {
  AppSettings, LanguageMode, ThemeMode, languageModeDescription, languageModeLabel,
  themeModeDescription, themeModeLabel,
} from '../../data/AppSettings';
import { L10n } from '../../data/L10n';
import { Theme, Typo, withAlpha } from '../Theme';
import {
  InkText, Kicker, Hairline, PageHeader, InkButton, TextAction, UnderlinedField,
  AppTopBar,
} from '../Components';
import { InkGlyph, IconName } from '../Icons';
import { AppModalSheet } from '../AppModalSheet';
import { AppUI, TopBarState } from '../AppState';
import { SecondaryTitleBar } from '../TopBar';
import { AppNav } from '../AppNav';
import { ProfileViewModel } from '../ScreenViewModels';
import {
  ProviderKind, PROVIDER_JIANYIN, PROVIDER_SUBSONIC, providerLabel,
} from '../../data/ProviderTypes';

@ComponentV2
export struct ProfileScreen {
  @Local showTheme: boolean = false;
  @Local showLanguage: boolean = false;
  @Local showRestart: boolean = false;
  @Local vm: ProfileViewModel = new ProfileViewModel();

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: 0 }) {
        PageHeader({ title: '我的' })
        if (Session.user === null) {
          Column({ space: 0 }) {
            if (Session.guestMode) {
              InkText({
                text: L10n.fmt('fmt_guest_mode', [Session.baseUrl]),
                style: Typo.bodySmall,
                color: Theme.ink.inkMuted,
                lines: 1,
              })
                .width('100%')
                .padding({ left: 20, right: 20, top: 8, bottom: 4 })
            }
            GuestPanel({
              onOpenThemeSettings: (): void => {
                this.showTheme = true;
              },
              onOpenLanguageSettings: (): void => {
                this.showLanguage = true;
              },
            })
              .layoutWeight(1)
              .width('100%')
          }
          .layoutWeight(1)
          .width('100%')
        } else {
          AccountPanel({
            user: Session.user as User,
            vm: this.vm,
            onOpenThemeSettings: (): void => {
              this.showTheme = true;
            },
            onOpenLanguageSettings: (): void => {
              this.showLanguage = true;
            },
          })
            .layoutWeight(1)
            .width('100%')
        }
      }
      .width('100%')
      .height('100%')

      if (this.showTheme) {
        ThemePickerSheet({ onDismiss: (): void => {
          this.showTheme = false;
        } })
      }

      if (this.showLanguage) {
        LanguagePickerSheet({ onDismiss: (): void => {
          this.showLanguage = false;
          this.showRestart = true;
        } })
      }

      if (this.showRestart) {
        RestartNoticeSheet({ onDismiss: (): void => {
          this.showRestart = false;
        } })
      }
    }
    .width('100%')
    .height('100%')
  }
}

/** 未登录的「我的」页：登录入口走二级页面，本页只留设置分组。 */
@ComponentV2
struct GuestPanel {
  @Event onOpenThemeSettings: () => void = () => {
  };
  @Event onOpenLanguageSettings: () => void = () => {
  };

  build() {
    Scroll() {
      Column({ space: 0 }) {
        Row().height(12)
        Row({ space: 0 }) {
          Stack({ alignContent: Alignment.Center }) {
            InkGlyph({ name: 'person', boxSize: 28, color: Theme.ink.inkMuted })
          }
          .width(58)
          .height(58)
          .borderRadius(29)
          .backgroundColor(Theme.ink.fill)

          Row().width(16).height(1)
          Column({ space: 0 }) {
            InkText({ text: '登录账户', style: Typo.headlineSmall, color: Theme.ink.ink })
            Row().height(5)
            InkText({
              text: '登录后同步歌单与收藏',
              style: Typo.bodySmall,
              color: Theme.ink.inkMuted,
            })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          InkGlyph({ name: 'chevronRight', boxSize: 20, color: Theme.ink.inkMuted })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding(16)
        .borderRadius(20)
        .backgroundColor(Theme.ink.raised)
        .onClick((): void => AppNav.openLogin())

        SettingsGroup({
          onOpenThemeSettings: (): void => this.onOpenThemeSettings(),
          onOpenLanguageSettings: (): void => this.onOpenLanguageSettings(),
        })

        Row().height(26)
        InkText({
          text: L10n.fmt('fmt_service', [Session.baseUrl]),
          style: Typo.bodySmall,
          color: withAlpha(Theme.ink.inkMuted, 0.55),
          lines: 1,
        })
        Row().height(26 + AppNav.floatClearance)
      }
      .width('100%')
      .padding({ left: 22, right: 22 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }
}

/** 设置分组：登录前后一致，差异只在页面上方的账户区。 */
@ComponentV2
struct SettingsGroup {
  @Event onOpenThemeSettings: () => void = () => {
  };
  @Event onOpenLanguageSettings: () => void = () => {
  };

  private languageSubtitle(): string {
    const mode = AppSettings.languageMode;
    return L10n.tr(languageModeLabel(mode)) + ' · ' + L10n.tr(languageModeDescription(mode));
  }

  build() {
    Column({ space: 0 }) {
      Row().height(34)
      Kicker({ text: '设置' })
      Row().height(4)
      Hairline()
      SettingRow({
        icon: 'darkMode',
        title: '外观主题',
        subtitle: L10n.tr(themeModeLabel(AppSettings.themeMode)) + ' · ' +
          L10n.tr(themeModeDescription(AppSettings.themeMode)),
        onTap: (): void => this.onOpenThemeSettings(),
      })
      Hairline()
      SettingRow({
        icon: 'swap',
        title: '语言',
        subtitle: this.languageSubtitle(),
        onTap: (): void => this.onOpenLanguageSettings(),
      })
      Hairline()
      SettingRow({
        icon: 'info',
        title: '关于简音',
        subtitle: '版本、服务器与客户端信息',
        onTap: (): void => AppNav.openAbout(),
        trailingVersion: '1.0.0',
      })
      Hairline()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/** 登录 / 注册：从「我的」页进入的二级页面。 */
@ComponentV2
export struct LoginScreen {
  @Local vm: ProfileViewModel = new ProfileViewModel();
  @Local registerMode: boolean = false;
  @Local provider: ProviderKind = Session.providerKind;
  @Local server: string = Session.baseUrl;
  @Local account: string = '';
  @Local password: string = '';
  @Local nickname: string = '';
  @Local bar: TopBarState = new TopBarState();

  private submit(): void {
    AppUI.keyboardHide();
    if (this.registerMode) {
      this.vm.register(this.server, this.account, this.password, this.nickname)
        .then((ok: boolean): void => {
          if (ok) {
            this.finishAuth();
          }
        });
    } else {
      this.vm.login(this.provider, this.server, this.account, this.password)
        .then((ok: boolean): void => {
          if (ok) {
            this.finishAuth();
          }
        });
    }
  }

  private enterGuest(): void {
    AppUI.keyboardHide();
    this.registerMode = false;
    this.vm.guest(this.provider, this.server).then((ok: boolean): void => {
      if (ok) {
        this.finishAuth();
      }
    });
  }

  /** 登录成功直接返回：四个页签监听 Session.dataVersion，会各自重新拉取内容，不需要重启 App。 */
  private finishAuth(): void {
    AppUI.keyboardHide();
    AppNav.pop();
  }

  @Builder
  private providerChip(label: string, kind: ProviderKind) {
    InkText({
      text: label,
      style: Typo.labelLarge,
      color: this.provider === kind ? Theme.ink.onAccent : Theme.ink.ink,
    })
      .padding({ left: 14, right: 14, top: 9, bottom: 9 })
      .borderRadius(20)
      .backgroundColor(this.provider === kind ? Theme.ink.accent : Theme.ink.fill)
      .onClick((): void => {
        this.provider = kind;
        this.server = Session.baseUrlFor(kind);
        if (kind !== PROVIDER_JIANYIN) {
          this.registerMode = false;
        }
      })
  }

  private providerLogins(): SavedLogin[] {
    return Session.savedLogins.filter((saved: SavedLogin): boolean => saved.kind === this.provider);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: 0 }) {
        Scroll() {
        Column({ space: 0 }) {
          Row().height(AppTopBar.contentTop())
          Row().height(8)
          InkText({
            text: this.registerMode ? '创建账户' : '登录账户',
            style: Typo.displaySmall,
            color: Theme.ink.ink,
          })
          Row().height(8)
          InkText({
            text: this.registerMode ? '注册后即可同步歌单与收藏。'
              : '服务器、账号与登录令牌都保存在本机，可随时切换。',
            style: Typo.bodyMedium,
            color: Theme.ink.inkMuted,
          })

          Row().height(24)
          Kicker({ text: '服务类型' })
          Row().height(10)
          Row({ space: 8 }) {
            this.providerChip('GuoBeng', PROVIDER_JIANYIN)
            this.providerChip('Navidrome', PROVIDER_SUBSONIC)
          }
          .width('100%')

          if (!this.registerMode && this.providerLogins().length > 0) {
            Row().height(26)
            Kicker({ text: '快捷填充' })
            Row().height(12)
            Scroll() {
              Row({ space: 8 }) {
                ForEach(this.providerLogins(), (saved: SavedLogin) => {
                  Row({ space: 0 }) {
                    InkGlyph({ name: 'person', boxSize: 14, color: Theme.ink.inkMuted })
                    Row().width(7).height(1)
                    InkText({
                      text: `${saved.nickname} · ${providerLabel(saved.kind)} · ${saved.host}`,
                      style: Typo.labelLarge,
                      color: Theme.ink.ink,
                      lines: 1,
                    })
                  }
                  .alignItems(VerticalAlign.Center)
                  .borderRadius(20)
                  .backgroundColor(Theme.ink.fill)
                  .padding({ left: 13, right: 13, top: 9, bottom: 9 })
                  .onClick((): void => {
                    this.provider = saved.kind;
                    this.server = saved.baseUrl;
                    this.account = saved.username;
                    if (saved.kind !== PROVIDER_JIANYIN) {
                      this.registerMode = false;
                    }
                  })
                  .gesture(LongPressGesture({ repeat: false, duration: 500 })
                    .onAction((): void => {
                      Session.removeSavedLogin(saved.key);
                      AppUI.toast('已删除该登录记录');
                    }))
                }, (saved: SavedLogin) => saved.key)
              }
              .alignItems(VerticalAlign.Center)
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')
            .height(40)
          }

          Row().height(30)
          UnderlinedField({
            value: this.server,
            onValueChange: (v: string): void => {
              this.server = v;
            },
            label: '服务器地址',
            placeholder: this.provider === PROVIDER_SUBSONIC
              ? 'http://your-server:4533' : 'http://your-server:8000',
            enterKey: EnterKeyType.Next,
          })
          Row().height(6)
          InkText({
            text: this.provider === PROVIDER_SUBSONIC
              ? '填 Navidrome/Subsonic 的根地址，默认端口通常是 4533，不要带 /rest'
              : '真机填电脑的局域网 IP 和端口，例如 http://your-server:8000',
            style: Typo.bodySmall,
            color: Theme.ink.inkMuted,
          })
          Row().height(20)
          UnderlinedField({
            value: this.account,
            onValueChange: (v: string): void => {
              this.account = v;
            },
            label: this.registerMode ? '用户名' : '账号',
            placeholder: this.registerMode ? '设置一个用户名' : '你的账号',
            enterKey: EnterKeyType.Next,
          })
          if (this.registerMode) {
            Row().height(18)
            UnderlinedField({
              value: this.nickname,
              onValueChange: (v: string): void => {
                this.nickname = v;
              },
              label: '昵称',
              placeholder: '可留空',
              enterKey: EnterKeyType.Next,
            })
          }
          Row().height(18)
          UnderlinedField({
            value: this.password,
            onValueChange: (v: string): void => {
              this.password = v;
            },
            label: '密码',
            placeholder: '输入密码',
            isPassword: true,
            enterKey: EnterKeyType.Done,
            onImeAction: (): void => {
              if (this.account.length > 0 && this.password.length > 0) {
                this.submit();
              }
            },
          })
          if (this.vm.state.error.length > 0) {
            Row().height(12)
            InkText({ text: this.vm.state.error, style: Typo.bodySmall, color: Theme.ink.danger })
          }
          Row().height(28)
          InkButton({
            text: this.registerMode ? '注册并登录' : '登录',
            onTap: (): void => this.submit(),
            isEnabled: this.account.length > 0 && this.password.length > 0,
            loading: this.vm.state.loading,
          })
          Row().height(4)
          Row() {
            TextAction({
              text: '仅浏览（游客模式）',
              onTap: (): void => this.enterGuest(),
              color: Theme.ink.inkSoft,
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)

          if (this.provider === PROVIDER_JIANYIN) {
            Row().height(2)
            Row() {
              TextAction({
                text: this.registerMode ? '已有账号？返回登录' : '没有账号？创建一个',
                onTap: (): void => {
                  this.registerMode = !this.registerMode;
                  this.vm.clearError();
                },
                color: Theme.ink.inkSoft,
              })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
          Row().height(30 + AppNav.floatClearance)
        }
        .width('100%')
        .padding({ left: 22, right: 22 })
        .alignItems(HorizontalAlign.Start)
      }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')

      SecondaryTitleBar({ title: '登录账户', bar: this.bar })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.ink.canvas)
  }
}

@ComponentV2
struct AccountPanel {
  @Param user: User = new User('', '', '', '', '');
  @Param vm: ProfileViewModel = new ProfileViewModel();
  @Event onOpenThemeSettings: () => void = () => {
  };
  @Event onOpenLanguageSettings: () => void = () => {
  };

  private roleLabel(): string {
    switch (this.user.role) {
      case 'root':
        return '超级管理员';
      case 'admin':
        return '管理员';
      default:
        return '普通用户';
    }
  }

  build() {
    Scroll() {
      Column({ space: 0 }) {
        Row().height(12)
        Row({ space: 0 }) {
          if (this.user.avatarUrl.length > 0) {
            Image(Session.mediaUrl(this.user.avatarUrl))
              .objectFit(ImageFit.Cover)
              .draggable(false)
              .width(78)
              .height(78)
              .borderRadius(39)
          } else {
            Stack({ alignContent: Alignment.Center }) {
              InkGlyph({ name: 'person', boxSize: 32, color: Theme.ink.inkMuted })
            }
            .width(78)
            .height(78)
            .borderRadius(39)
            .backgroundColor(Theme.ink.fill)
          }
          Row().width(16).height(1)
          Column({ space: 0 }) {
            InkText({
              text: this.user.displayName,
              style: Typo.headlineLarge,
              color: Theme.ink.ink,
              lines: 1,
            })
            Row().height(3)
            InkText({ text: `@${this.user.username}`, style: Typo.bodyMedium, color: Theme.ink.inkMuted })
            Row().height(5)
            InkText({
              text: this.roleLabel(),
              style: Typo.labelSmall,
              color: withAlpha(Theme.ink.accent, 0.8),
            })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        SettingsGroup({
          onOpenThemeSettings: (): void => this.onOpenThemeSettings(),
          onOpenLanguageSettings: (): void => this.onOpenLanguageSettings(),
        })

        Row().height(26)
        Row({ space: 0 }) {
          InkGlyph({ name: 'logout', boxSize: 17, color: Theme.ink.inkMuted })
          Row().width(8).height(1)
          InkText({ text: '退出登录', style: Typo.labelLarge, color: Theme.ink.inkMuted })
        }
        .alignItems(VerticalAlign.Center)
        .borderRadius(25)
        .padding({ left: 14, right: 14, top: 11, bottom: 11 })
        .onClick((): void => {
          if (!this.vm.state.loading) {
            this.vm.logout();
          }
        })

        if (this.vm.state.error.length > 0) {
          Row().height(8)
          InkText({ text: this.vm.state.error, style: Typo.bodySmall, color: Theme.ink.danger })
        }

        Row().height(52)
        InkText({
          text: L10n.fmt('fmt_service', [Session.baseUrl]),
          style: Typo.bodySmall,
          color: withAlpha(Theme.ink.inkMuted, 0.55),
          lines: 1,
        })
        Row().height(26 + AppNav.floatClearance)
      }
      .width('100%')
      .padding({ left: 22, right: 22 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }
}

@ComponentV2
struct ThemePickerSheet {
  @Event onDismiss: () => void = () => {
  };

  build() {
    AppModalSheet({
      onDismissRequest: () => this.onDismiss(),
      title: '外观主题',
    }) {
      Column({ space: 0 }) {
        Hairline()
        ForEach(ThemeModes.all(), (mode: ThemeMode) => {
          Row({ space: 0 }) {
            Column({ space: 0 }) {
              InkText({ text: themeModeLabel(mode), style: Typo.titleMedium, color: Theme.ink.ink })
              Row().height(2)
              InkText({
                text: themeModeDescription(mode),
                style: Typo.bodySmall,
                color: Theme.ink.inkMuted,
              })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Row().width(14).height(1)
            Stack({ alignContent: Alignment.Center }) {
              if (AppSettings.themeMode === mode) {
                InkGlyph({ name: 'check', boxSize: 15, color: Theme.ink.onAccent })
              }
            }
            .width(24)
            .height(24)
            .borderRadius(12)
            .backgroundColor(AppSettings.themeMode === mode ? Theme.ink.accent : Theme.ink.fill)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .padding({ top: 15, bottom: 15 })
          .onClick((): void => {
            AppSettings.setThemeMode(mode);
            Theme.refresh();
          })
          Hairline()
        }, (mode: ThemeMode) => mode)
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 16 })
    }
  }
}

/** ThemeMode 枚举数组（ForEach 需要）。 */
export class ThemeModes {
  static all(): ThemeMode[] {
    return [ThemeMode.System, ThemeMode.Light, ThemeMode.Dark];
  }
}

@ComponentV2
struct LanguagePickerSheet {
  @Event onDismiss: () => void = () => {
  };

  build() {
    AppModalSheet({
      onDismissRequest: () => this.onDismiss(),
      title: '语言',
    }) {
      Column({ space: 0 }) {
        Hairline()
        ForEach(LanguageModes.all(), (mode: LanguageMode) => {
          Row({ space: 0 }) {
            Column({ space: 0 }) {
              InkText({ text: languageModeLabel(mode), style: Typo.titleMedium, color: Theme.ink.ink })
              Row().height(2)
              InkText({
                text: languageModeDescription(mode),
                style: Typo.bodySmall,
                color: Theme.ink.inkMuted,
              })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Row().width(14).height(1)
            Stack({ alignContent: Alignment.Center }) {
              if (AppSettings.languageMode === mode) {
                InkGlyph({ name: 'check', boxSize: 15, color: Theme.ink.onAccent })
              }
            }
            .width(24)
            .height(24)
            .borderRadius(12)
            .backgroundColor(AppSettings.languageMode === mode ? Theme.ink.accent : Theme.ink.fill)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .padding({ top: 15, bottom: 15 })
          .onClick((): void => {
            AppSettings.setLanguageMode(mode);
            this.onDismiss();
          })
          Hairline()
        }, (mode: LanguageMode) => mode)
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 16 })
    }
  }
}

/** LanguageMode 枚举数组（ForEach 需要）。 */
export class LanguageModes {
  static all(): LanguageMode[] {
    return [LanguageMode.System, LanguageMode.Chinese, LanguageMode.English];
  }
}

@ComponentV2
export struct RestartNoticeSheet {
  @Event onDismiss: () => void = () => {
  };

  build() {
    AppModalSheet({
      onDismissRequest: () => this.onDismiss(),
      title: L10n.fmt('fmt_restart_required', []),
    }) {
      Column({ space: 0 }) {
        Hairline()
        Row().height(16)
        InkText({
          text: L10n.fmt('fmt_restart_body', []),
          style: Typo.bodyMedium,
          color: Theme.ink.inkSoft,
        })
        Row().height(20)
        InkButton({
          text: L10n.fmt('fmt_got_it', []),
          onTap: (): void => this.onDismiss(),
        })
        Row().height(12)
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
    }
  }
}

@ComponentV2
export struct SettingRow {
  @Param icon: IconName = 'info';
  @Param title: string = '';
  @Param subtitle: string = '';
  @Param trailingVersion: string = '';
  @Event onTap: () => void = () => {
  };

  build() {
    Row({ space: 0 }) {
      InkGlyph({ name: this.icon, boxSize: 19, color: Theme.ink.inkMuted })
      Row().width(13).height(1)
      Column({ space: 0 }) {
        InkText({ text: this.title, style: Typo.titleSmall, color: Theme.ink.ink })
        if (this.subtitle.length > 0) {
          Row().height(2)
          InkText({
            text: this.subtitle,
            style: Typo.bodySmall,
            color: Theme.ink.inkMuted,
            lines: 1,
          })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row().width(12).height(1)
      if (this.trailingVersion.length > 0) {
        InkText({
          text: this.trailingVersion,
          style: Typo.labelMedium,
          color: Theme.ink.inkMuted,
        })
        Row().width(6).height(1)
      }
      InkGlyph({ name: 'chevronRight', boxSize: 18, color: Theme.ink.inkMuted })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ top: 14, bottom: 14 })
    .onClick(() => this.onTap())
  }
}

