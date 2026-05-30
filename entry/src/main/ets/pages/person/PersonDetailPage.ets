import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import { fileIo } from '@kit.CoreFileKit';
import BuildProfile from 'BuildProfile';
import type { GenderEnum, PersonModel, PersonTypeEnum, PhotoMetadata, PhotoRefModel, StoryModel } from '../../domain/model/Models';
import { PersonTypeEnum as PT } from '../../domain/model/Models';
import { GenderEnum as GE } from '../../domain/model/Models';
import { getPersonService } from '../../features/person/PersonFeature';
import { getStoryService } from '../../features/story/StoryFeature';
import { getPhotoLibraryService } from '../../features/photolibrary/PhotoLibraryFeature';
import { PhotoGridItem } from '../../common/ui/PhotoGridItem';
import { UriHealthChecker } from '../../infrastructure/media/UriHealthChecker';
import { dismissSoftKeyboard } from '../../common/ime/SoftKeyboard';
import { PhotoSwiper } from '../../common/ui/PhotoSwiper';

function parsePersonId(params: Record<string, Object>): number {
  const raw = params['personId'];
  if (typeof raw === 'number') {
    return raw as number;
  }
  if (typeof raw === 'string') {
    const n = Number.parseInt(raw as string, 10);
    return Number.isNaN(n) ? 0 : n;
  }
  return 0;
}

function typeLabel(val: PersonTypeEnum): string {
  if (val === PT.BABY) {
    return '宝宝';
  }
  if (val === PT.ADULT) {
    return '成人';
  }
  if (val === PT.ELDER) {
    return '长辈';
  }
  return '其他';
}

function genderLabel(val: GenderEnum | null): string {
  if (val === null || val === GE.UNSPECIFIED) {
    return '未填';
  }
  if (val === GE.MALE) {
    return '男';
  }
  return '女';
}

