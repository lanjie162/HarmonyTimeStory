import router from '@ohos.router';

type ViewState = 'empty' | 'loading' | 'error';

@Entry
@Component
export struct PersonDetailPage {
  @State detailState: ViewState = 'empty';

  private nextState(): void {
    if (this.detailState === 'empty') {
      this.detailState = 'loading';
      return;
    }
    if (this.detailState === 'loading') {
      this.detailState = 'error';
      return;
    }
    this.detailState = 'empty';
  }

  build() {
    Column({ space: 12 }) {
      Text('人物详情壳页')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)

      Text(`当前状态：${this.detailState}`)

      Row({ space: 8 }) {
        Button('返回人物列表')
          .onClick(() => router.back())
        Button('进入导入壳页')
          .onClick(() => router.pushUrl({ url: 'pages/import/ImportPage' }))
      }

      if (this.detailState === 'empty') {
        Text('空态：无照片/无关联故事')
      } else if (this.detailState === 'loading') {
        Text('加载态：人物详情加载中...')
      } else {
        Text('错误态：人物详情加载失败，可重试')
      }

      Button('切换状态')
        .onClick(() => this.nextState())
    }
    .padding(16)
    .width('100%')
    .height('100%')
  }
}
