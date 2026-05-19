import router from '@ohos.router';

/** 与 UI 原型 v1.2 一致的「人物 / 故事」底栏；Tab 间切换用 replaceUrl，避免栈过深。 */
@Component
export struct MainTabBar {
  /** `'person'` | `'story'` */
  @Prop currentTab: string = 'person';

  private goPerson(): void {
    if (this.currentTab !== 'person') {
      router.replaceUrl({ url: 'pages/person/PersonPage' });
    }
  }

  private goStory(): void {
    if (this.currentTab !== 'story') {
      router.replaceUrl({ url: 'pages/story/StoryPage' });
    }
  }

  build() {
    Row() {
      Column() {
        Text('人物')
          .fontSize($r('app.float.ts_font_support'))
          .fontColor(this.currentTab === 'person' ? $r('app.color.ts_brand_primary') : $r('app.color.ts_text_tertiary'))
          .fontWeight(this.currentTab === 'person' ? FontWeight.Medium : FontWeight.Regular)
        if (this.currentTab === 'person') {
          Divider()
            .margin({ top: 6 })
            .width(28)
            .strokeWidth(3)
            .color($r('app.color.ts_brand_primary'))
        } else {
          Blank().height(9).margin({ top: 6 })
        }
      }
      .layoutWeight(1)
      .height(52)
      .justifyContent(FlexAlign.Center)
      .onClick((): void => {
        this.goPerson();
      })

      Column() {
        Text('故事')
          .fontSize($r('app.float.ts_font_support'))
          .fontColor(this.currentTab === 'story' ? $r('app.color.ts_brand_primary') : $r('app.color.ts_text_tertiary'))
          .fontWeight(this.currentTab === 'story' ? FontWeight.Medium : FontWeight.Regular)
        if (this.currentTab === 'story') {
          Divider()
            .margin({ top: 6 })
            .width(28)
            .strokeWidth(3)
            .color($r('app.color.ts_brand_primary'))
        } else {
          Blank().height(9).margin({ top: 6 })
        }
      }
      .layoutWeight(1)
      .height(52)
      .justifyContent(FlexAlign.Center)
      .onClick((): void => {
        this.goStory();
      })
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 6, bottom: 8 })
    .backgroundColor($r('app.color.ts_surface_container_high'))
    .border({ width: { top: 1 }, color: $r('app.color.ts_outline') })
  }
}
