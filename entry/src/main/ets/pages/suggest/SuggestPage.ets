import router from '@ohos.router';

type ViewState = 'empty' | 'loading' | 'error';

@Entry
@Component
export struct SuggestPage {
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
      Text('建议审阅壳页')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)

      Text(`当前状态：${this.pageState}`)

      Button('返回人物页')
        .onClick(() => router.back())

      if (this.pageState === 'empty') {
        Text('空态：暂无建议')
      } else if (this.pageState === 'loading') {
        Text('加载态：正在加载建议...')
      } else {
        Text('错误态：建议加载失败，可重试')
      }

      Button('切换状态')
        .onClick(() => this.nextState())
    }
    .padding(16)
    .width('100%')
    .height('100%')
  }
}
