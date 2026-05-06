import router from '@ohos.router';

type ViewState = 'empty' | 'loading' | 'error';

@Entry
@Component
export struct PersonPage {
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
      Text('人物列表壳页')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)

      Text(`当前状态：${this.pageState}`)

      Row({ space: 8 }) {
        Button('返回主壳')
          .onClick(() => router.back())
        Button('切到故事')
          .onClick(() => router.pushUrl({ url: 'pages/story/StoryPage' }))
      }

      Row({ space: 8 }) {
        Button('进入人物详情空态')
          .onClick(() => router.pushUrl({ url: 'pages/person/PersonDetailPage' }))
        Button('进入建议页')
          .onClick(() => router.pushUrl({ url: 'pages/suggest/SuggestPage' }))
      }

      if (this.pageState === 'empty') {
        Text('空态：暂无人物，点击详情可验证空态可进入')
      } else if (this.pageState === 'loading') {
        Text('加载态：人物列表加载中...')
      } else {
        Text('错误态：人物列表加载失败，可重试')
      }

      Button('切换状态')
        .onClick(() => this.nextState())
    }
    .padding(16)
    .width('100%')
    .height('100%')
  }
}
