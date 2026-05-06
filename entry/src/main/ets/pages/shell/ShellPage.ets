import router from '@ohos.router';

type ViewState = 'empty' | 'loading' | 'error';

@Entry
@Component
export struct ShellPage {
  @State shellState: ViewState = 'empty';

  private nextState(): void {
    if (this.shellState === 'empty') {
      this.shellState = 'loading';
      return;
    }
    if (this.shellState === 'loading') {
      this.shellState = 'error';
      return;
    }
    this.shellState = 'empty';
  }

  private goPerson(): void {
    router.pushUrl({ url: 'pages/person/PersonPage' });
  }

  private goStory(): void {
    router.pushUrl({ url: 'pages/story/StoryPage' });
  }

  build() {
    Column({ space: 12 }) {
      Text('时光故事 - 主壳页')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)

      Text(`当前状态：${this.shellState}`)

      Row({ space: 8 }) {
        Button('人物')
          .onClick(() => this.goPerson())
        Button('故事')
          .onClick(() => this.goStory())
      }

      if (this.shellState === 'empty') {
        Text('空态：请选择人物或故事入口')
      } else if (this.shellState === 'loading') {
        Text('加载态：正在初始化导航...')
      } else {
        Text('错误态：导航初始化失败，可重试')
      }

      Button('切换状态')
        .onClick(() => this.nextState())
    }
    .padding(16)
    .width('100%')
    .height('100%')
  }
}
