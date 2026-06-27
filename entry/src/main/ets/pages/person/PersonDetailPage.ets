import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import { fileIo } from '@kit.CoreFileKit';
import BuildProfile from 'BuildProfile';
import type { GenderEnum, PersonModel, PersonTypeEnum, PhotoMetadata, PhotoRefModel, StoryModel } from '../../domain/model/Models';
import { getPersonService } from '../../features/person/PersonFeature';
import { getStoryService } from '../../features/story/StoryFeature';
import { getPhotoLibraryService } from '../../features/photolibrary/PhotoLibraryFeature';
import { PhotoGridItem } from '../../common/ui/PhotoGridItem';
import { UriHealthChecker } from '../../infrastructure/media/UriHealthChecker';
import { dismissSoftKeyboard } from '../../common/ime/SoftKeyboard';
import { PhotoSwiper } from '../../common/ui/PhotoSwiper';
import { typeLabel, genderLabel, formatBirthday, formatMonthLabel, parsePersonId, buildMonthGroups as buildMonthGroupsLogic, blobToBase64, MonthGroup, TimelineItem, StoryStat } from './PersonDetailLogic';

@Entry
@Component
export struct PersonDetailPage {
  @State personId: number = 0;
  @State person: PersonModel | null = null;
  @State linkedStories: StoryModel[] = [];
  @State photos: PhotoRefModel[] = [];
  @State monthGroups: MonthGroup[] = [];
  @State showSwiper: boolean = false;
  @State swiperIndex: number = 0;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    this.personId = parsePersonId(params);
    this.refresh();
  }

  onPageShow(): void {
    if (this.personId > 0) {
      this.refresh();
    }
  }

  private refresh(): void {
    const pSvc = getPersonService();
    this.person = pSvc.getPerson(this.personId);
    if (this.person !== null) {
      this.linkedStories = pSvc.listLinkedStories(this.personId);
      this.photos = pSvc.listPersonPhotos(this.personId);
      this.buildMonthGroups();
    } else {
      this.linkedStories = [];
      this.photos = [];
      this.monthGroups = [];
    }
  }

  private buildMonthGroups(): void {
    this.monthGroups = buildMonthGroupsLogic(this.photos, this.linkedStories, (sid: number): PhotoRefModel[] => {
      return getStoryService().listStoryPhotos(sid);
    });
  }

  private findPhotoIndexInAll(photoId: number): number {
    for (let i = 0; i < this.photos.length; i++) {
      if (this.photos[i].id === photoId) {
        return i;
      }
    }
    return -1;
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
      const svc = getPersonService();
      for (const uri of uris) {
        const metadata: PhotoMetadata = {};
        const res = svc.addPhotoToPerson(this.personId, uri, metadata);
        if (res.duplicate) {
          promptAction.showToast({ message: '检测到重复 URI，已跳过' });
        }
      }
      promptAction.showToast({ message: '已处理相册选择' });
      this.refresh();
    } catch (_e) {
      promptAction.showToast({ message: '选图取消或不可用' });
    }
  }

  private removePhoto(photo: PhotoRefModel): void {
    const ok = getPersonService().removePhotoFromPerson(this.personId, photo.id);
    if (ok) {
      promptAction.showToast({ message: '已移除照片' });
      this.refresh();
    } else {
      promptAction.showToast({ message: '移除失败' });
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: 0 }) {
        Row({ space: 10 }) {
          Button('←')
            .height(36)
            .fontSize(24)
            .backgroundColor(Color.Transparent)
            .fontColor($r('app.color.ts_import_bar_on_bg'))
            .onClick((): void => {
              dismissSoftKeyboard();
              router.back();
            })
          Text(this.person?.displayName ?? '人物')
            .fontSize(20)
            .fontColor($r('app.color.ts_import_bar_on_bg'))
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
          Button('编辑')
            .height(36)
            .fontSize(16)
            .backgroundColor($r('app.color.ts_brand_primary'))
            .fontColor($r('app.color.ts_import_bar_on_bg'))
            .onClick((): void => {
              router.pushUrl({
                url: 'pages/person/PersonDetailEditPage',
                params: { personId: this.personId }
              });
            })
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .backgroundColor($r('app.color.ts_surface_container_high'))
        .alignItems(VerticalAlign.Center)

        if (this.person !== null && this.personId > 0) {
          Scroll() {
            Column({ space: 14 }) {
              Column({ space: 8 }) {
                Row({ space: 12 }) {
                  this.buildAvatar(this.person.avatarBlob)
                  Column({ space: 4 }) {
                    Text(this.person.displayName)
                      .fontSize(20)
                      .fontColor($r('app.color.ts_text_primary'))
                      .fontWeight(FontWeight.Medium)
                      .width('100%')
                    Text(`${typeLabel(this.person.personType)} · ${formatBirthday(this.person.birthday)} · ${genderLabel(this.person.gender)}`)
                      .fontSize(12)
                      .fontColor($r('app.color.ts_text_tertiary'))
                      .width('100%')
                    Text(`${this.photos.length} 张照片 · ${this.linkedStories.length} 个故事`)
                      .fontSize(12)
                      .fontColor($r('app.color.ts_text_tertiary'))
                      .width('100%')
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')

                Row({ space: 8 }) {
                  Button('+ 添加照片')
                    .height(40)
                    .fontSize(14)
                    .backgroundColor($r('app.color.ts_color_info'))
                    .fontColor($r('app.color.ts_import_bar_on_bg'))
                    .layoutWeight(1)
                    .onClick((): void => {
                      this.pickPhotosFromAlbum();
                    })
                  Button('导入相册…')
                    .height(40)
                    .fontSize(14)
                    .backgroundColor($r('app.color.ts_surface_container_high'))
                    .fontColor($r('app.color.ts_text_tertiary'))
                    .layoutWeight(1)
                    .onClick((): void => {
                      router.pushUrl({
                        url: 'pages/import/ImportPage',
                        params: { ctx: 'person', ownerId: `${this.personId}` }
                      });
                    })
                }
                .width('100%')
              }
              .width('100%')
              .padding(16)
              .backgroundColor($r('app.color.ts_surface_container'))
              .borderRadius(12)
              .border({ width: 1, color: $r('app.color.ts_outline') })

              if (this.monthGroups.length > 0) {
                List() {
                  ForEach(this.monthGroups, (g: MonthGroup) => {
                    ListItemGroup({ header: this.buildMonthHeader(g) }) {
                      ForEach(g.items, (item: TimelineItem, index: number) => {
                        if (item.kind === 'photo' && item.photo) {
                          this.buildPhotoGridItem(item.photo, index)
                        } else if (item.kind === 'story' && item.story) {
                          this.buildStoryGridItem(item.story, item.coverPhoto, g.storyStats.get(item.story.id))
                        }
                      }, (item: TimelineItem): string => {
                        if (item.kind === 'photo' && item.photo) {
                          return `photo-${item.photo.id}`;
                        } else if (item.kind === 'story' && item.story) {
                          return `story-${item.story.id}`;
                        }
                        return `item-${Math.random()}`;
                      })
                    }
                  }, (g: MonthGroup): string => `group-${g.year}-${g.month}`)
                }
                .sticky(StickyStyle.Header)
                .width('100%')
                .padding(16)
                .backgroundColor($r('app.color.ts_surface_container'))
                .borderRadius(12)
                .border({ width: 1, color: $r('app.color.ts_outline') })
              } else {
                Column({ space: 10 }) {
                  Text('🖼️ 还没有照片')
                    .fontSize(16)
                    .fontColor($r('app.color.ts_text_tertiary'))
                  Button('+ 添加照片')
                    .height(40)
                    .fontSize(14)
                    .backgroundColor($r('app.color.ts_color_info'))
                    .fontColor($r('app.color.ts_import_bar_on_bg'))
                    .onClick((): void => {
                      this.pickPhotosFromAlbum();
                    })
                }
                .width('100%')
                .padding(24)
                .backgroundColor($r('app.color.ts_surface_container'))
                .borderRadius(12)
                .border({ width: 1, color: $r('app.color.ts_outline') })
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 28 })
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
      .backgroundColor($r('app.color.ts_surface'))

      if (this.showSwiper) {
        PhotoSwiper({
          photos: this.photos,
          initialIndex: this.swiperIndex,
          removeLabel: '从人物移除',
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
  buildPhotoGridItem(photo: PhotoRefModel, _index: number) {
    ListItem() {
      Stack() {
        Image(photo.uri)
          .width('100%')
          .aspectRatio(1)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
          .onClick((): void => {
            this.swiperIndex = this.findPhotoIndexInAll(photo.id);
            this.showSwiper = true;
          })
      }
      .width('100%')
      .aspectRatio(1)
    }
  }

  @Builder
  buildStoryGridItem(story: StoryModel, coverPhoto?: PhotoRefModel, stats?: StoryStat) {
    ListItem() {
      Column({ space: 4 }) {
        Stack({ alignContent: Alignment.BottomStart }) {
          if (coverPhoto && coverPhoto.uri) {
            Image(coverPhoto.uri)
              .width('100%')
              .aspectRatio(1)
              .objectFit(ImageFit.Cover)
              .borderRadius(16)
              .onClick((): void => {
                router.pushUrl({
                  url: 'pages/story/StoryDetailPage',
                  params: { storyId: story.id }
                });
              })
            Column() {
              Text(`📖 ${stats?.title ?? story.title}`)
                .fontSize(11)
                .fontColor($r('app.color.ts_import_bar_on_bg'))
                .maxLines(1)
            }
            .width('100%')
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor('#99B85C38')
            .borderRadius({ bottomLeft: 16, bottomRight: 16 })
          } else {
            Column() {
              Text('📖')
                .fontSize(24)
                .fontColor($r('app.color.ts_brand_primary'))
            }
            .width('100%')
            .aspectRatio(1)
            .backgroundColor('#1AB85C38')
            .borderRadius(16)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .onClick((): void => {
              router.pushUrl({
                url: 'pages/story/StoryDetailPage',
                params: { storyId: story.id }
              });
            })
          }
        }
        .width('100%')

        Row({ space: 4 }) {
          Text(`📖 ${stats?.title ?? story.title} · ${stats?.count ?? 0} 张  →`)
            .fontSize(11)
            .fontColor($r('app.color.ts_brand_primary'))
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 4 })
        .onClick((): void => {
          router.pushUrl({
            url: 'pages/story/StoryDetailPage',
            params: { storyId: story.id }
          });
        })
      }
      .width('100%')
    }
  }

  @Builder
  buildMonthHeader(g: MonthGroup) {
    Row() {
      Text(formatMonthLabel(g.year, g.month))
        .fontSize(16)
        .fontColor($r('app.color.ts_text_primary'))
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .padding({ left: 0, right: 0, top: 8, bottom: 8 })
    .backgroundColor($r('app.color.ts_surface_container'))
  }

  @Builder
  buildAvatar(blob: Uint8Array | null) {
    if (blob !== null && blob.byteLength > 0) {
      Image('data:image/png;base64,' + this.blobToBase64(blob))
        .width(64).height(64)
        .borderRadius(32)
        .objectFit(ImageFit.Cover)
    } else {
      Circle({ width: 64, height: 64 })
        .fill($r('app.color.ts_surface_container_high'))
    }
  }

  @Builder
  buildErrorState() {
    Column({ space: 16 }) {
      Text('⛔')
        .fontSize(48)
        .fontColor($r('app.color.ts_color_error'))
      Text('人物不存在或已被删除')
        .fontSize(16)
        .fontColor($r('app.color.ts_import_bar_on_bg'))
      Button('返回人物列表')
        .height(44)
        .fontSize(14)
        .backgroundColor($r('app.color.ts_surface_container_high'))
        .fontColor($r('app.color.ts_import_bar_on_bg'))
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
}
