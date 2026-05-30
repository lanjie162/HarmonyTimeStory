import type { PhotoRefModel } from '../../domain/model/Models';
import { UriHealthStatus } from '../../domain/model/Models';

function formatDate(timestamp?: number): string {
  if (!timestamp || timestamp <= 0) {
    return '';
  }
  const date = new Date(timestamp);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

@Component
export struct PhotoSwiper {
  @Prop photos: PhotoRefModel[] = [];
  @Prop initialIndex: number = 0;
  @Prop removeLabel: string = '移除';
  onRemove?: (photo: PhotoRefModel) => void;
  onClose?: () => void;

  @State currentIndex: number = 0;
  @State showMenu: boolean = false;
  @State swipeOffsetY: number = 0;
  @State failedIndices: Set<number> = new Set<number>();
  @State loadingIndices: Set<number> = new Set<number>();
  private swiperController: SwiperController = new SwiperController();

  aboutToAppear(): void {
    this.currentIndex = this.initialIndex;
  }

  private close(): void {
    if (this.onClose) {
      this.onClose();
    }
  }

  private onLoadComplete(index: number): void {
    this.loadingIndices.delete(index);
    this.loadingIndices = new Set(this.loadingIndices);
  }

  private onLoadError(index: number): void {
    this.loadingIndices.delete(index);
    this.failedIndices.add(index);
    this.failedIndices = new Set(this.failedIndices);
  }

  private confirmRemove(): void {
    this.showMenu = false;
    const photo = this.photos[this.currentIndex];
    AlertDialog.show({
      title: '确认移除',
      message: `确定移除该照片（ref#${photo.id}）？仅解除关联，不删系统原图。`,
      primaryButton: {
        value: '取消',
        action: (): void => {
        }
      },
      secondaryButton: {
        value: '移除',
        fontColor: '#CC0000',
        action: (): void => {
          if (this.onRemove) {
            this.onRemove(photo);
          }
          this.close();
        }
      }
    });
  }

  @Builder
  buildPhotoItem(photo: PhotoRefModel, index: number) {
    Column() {
      if (this.failedIndices.has(index) || photo.refStatus >= UriHealthStatus.LOCAL_DELETED) {
        Column() {
          Text('🖼️')
            .fontSize(48)
          Text('图片已不可访问')
            .fontSize(16)
            .fontColor('#AAAAAA')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#222222')
      } else {
        Stack() {
          Image(photo.uri)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .onComplete(() => {
              this.onLoadComplete(index);
            })
            .onError(() => {
              this.onLoadError(index);
            })
          if (this.loadingIndices.has(index)) {
            LoadingProgress()
              .color('#FFFFFF')
              .width(48)
              .height(48)
          }
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildTopLeftRow() {
    Row({ space: 8 }) {
      Button('←')
        .fontSize(24)
        .fontColor('#FFFFFF')
        .backgroundColor(Color.Transparent)
        .height(44)
        .onClick(() => {
          this.close();
        })
      if (this.photos.length > 0 && this.photos[this.currentIndex]?.metadata?.takenAt) {
        Text(formatDate(this.photos[this.currentIndex]?.metadata?.takenAt))
          .fontSize(16)
          .fontColor('#FFFFFF')
      }
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Swiper(this.swiperController) {
          ForEach(this.photos, (photo: PhotoRefModel, index: number) => {
            this.buildPhotoItem(photo, index)
          }, (photo: PhotoRefModel) => `photo-${photo.id}`)
        }
        .index(this.currentIndex)
        .indicator(false)
        .loop(this.photos.length > 1)
        .width('100%')
        .height('100%')
        .onChange((index: number) => {
          this.currentIndex = index;
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#000000')
      .opacity(Math.max(1 - this.swipeOffsetY / 500, 0.3))
      .gesture(
        PanGesture({ direction: PanDirection.Down, distance: 30 })
          .onActionUpdate((event: GestureEvent) => {
            if (event.offsetY > 0) {
              this.swipeOffsetY = event.offsetY;
            }
          })
          .onActionEnd(() => {
            if (this.swipeOffsetY > 100) {
              this.close();
            } else {
              this.swipeOffsetY = 0;
            }
          })
      )
      .offset({ y: this.swipeOffsetY * 0.5 })

      Column() {
          Row({ space: 0 }) {
            this.buildTopLeftRow()
            Text(`${this.currentIndex + 1}/${this.photos.length}`)
              .fontSize(14)
              .fontColor('#FFFFFF')
            Button('⋮')
              .fontSize(24)
              .fontColor('#FFFFFF')
              .backgroundColor(Color.Transparent)
              .height(44)
              .onClick(() => {
                this.showMenu = true;
              })
          }
          .width('100%')
          .height(64)
          .padding({ left: 16, right: 16, top: 20, bottom: 0 })
          .justifyContent(FlexAlign.SpaceBetween)
          .alignItems(VerticalAlign.Center)
          .linearGradient({
            angle: 180,
            colors: [
              ['#66000000', 0.0],
              ['#00000000', 1.0]
            ]
          })
        }
        .width('100%')
        .zIndex(10)

        if (this.showMenu) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#40000000')
            .onClick(() => {
              this.showMenu = false;
            })
            .zIndex(20)

          Column() {
            Column() {
              Text('照片选项')
                .fontSize(16)
                .fontColor('#FFFFFF')
                .width('100%')
                .padding({ top: 16, bottom: 12, left: 16, right: 16 })
              Divider()
                .color('#333333')
              Button(this.removeLabel)
                .fontSize(16)
                .fontColor('#FF5555')
                .backgroundColor(Color.Transparent)
                .width('100%')
                .height(56)
                .onClick(() => {
                  this.confirmRemove();
                })
            }
            .width('100%')
            .backgroundColor('#1E1E1E')
            .borderRadius({ topLeft: 16, topRight: 16 })
          }
          .width('100%')
          .zIndex(30)
          .position({ x: 0, y: 0 })
          .transition({ type: TransitionType.Insert, translate: { y: 200 } })
        }
    }
    .width('100%')
    .height('100%')
  }
}
