import router from '@ohos.router';

type ViewState = 'empty' | 'loading' | 'error';

@Entry
@Component
export struct ImportPage {
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
      Text('导入壳页')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)

      Text(`当前状态：${this.pageState}`)

      Row({ space: 8 }) {
        Button('返回上一级')
          .onClick(() => router.back())
        Button('返回人物页')
          .onClick(() => router.pushUrl({ url: 'pages/person/PersonPage' }))
      }

      if (this.pageState === 'empty') {
        Text('空态：尚未配置导入条件')
      } else if (this.pageState === 'loading') {
        Text('加载态：正在准备导入资源...')
      } else {
        Text('错误态：导入入口失败，可返回或重试')
      }

      Button('切换状态')
        .onClick(() => this.nextState())
    }
    .padding(16)
    .width('100%')
    .height('100%')
  }
}