function formatBirthday(ts: number | null): string {
  if (ts === null || ts <= 0) {
    return '未设置';
  }
  const date = new Date(ts);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function formatMonthLabel(year: number, month: number): string {
  return `${year}年${month + 1}月`;
}

type TimelineItemKind = 'photo' | 'story';

interface TimelineItem {
  kind: TimelineItemKind;
  photo?: PhotoRefModel;
  story?: StoryModel;
  coverPhoto?: PhotoRefModel;
}

interface StoryStat {
  title: string;
  count: number;
}

interface MonthGroup {
  year: number;
  month: number;
  items: TimelineItem[];
  storyStats: Map<number, StoryStat>;
}

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
    const groups: MonthGroup[] = [];
    const map = new Map<string, MonthGroup>();

    // 添加人物照片
    for (const ph of this.photos) {
      const ts = ph.metadata?.takenAt ?? 0;
      const d = new Date(ts);
      const y = d.getFullYear();
      const m = d.getMonth();
      const key = `${y}-${m}`;
      let g = map.get(key);
      if (!g) {
        g = { year: y, month: m, items: [], storyStats: new Map() };
        map.set(key, g);
        groups.push(g);
      }
      g.items.push({ kind: 'photo', photo: ph });
    }

    // 添加关联故事封面
    for (const s of this.linkedStories) {
      const ts = s.timeStart ?? 0;
      if (ts <= 0) {
        continue;
      }
      const d = new Date(ts);
      const y = d.getFullYear();
      const m = d.getMonth();
      const key = `${y}-${m}`;
      let g = map.get(key);
      if (!g) {
        g = { year: y, month: m, items: [], storyStats: new Map() };
        map.set(key, g);
        groups.push(g);
      }

      // 获取故事封面
      let coverPhoto: PhotoRefModel | undefined;
      
      // 优先用 coverUri，在人物照片中查找
      if (s.coverUri && s.coverUri.length > 0) {
        coverPhoto = this.photos.find(ph => ph.uri === s.coverUri);
      }
      
      // 如果 coverUri 没找到，或者没有 coverUri，去故事照片中取第一张
      if (!coverPhoto && s.photoCount > 0) {
        const storyPhotos = getStoryService().listStoryPhotos(s.id);
        if (storyPhotos.length > 0) {
          coverPhoto = storyPhotos[0];
        }
      }

      g.items.push({ kind: 'story', story: s, coverPhoto: coverPhoto });

      // 直接用 story.photoCount
      g.storyStats.set(s.id, { title: s.title, count: s.photoCount });
    }

    for (const g of groups) {
      g.items.sort((a, b) => {
        const tsA = a.kind === 'photo' ? (a.photo?.metadata?.takenAt ?? 0) : (a.story?.timeStart ?? 0);
        const tsB = b.kind === 'photo' ? (b.photo?.metadata?.takenAt ?? 0) : (b.story?.timeStart ?? 0);
        return tsB - tsA;
      });
    }

    groups.sort((a, b) => {
      if (a.year !== b.year) {
        return b.year - a.year;
      }
      return b.month - a.month;
    });

    this.monthGroups = groups;
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
            .fontColor('#FFFFFF')
            .onClick((): void => {
              dismissSoftKeyboard();
              router.back();
            })
          Text(this.person?.displayName ?? '人物')
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
                url: 'pages/person/PersonDetailEditPage',
                params: { personId: this.personId }
              });
            })
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .backgroundColor('#333333')
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
                      .fontColor('#FFFFFF')
                      .fontWeight(FontWeight.Medium)
                      .width('100%')
                    Text(`${typeLabel(this.person.personType)} · ${formatBirthday(this.person.birthday)} · ${genderLabel(this.person.gender)}`)
                      .fontSize(12)
                      .fontColor('#AAAAAA')
                      .width('100%')
                    Text(`${this.photos.length} 张照片 · ${this.linkedStories.length} 个故事`)
                      .fontSize(12)
                      .fontColor('#AAAAAA')
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
                    .backgroundColor('#1E88E5')
                    .fontColor('#FFFFFF')
                    .layoutWeight(1)
                    .onClick((): void => {
                      this.pickPhotosFromAlbum();
                    })
                  Button('导入相册…')
                    .height(40)
                    .fontSize(14)
                    .backgroundColor('#444444')
                    .fontColor('#AAAAAA')
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
              .backgroundColor('#222222')
              .borderRadius(12)
              .border({ width: 1, color: '#444444' })

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
                .backgroundColor('#222222')
                .borderRadius(12)
                .border({ width: 1, color: '#444444' })
              } else {
                Column({ space: 10 }) {
                  Text('🖼️ 还没有照片')
                    .fontSize(16)
                    .fontColor('#AAAAAA')
                  Button('+ 添加照片')
                    .height(40)
                    .fontSize(14)
                    .backgroundColor('#1E88E5')
                    .fontColor('#FFFFFF')
                    .onClick((): void => {
                      this.pickPhotosFromAlbum();
                    })
                }
                .width('100%')
                .padding(24)
                .backgroundColor('#222222')
                .borderRadius(12)
                .border({ width: 1, color: '#444444' })
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
      .backgroundColor('#111111')

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
  buildPhotoGridItem(photo: PhotoRefModel, index: number) {
    ListItem() {
      Stack() {
        Image(photo.uri)
          .width('100%')
          .aspectRatio(1)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
          .onClick((): void => {
            this.swiperIndex = index;
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
                .fontColor('#FFFFFF')
                .maxLines(1)
            }
            .width('100%')
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor('#9967C31F')
            .borderRadius({ bottomLeft: 16, bottomRight: 16 })
          } else {
            Column() {
              Text('📖')
                .fontSize(24)
                .fontColor('#67C31F')
            }
            .width('100%')
            .aspectRatio(1)
            .backgroundColor('#1A67C31F')
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
            .fontColor('#67C31F')
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
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .padding({ left: 0, right: 0, top: 8, bottom: 8 })
    .backgroundColor('#222222')
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
        .fill('#444444')
    }
  }

  @Builder
  buildErrorState() {
    Column({ space: 16 }) {
      Text('⛔')
        .fontSize(48)
        .fontColor('#FF5555')
      Text('人物不存在或已被删除')
        .fontSize(16)
        .fontColor('#FFFFFF')
      Button('返回人物列表')
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
}
