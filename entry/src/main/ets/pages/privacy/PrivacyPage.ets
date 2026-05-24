import router from '@ohos.router';

@Entry
@Component
export struct PrivacyPage {
  build() {
    Column({ space: 0 }) {
      // 顶栏
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor($r('app.color.ts_text_primary'))
          .fontWeight(FontWeight.Regular)
          .onClick((): void => {
            router.back();
          })
        Blank()
        Text('隐私与数据说明')
          .fontSize($r('app.float.ts_font_title'))
          .fontColor($r('app.color.ts_text_primary'))
          .fontWeight(FontWeight.Medium)
        Blank()
        // 占位与 ← 保持标题居中
        Text('  ')
          .fontSize(22)
      }
      .width('100%')
      .height(56)
      .padding({ left: 12, right: 16 })
      .backgroundColor($r('app.color.ts_surface'))

      // 内容区
      Scroll() {
        Column({ space: 12 }) {
          // 板块 1：数据存储
          this.PrivacySection(
            '数据存储',
            '本应用不存储原始照片副本。所有照片资源均通过系统相册引用访问，应用本地仅保存引用标识（URI）。卸载应用后，这些引用标识将一并清除，不可恢复。'
          )

          // 板块 2：照片与云相册
          this.PrivacySection(
            '照片与云相册',
            '应用通过系统 PhotoPicker 访问您选择的照片。华为云相册中的照片由系统统一呈现，应用不单独访问云相册 SDK、不上传照片到自有服务端。'
          )

          // 板块 3：人脸与本地索引
          this.PrivacySection(
            '人脸与本地索引',
            '人脸检测与特征提取完全在设备本地完成，不上传至任何服务器。特征数据仅用于同设备内的人物分组与建议。关闭人脸开关后停止新索引，已有关联保留。'
          )

          // 板块 4：崩溃诊断信息收集
          this.PrivacySection(
            '崩溃诊断信息收集',
            '在不上传原图、可匿名/去标识化前提下采集崩溃栈信息（通过系统 FaultLogger）。采集内容不包含照片内容、联系人等个人数据。您可在设置中开关此功能。'
          )

          // 板块 5：缓存清理说明
          this.PrivacySection(
            '缓存清理说明',
            '人脸特征索引等缓存数据随应用卸载自动清除。若未来提供手动清理入口，清理后将重新开始人脸检测与索引过程。'
          )

          // 板块 6：卸载与恢复预期
          this.PrivacySection(
            '卸载与恢复预期',
            '卸载本应用后，所有本地数据（包括人物档案、故事内容、照片引用、人脸索引等）不可恢复。系统相册中的原始照片不受影响。'
          )
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 32 })
      }
      .layoutWeight(1)
      .backgroundColor($r('app.color.ts_surface'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.ts_surface'))
  }

  @Builder
  private PrivacySection(title: string, text: string): void {
    Column({ space: 8 }) {
      Text(title)
        .fontSize($r('app.float.ts_font_title'))
        .fontColor($r('app.color.ts_text_primary'))
        .fontWeight(FontWeight.Medium)
      Text(text)
        .fontSize($r('app.float.ts_font_body'))
        .fontColor($r('app.color.ts_text_secondary'))
        .lineHeight(22)
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.ts_surface_container'))
    .borderRadius(12)
  }
}