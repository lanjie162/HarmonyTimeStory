import router from '@ohos.router';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import BuildProfile from 'BuildProfile';
import type { PersonModel, PhotoMetadata, PhotoRefModel, StoryModel } from '../../domain/model/Models';
import { getPersonService } from '../../features/person/PersonFeature';
import { getStoryService } from '../../features/story/StoryFeature';
import { PhotoSwiper } from '../../common/ui/PhotoSwiper';
import { dismissSoftKeyboard } from '../../common/ime/SoftKeyboard';

function parseStoryId(params: Record<string, Object>): number {
  const raw = params['storyId'];
  if (typeof raw === 'number') {
    return raw as number;
  }
  if (typeof raw === 'string') {
    const n = Number.parseInt(raw as string, 10);
    return Number.isNaN(n) ? 0 : n;
  }
  return 0;
}

function formatDate(ts: number | null): string {
  if (ts === null || ts <= 0) {
    return '未设置';
  }
  const d = new Date(ts);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

@Entry
@Component
export struct StoryDetailPage {
  @State storyId: number = 0;
  @State story: StoryModel | null = null;
  @State linkedPersons: PersonModel[] = [];
  @State photos: PhotoRefModel[] = [];
  @State showSwiper: boolean = false;
  @State swiperIndex: number = 0;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    this.storyId = parseStoryId(params);
    this.refresh();
  }

  onPageShow(): void {
    if (this.storyId > 0) {
      this.refresh();
    }
  }

  private refresh(): void {
    const sSvc = getStoryService();
    this.story = sSvc.getStory(this.storyId);
    if (this.story !== null) {
      this.linkedPersons = sSvc.listLinkedPersons(this.storyId);
      this.photos = sSvc.listStoryPhotos(this.storyId);
    } else {
      this.linkedPersons = [];
      this.photos = [];
    }
  }

  private async pickPhotosFromAlbum(): Promise<void> {
    dismissSoftKeyboard();
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.maxSelectNumber = 9;
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select(options);
      const uris = result.photoUris;
      if (!uris || uris.length === 0) {
        return;
      }
      const svc = getStoryService();
      for (const uri of uris) {
        const metadata: PhotoMetadata = {};
        svc.addPhotoToStory(this.storyId, uri, metadata);
      }
      this.refresh();
    } catch (_e) {
    }
  }

  private removePhoto(photo: PhotoRefModel): void {
    const ok = getStoryService().removePhotoFromStory(this.storyId, photo.id);
    if (ok) {
      this.refresh();
    }
  }

  private buildDateRangeText(): string {
    if (!this.story) {
      return '';
    }
    const start = formatDate(this.story.timeStart);
    const end = formatDate(this.story.timeEnd);
    if (start === '未设置' && end === '未设置') {
      return '';
    }
    if (start === end) {
      return start;
    }
    return `${start} ~ ${end}`;
  }

  private buildMetaInfoText(): string {
    const dateRange = this.buildDateRangeText();
    const location = this.story?.location ?? '';
    if (dateRange && location) {
      return `${dateRange}  ·  ${location}`;
    }
    return dateRange || location;
  }

  private getDisplayTags(): string[] {
    if (!this.story || !this.story.tags || this.story.tags.length === 0) {
      return [];
    }
    return this.story.tags.slice(0, 3);
  }

  private getExtraTagCount(): number {
    if (!this.story || !this.story.tags) {
      return 0;
    }
    return Math.max(0, this.story.tags.length - 3);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: 0 }) {
        Row({ space: 10 }) {
          Button('←')
            .height(36)
            .fontSize(24)
            .backgroundColor(Color.Transparent)
            .fontColor('#FFFFFF')
            .onClick((): void => {
              dismissSoftKeyboard();
              router.back();
            })
          Text(this.story?.title ?? '故事')
            .fontSize(20)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
          Button('编辑')
            .height(36)
            .fontSize(16)
            .backgroundColor('#67C31F')
            .fontColor('#FFFFFF')
            .onClick((): void => {
              router.pushUrl({
                url: 'pages/story/StoryDetailEditPage',
                params: { storyId: this.storyId }
              });
            })
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .backgroundColor('#333333')
        .alignItems(VerticalAlign.Center)

        if (this.story !== null && this.storyId > 0) {
          Scroll() {
            Column({ space: 0 }) {
              this.buildCoverBanner()

              if (this.buildMetaInfoText()) {
                this.buildMetaInfoRow()
              }

              if (this.getDisplayTags().length > 0) {
                this.buildTagsRow()
              }

              if (this.linkedPersons.length > 0) {
                this.buildPersonAvatarRow()
              }

              this.buildPhotoSection()
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 0, bottom: 28 })
          }
          .layoutWeight(1)
          .width('100%')
          .align(Alignment.Top)
          .scrollBar(BarState.Auto)
          .edgeEffect(EdgeEffect.Spring)
        } else {
          this.buildErrorState()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#111111')

      if (this.showSwiper) {
        PhotoSwiper({
          photos: this.photos,
          initialIndex: this.swiperIndex,
          removeLabel: '从故事移除',
          onRemove: (photo: PhotoRefModel): void => {
            this.removePhoto(photo);
          },
          onClose: (): void => {
            this.showSwiper = false;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildCoverBanner() {
    Column() {
      if (this.story && this.story.coverUri && this.story.coverUri.length > 0) {
        Image(this.story.coverUri)
          .width('100%')
          .aspectRatio(16 / 9)
          .objectFit(ImageFit.Cover)
          .borderRadius(12)
      } else {
        Column() {
          Text('🖼️')
            .fontSize(48)
            .fontColor('#555555')
          Text('暂无封面')
            .fontSize(14)
            .fontColor('#888888')
            .margin({ top: 8 })
        }
        .width('100%')
        .aspectRatio(16 / 9)
        .backgroundColor('#222222')
        .borderRadius(12)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .margin({ top: 16 })
  }

  @Builder
  buildMetaInfoRow() {
    Column() {
      Text(this.buildMetaInfoText())
        .fontSize(14)
        .fontColor('#AAAAAA')
        .width('100%')
    }
    .width('100%')
    .padding({ top: 12, bottom: 4 })
  }

  @Builder
  buildTagsRow() {
    Column() {
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.getDisplayTags(), (tag: string) => {
          Text(`#${tag}`)
            .fontSize(12)
            .fontColor('#67C31F')
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor('#1A67C31F')
            .borderRadius(14)
            .margin({ right: 8, bottom: 8 })
        }, (tag: string): string => `tag-${tag}`)
        if (this.getExtraTagCount() > 0) {
          Text(`+${this.getExtraTagCount()}`)
            .fontSize(12)
            .fontColor('#67C31F')
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor('#1A67C31F')
            .borderRadius(14)
            .margin({ bottom: 8 })
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding({ top: 8, bottom: 4 })
  }

  @Builder
  buildPersonAvatarRow() {
    Column() {
      Scroll() {
        Row({ space: 16 }) {
          ForEach(this.linkedPersons, (p: PersonModel) => {
            Column({ space: 4 }) {
              if (p.avatarBlob && p.avatarBlob.byteLength > 0) {
                Image('data:image/png;base64,' + this.blobToBase64(p.avatarBlob))
                  .width(40)
                  .height(40)
                  .borderRadius(20)
                  .objectFit(ImageFit.Cover)
              } else {
                Circle({ width: 40, height: 40 })
                  .fill('#444444')
              }
              Text(p.displayName)
                .fontSize(10)
                .fontColor('#AAAAAA')
                .maxLines(1)
            }
            .onClick((): void => {
              router.pushUrl({
                url: 'pages/person/PersonDetailPage',
                params: { personId: p.id }
              });
            })
          }, (p: PersonModel): string => `person-avatar-${p.id}`)
        }
        .padding({ right: 8 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .width('100%')
    .padding({ top: 12, bottom: 4 })
  }

  @Builder
  buildPhotoSection() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text(`${this.photos.length} 张照片`)
          .fontSize(16)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Medium)
        Row({ space: 8 }) {
          Button('+ 添加')
            .height(32)
            .fontSize(12)
            .backgroundColor('#1E88E5')
            .fontColor('#FFFFFF')
            .onClick((): void => {
              this.pickPhotosFromAlbum();
            })
          Button('导入')
            .height(32)
            .fontSize(12)
            .backgroundColor('#444444')
            .fontColor('#FFFFFF')
            .onClick((): void => {
              router.pushUrl({
                url: 'pages/import/ImportPage',
                params: { ctx: 'story', ownerId: `${this.storyId}` }
              });
            })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.End)
      }
      .width('100%')

      if (this.photos.length > 0) {
        Grid() {
          ForEach(this.photos, (ph: PhotoRefModel, idx: number) => {
            GridItem() {
              Image(ph.uri)
                .width('100%')
                .aspectRatio(1)
                .objectFit(ImageFit.Cover)
                .borderRadius(8)
                .onClick((): void => {
                  this.swiperIndex = idx;
                  this.showSwiper = true;
                })
            }
          }, (ph: PhotoRefModel): string => `ph-${ph.id}`)
        }
        .columnsTemplate('1fr 1fr 1fr')
        .columnsGap(6)
        .rowsGap(6)
        .width('100%')
        .scrollBar(BarState.Off)
      } else {
        Column({ space: 10 }) {
          Text('🖼️')
            .fontSize(32)
            .fontColor('#555555')
          Text('这个事件还没有照片')
            .fontSize(14)
            .fontColor('#888888')
          Text('添加照片或导入相册来记录吧')
            .fontSize(12)
            .fontColor('#666666')
            .margin({ top: 4 })
          Button('+ 添加照片')
            .height(40)
            .fontSize(14)
            .backgroundColor('#1E88E5')
            .fontColor('#FFFFFF')
            .margin({ top: 12 })
            .onClick((): void => {
              this.pickPhotosFromAlbum();
            })
        }
        .width('100%')
        .padding(24)
        .backgroundColor('#1A222222')
        .borderRadius(12)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .padding({ top: 16 })
  }

  @Builder
  buildErrorState() {
    Column({ space: 16 }) {
      Text('⛔')
        .fontSize(48)
        .fontColor('#FF5555')
      Text('故事不存在或已被删除')
        .fontSize(16)
        .fontColor('#FFFFFF')
      Button('返回故事列表')
        .height(44)
        .fontSize(14)
        .backgroundColor('#444444')
        .fontColor('#FFFFFF')
        .width('100%')
        .onClick((): void => {
          router.back();
        })
    }
    .width('100%')
    .padding(32)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }

  private blobToBase64(blob: Uint8Array): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let result = '';
    const bytes = blob;
    for (let i = 0; i < bytes.byteLength; i += 3) {
      const b0 = bytes[i];
      const b1 = i + 1 < bytes.byteLength ? bytes[i + 1] : 0;
      const b2 = i + 2 < bytes.byteLength ? bytes[i + 2] : 0;
      result += chars.charAt(b0 >> 2);
      result += chars.charAt(((b0 & 3) << 4) | (b1 >> 4));
      result += i + 1 < bytes.byteLength ? chars.charAt(((b1 & 15) << 2) | (b2 >> 6)) : '=';
      result += i + 2 < bytes.byteLength ? chars.charAt(b2 & 63) : '=';
    }
    return result;
  }
}
