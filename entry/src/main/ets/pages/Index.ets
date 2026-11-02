import { MusicRoot } from '../ui/MusicRoot';
import { Theme } from '../ui/Theme';
import { Backs } from '../ui/AppState';
import { AppNav } from '../ui/AppNav';

// 入口壳使用 V1 组件（@Entry 要求），内部全部为 V2 组件。
@Entry
@Component
struct Index {
  build() {
    Stack() {
      MusicRoot()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.ink.canvas)
  }

  onBackPress(): boolean {
    if (Backs.handle()) {
      return true;
    }
    if (AppNav.canPop) {
      AppNav.pop();
      return true;
    }
    return false;
  }
}
