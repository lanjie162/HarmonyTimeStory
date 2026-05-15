import router from '@ohos.router';

/**
 * 默认工程模板页；未列入 `main_pages.json` 时不会在主路由中出现。
 * 与产品壳页同一套 Token，便于单独调试或将来挂到入口。
 */
@Entry
@Component
struct Index {
  build() {
    Column({ space: 0 }) {
      Column({ space: 10 }) {
        Text('时光故事')
          .fontSize($r('app.float.ts_font_display'))
          .fontColor($r('app.color.ts_text_primary'))
          .fontWeight(FontWeight.Bold)
          .width('100%')
        Text('照片留在本机，人物与故事在本地串联。')
          .fontSize($r('app.float.ts_font_caption'))
          .fontColor($r('app.color.ts_text_tertiary'))
          .lineHeight(20)
          .width('100%')
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 36, bottom: 24 })
      .backgroundColor($r('app.color.ts_brand_primary_container'))
      .borderRadius({ bottomLeft: 20, bottomRight: 20 })

      Column({ space: 16 }) {
        Text('这是 Index 占位入口，与主壳页视觉对齐。')
          .fontSize($r('app.float.ts_font_body'))
          .fontColor($r('app.color.ts_text_secondary'))
          .width('100%')
        Button('进入主界面')
          .width('100%')
          .height(48)
          .fontSize($r('app.float.ts_font_body'))
          .fontWeight(FontWeight.Medium)
          .backgroundColor($r('app.color.ts_brand_primary'))
          .fontColor($r('app.color.ts_import_bar_on_bg'))
          .onClick((): void => {
            router.replaceUrl({ url: 'pages/shell/ShellPage' });
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 28 })
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.ts_surface'))
  }
}
