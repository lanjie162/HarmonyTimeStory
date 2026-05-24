import router from '@ohos.router';

type ViewState = 'empty' | 'loading' | 'error';

@Entry
@Component
export struct ShellPage {
  @State shellState: ViewState = 'empty';
  @State isMoreMenuVisible: boolean = false;

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
    router.replaceUrl({ url: 'pages/person/PersonPage' });
  }

  private goStory(): void {
    router.replaceUrl({ url: 'pages/story/StoryPage' });
  }

  private goPrivacy(): void {
    this.isMoreMenuVisible = false;
    router.pushUrl({ url: 'pages/privacy/PrivacyPage' });
  }

  private goSettings(): void {
    this.isMoreMenuVisible = false;
    // T-38: 人脸开关设置页，暂为占位
  }

  build() {
    Stack() {
      Column({ space: 0 }) {
        Column({ space: 8 }) {
          Row() {
            Text('时光故事')
              .fontSize($r('app.float.ts_font_display'))
              .fontColor($r('app.color.ts_text_primary'))
              .fontWeight(FontWeight.Bold)
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
          Text('照片留在本机，故事与人物在本地串联。')
            .fontSize($r('app.float.ts_font_caption'))
            .fontColor($r('app.color.ts_text_tertiary'))
            .lineHeight(20)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 20, right: 20, top: 28, bottom: 22 })
        .backgroundColor($r('app.color.ts_brand_primary_container'))
        .borderRadius({ bottomLeft: 20, bottomRight: 20 })

        Column({ space: 12 }) {
          Column({ space: 6 }) {
            Text('人物')
              .fontSize($r('app.float.ts_font_headline'))
              .fontColor($r('app.color.ts_text_primary'))
              .fontWeight(FontWeight.Medium)
            Text('档案、照片与从相册导入（形态二）')
              .fontSize($r('app.float.ts_font_caption'))
              .fontColor($r('app.color.ts_text_tertiary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .padding({ top: 20, bottom: 20, left: 16, right: 16 })
          .backgroundColor($r('app.color.ts_surface_container'))
          .borderRadius(12)
          .border({ width: 1, color: $r('app.color.ts_outline') })
          .onClick((): void => {
            this.goPerson();
          })

          Column({ space: 6 }) {
            Text('故事')
              .fontSize($r('app.float.ts_font_headline'))
              .fontColor($r('app.color.ts_text_primary'))
              .fontWeight(FontWeight.Medium)
            Text('时间线、关联人物与相册导入（形态一）')
              .fontSize($r('app.float.ts_font_caption'))
              .fontColor($r('app.color.ts_text_tertiary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .padding({ top: 20, bottom: 20, left: 16, right: 16 })
          .backgroundColor($r('app.color.ts_surface_container'))
          .borderRadius(12)
          .border({ width: 1, color: $r('app.color.ts_outline') })
          .onClick((): void => {
            this.goStory();
          })
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
        .layoutWeight(1)

        Column({ space: 6 }) {
          if (this.shellState === 'empty') {
            Text('从上方任选入口开始')
              .fontSize($r('app.float.ts_font_caption'))
              .fontColor($r('app.color.ts_text_tertiary'))
          } else if (this.shellState === 'loading') {
            Text('正在准备…')
              .fontSize($r('app.float.ts_font_caption'))
              .fontColor($r('app.color.ts_color_info'))
          } else {
            Text('导航未就绪，可稍后重试')
              .fontSize($r('app.float.ts_font_caption'))
              .fontColor($r('app.color.ts_color_warning'))
          }
          Button('调试：切换占位状态')
            .fontSize($r('app.float.ts_font_overline'))
            .height(36)
            .backgroundColor($r('app.color.ts_surface_container_high'))
            .fontColor($r('app.color.ts_text_muted'))
            .onClick((): void => {
              this.nextState();
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 12, bottom: 24 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.ts_surface'))

      // ⋮ 更多菜单
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
        .width('100%')
        .alignItems(HorizontalAlign.End)
        .padding({ top: 78, right: 16 })
        .onClick((): void => {
          this.isMoreMenuVisible = false;
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}