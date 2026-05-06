import router from '@ohos.router';

type ViewState = 'empty' | 'loading' | 'error';

@Entry
@Component
export struct StoryPage {
  @State pageState: ViewState = 'empty';

  private nextState(): void {
    if (this.pageState === 'empty') {
      this.pageState = 'loading';
      return;
    }
    if (this.pageState === 'loading') {
      this.pageState = 'error';
      return;
    }
    this.pageState = 'empty';
  }

  build() {
    Column({ space: 12 }) {
      Text('故事列表壳页')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)

      Text(`当前状态：${this.pageState}`)

      Row({ space: 8 }) {
        Button('返回主壳')
          .onClick(() => router.back())
        Button('切到人物')
          .onClick(() => router.pushUrl({ url: 'pages/person/PersonPage' }))
      }

      Button('进入故事详情空态')
        .onClick(() => router.pushUrl({ url: 'pages/story/StoryDetailPage' }))

      if (this.pageState === 'empty') {
        Text('空态：暂无故事，点击详情可验证空态可进入')
      } else if (this.pageState === 'loading') {
        Text('加载态：故事列表加载中...')
      } else {
        Text('错误态：故事列表加载失败，可重试')
      }

      Button('切换状态')
        .onClick(() => this.nextState())
    }
    .padding(16)
    .width('100%')
    .height('100%')
  }
}
