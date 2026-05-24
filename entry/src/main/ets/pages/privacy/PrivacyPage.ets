import router from '@ohos.router';
import { CrashReporter } from '../../infrastructure/api/CrashReporter';

@Entry
@Component
export struct PrivacyPage {
  @State crashReportEnabled: boolean = CrashReporter.getInstance().isEnabled();

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
          // 板块 1：不存原图
          this.PrivacySection(
            '不存原图',
            '本应用不存储原始照片副本。所有照片资源均通过系统相册引用访问，应用本地仅保存引用标识（URI）。卸载应用后，这些引用标识将一并清除，不可恢复。'
          )

          // 板块 2：不上传云端
          this.PrivacySection(
            '不上传云端',
            '应用通过系统 PhotoPicker 或相册引用访问您选择的照片。所有数据（包括人物档案、故事内容、照片引用、人脸特征索引等）仅保存在设备本地，不会上传至任何云端服务器。华为云相册中的照片由系统统一呈现，应用不单独访问云相册 SDK。'
          )

          // 板块 3：系统引用说明
          this.PrivacySection(
            '系统引用说明',
            '应用通过系统能力（PhotoAccessHelper、PhotoPicker）访问照片，系统相册中的原始照片始终归系统管理。应用不持有照片文件副本，仅保存一个引用标识（URI）。每次加载照片时，应用向系统请求该 URI 对应的图片数据。如果原始照片被用户从系统相册删除，引用将失效。'
          )

          // 板块 4：人脸开关
          this.PrivacySection(
            '人脸与索引开关',
            '人脸检测与特征提取完全在设备本地完成，不上传至任何服务器。特征数据仅用于同设备内的人物分组与建议。您可在主菜单「人脸与索引设置」中关闭人脸功能。关闭后停止新索引，已有关联保留；若选择"关闭并清空"，所有人脸数据将被清除。'
          )

          // 板块 5：缓存清理说明
          this.PrivacySection(
            '缓存清理说明',
            '人脸特征索引等缓存数据随应用卸载自动清除。若您需要手动清理，可进入「人脸与索引设置」中选择"关闭并清空"以清除人脸索引数据。缓存清理后重新打开人脸功能将重新开始人脸检测与索引过程。'
          )

          // 板块 6：卸载不可恢复
          this.PrivacySection(
            '卸载与数据不可恢复',
            '卸载本应用后，所有本地数据（包括人物档案、故事内容、照片引用标识、人脸特征索引等）将完全清除，不可恢复。系统相册中的原始照片不受影响。建议在卸载前确认已无需要保留的数据。'
          )

          // 板块 7：崩溃诊断板块（T-34 联动）
          this.CrashDiagnosisSection(
            '崩溃诊断信息收集',
            '在不上传原图、可匿名/去标识化前提下采集崩溃栈信息（通过系统 FaultLogger）。采集内容不包含照片内容、联系人等个人数据。您可在本页开关此功能。'
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

  @Builder
  private CrashDiagnosisSection(title: string, text: string): void {
    Column({ space: 8 }) {
      Row() {
        Text(title)
          .fontSize($r('app.float.ts_font_title'))
          .fontColor($r('app.color.ts_text_primary'))
          .fontWeight(FontWeight.Medium)
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: this.crashReportEnabled })
          .onChange((isOn: boolean): void => {
            this.crashReportEnabled = isOn;
            CrashReporter.getInstance().setEnabled(isOn);
          })
      }
      .width('100%')
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