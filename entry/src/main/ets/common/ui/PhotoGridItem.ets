import type { PhotoRefModel } from '../../domain/model/Models';
import { UriHealthStatus } from '../../domain/model/Models';

@Component
export struct PhotoGridItem {
  @Prop ph: PhotoRefModel = { id: 0, uri: '', refStatus: 0 };
  onRemove?: (photoRefId: number) => void;
  /** 当 Image.onError 触发时，通过此回调通知上层持久化失效状态。 */
  onStatusChanged?: (photoRefId: number, status: number) => void;
  @State imageLoadFailed: boolean = false;

  aboutToAppear(): void {
    this.imageLoadFailed = this.ph.refStatus >= UriHealthStatus.LOCAL_DELETED;
  }

  private getStatusText(): string {
    if (this.ph.refStatus === UriHealthStatus.LOCAL_DELETED) {
      return '本地已删除';
    }
    if (this.ph.refStatus === UriHealthStatus.CLOUD_INACCESSIBLE) {
      return '云端不可访问';
    }
    return '图片已失效';
  }

  build() {
    Column({ space: 4 }) {
      Stack() {
        Image(this.ph.uri)
          .width('100%').height(96)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
          .onError((): void => {
            this.imageLoadFailed = true;
            if (this.onStatusChanged !== undefined) {
              this.onStatusChanged(this.ph.id, UriHealthStatus.LOCAL_DELETED);
            }
          })

        if (this.imageLoadFailed) {
          Column() {
            Text(this.getStatusText())
              .fontSize($r('app.float.ts_font_overline'))
              .fontColor('#FFFFFF')
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#80000000')
          .borderRadius(8)
        }
      }
      .width('100%')
      .height(96)

      Text(`ref#${this.ph.id}`)
        .fontSize($r('app.float.ts_font_overline'))
        .fontColor($r('app.color.ts_text_caption'))

      Button('移除')
        .height(26)
        .fontSize($r('app.float.ts_font_overline'))
        .backgroundColor($r('app.color.ts_surface_container_high'))
        .fontColor('#CC0000')
        .width('100%')
        .onClick((): void => {
          if (this.onRemove !== undefined) {
            this.onRemove(this.ph.id);
          }
        })
    }
  }
}