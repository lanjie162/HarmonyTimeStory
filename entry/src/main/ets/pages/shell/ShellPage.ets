import router from '@ohos.router';
import { PersonPage } from '../person/PersonPage';
import { StoryPage } from '../story/StoryPage';

@Entry
@Component
export struct ShellPage {
  @State currentIndex: number = 0;
  @State isMoreMenuVisible: boolean = false;

  private goPrivacy(): void {
    this.isMoreMenuVisible = false;
    router.pushUrl({ url: 'pages/privacy/PrivacyPage' });
  }

  private goSettings(): void {
    this.isMoreMenuVisible = false;
    // T-38: 人脸开关设置页，暂为占位
  }

  @Builder
  TabBuilder(title: string, targetIndex: number) {
    Column() {
      Text(title)
        .fontSize($r('app.float.ts_font_support'))
        .fontColor(this.currentIndex === targetIndex
          ? $r('app.color.ts_brand_primary')
          : $r('app.color.ts_text_tertiary'))
        .fontWeight(this.currentIndex === targetIndex
          ? FontWeight.Medium : FontWeight.Regular)
      if (this.currentIndex === targetIndex) {
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
      this.currentIndex = targetIndex;
    })
  }

  build() {
    Column({ space: 0 }) {
      // 顶部 ⋮ 按钮栏 — 固定高度，不浮动，不遮挡列表
      Row() {
        Blank()
        Text('⋮')
          .fontSize(24)
          .fontColor($r('app.color.ts_text_secondary'))
          .fontWeight(FontWeight.Bold)
          .onClick((): void => {
            this.isMoreMenuVisible = !this.isMoreMenuVisible;
          })
      }
      .width('100%')
      .height(44)
      .padding({ right: 16, left: 16 })

      // Tabs 区域 + 菜单浮层（内层 Stack，菜单仅出现在右上角）
      Stack({ alignContent: Alignment.TopEnd }) {
        Tabs({ index: this.currentIndex, barPosition: BarPosition.End }) {
          TabContent() {
            PersonPage()
          }
          .tabBar(this.TabBuilder('人物', 0))

          TabContent() {
            StoryPage()
          }
          .tabBar(this.TabBuilder('故事', 1))
        }
        .barMode(BarMode.Fixed)
        .onChange((index: number): void => {
          this.currentIndex = index;
        })
        .backgroundColor($r('app.color.ts_surface'))

        // ⋮ 更多菜单浮层（仅显示时叠加在 Tabs 右上角）
        if (this.isMoreMenuVisible) {
          Column() {
            Column() {
              Text('隐私说明')
                .fontSize($r('app.float.ts_font_label'))
                .fontColor($r('app.color.ts_text_primary'))
                .width('100%')
                .padding({ left: 16, right: 16, top: 14, bottom: 14 })
                .onClick((): void => {
                  this.goPrivacy();
                })
              Divider()
                .width('100%')
                .color($r('app.color.ts_outline'))
              Text('人脸与索引设置')
                .fontSize($r('app.float.ts_font_label'))
                .fontColor($r('app.color.ts_text_tertiary'))
                .width('100%')
                .padding({ left: 16, right: 16, top: 14, bottom: 14 })
                .onClick((): void => {
                  this.goSettings();
                })
            }
            .width(180)
            .borderRadius(12)
            .backgroundColor($r('app.color.ts_surface'))
            .border({ width: 1, color: $r('app.color.ts_outline') })
            .shadow({ radius: 8, color: '#33000000', offsetY: 4 })
          }
          .margin({ top: 4, right: 16 })
          .onClick((): void => {
            this.isMoreMenuVisible = false;
          })
        }
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
  }
}