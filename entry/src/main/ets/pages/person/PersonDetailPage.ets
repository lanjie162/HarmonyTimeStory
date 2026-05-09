import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import type { PersonModel, PhotoRefModel, StoryModel } from '../../domain/model/Models';
import { getPersonService } from '../../features/person/PersonFeature';
import { getStoryService } from '../../features/story/StoryFeature';

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

@Entry
@Component
export struct PersonDetailPage {
  @State personId: number = 0;
  @State person: PersonModel | null = null;
  @State draftName: string = '';
  @State storiesAll: StoryModel[] = [];
  @State linkedStoryIds: number[] = [];
  @State photos: PhotoRefModel[] = [];
  @State newStoryTitle: string = '';

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
    this.draftName = this.person?.displayName ?? '';
    this.storiesAll = getStoryService().listStories();
    this.linkedStoryIds = pSvc.listLinkedStories(this.personId).map((s): number => s.id);
    this.photos = pSvc.listPersonPhotos(this.personId);
  }

  private saveName(): void {
    const ok = getPersonService().updatePerson(this.personId, this.draftName);
    if (!ok) {
      promptAction.showToast({ message: '保存失败：人物不存在或名称为空' });
      return;
    }
    promptAction.showToast({ message: '已保存显示名' });
    this.refresh();
  }

  private createStoryQuick(): void {
    const sid = getStoryService().createStory(this.newStoryTitle);
    if (sid < 0) {
      promptAction.showToast({ message: '故事标题不能为空' });
      return;
    }
    this.newStoryTitle = '';
    promptAction.showToast({ message: `已创建故事 #${sid}，可选择「关联」` });
    this.refresh();
  }

  private async pickPhotosFromAlbum(): Promise<void> {
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
        const res = svc.addPhotoToPerson(this.personId, uri);
        if (res.duplicate) {
          promptAction.showToast({ message: '检测到重复 URI，已跳过（PH-01）' });
        }
      }
      promptAction.showToast({ message: '已处理相册选择' });
      this.refresh();
    } catch (_e) {
      promptAction.showToast({ message: '选图取消或不可用，可稍后重试' });
    }
  }

  private toggleStoryLink(s: StoryModel): void {
    const svc = getPersonService();
    if (this.linkedStoryIds.indexOf(s.id) >= 0) {
      svc.unlinkPersonFromStory(this.personId, s.id);
    } else {
      svc.linkPersonToStory(this.personId, s.id);
    }
    this.refresh();
  }

  build() {
    Column({ space: 14 }) {
      Row({ space: 8 }) {
        Button('返回列表')
          .onClick((): void => {
            router.back();
          })
        Text('人物详情').fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1)
      }

      if (this.person === null || this.personId <= 0) {
        Text('未找到人物或路由参数缺失（需要 personId）。')
          .fontColor('#BF360C')
          .width('100%')
      } else {
        Column({ space: 14 }) {
      Text(`${this.person.displayName}  ·  id=${this.person.id}`)
        .fontSize(16)
        .width('100%')

      Divider()
      Text('编辑').fontWeight(FontWeight.Medium).width('100%')
      TextInput({ placeholder: '显示名', text: this.draftName })
        .onChange((v: string): void => {
          this.draftName = v;
        })
      Button('保存显示名').onClick((): void => {
        this.saveName();
      })

      Divider()
      Text('关联故事').fontWeight(FontWeight.Medium).width('100%')
      Text('可新建故事后点「切换关联」写入 PersonStory（内存）。').fontColor('#666666').fontSize(12)

      Row({ space: 8 }) {
        TextInput({ placeholder: '新故事标题', text: this.newStoryTitle })
          .layoutWeight(1)
          .onChange((v: string): void => {
            this.newStoryTitle = v;
          })
        Button('创建')
          .onClick((): void => {
            this.createStoryQuick();
          })
      }
      .width('100%')

      if (this.storiesAll.length === 0) {
        Text('暂无故事，可先创建或与故事主线并行补充。').fontColor('#666666')
      }
      Column({ space: 6 }) {
        ForEach(this.storiesAll, (s: StoryModel) => {
          Row({ space: 8 }) {
            Text(s.title).layoutWeight(1)
            Button(this.linkedStoryIds.indexOf(s.id) >= 0 ? '解除关联' : '关联')
              .onClick((): void => {
                this.toggleStoryLink(s);
              })
          }
          .padding(8)
          .width('100%')
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
        }, (s: StoryModel): string => `story-row-${s.id}`)
      }

      Divider()
      Text('照片（PhotoOwnerLink）').fontWeight(FontWeight.Medium).width('100%')
      Button('从相册选择照片（可多选）')
        .width('100%')
        .onClick((): void => {
          this.pickPhotosFromAlbum();
        })

      if (this.photos.length === 0) {
        Text('暂无挂载照片').fontColor('#666666').fontSize(12)
      } else {
        Grid() {
          ForEach(this.photos, (ph: PhotoRefModel) => {
            GridItem() {
              Column() {
                Image(ph.uri).width('100%').height(96).objectFit(ImageFit.Cover).borderRadius(6)
                Text(`ref#${ph.id}`).fontSize(10).fontColor('#999999').margin({ top: 4 })
              }
            }
          }, (ph: PhotoRefModel): string => `ph-${ph.id}`)
        }
        .columnsTemplate('1fr 1fr 1fr')
        .columnsGap(8)
        .rowsGap(8)
        .width('100%')
      }

      Divider()
      Button('进入导入向导壳页').onClick((): void => {
        router.pushUrl({
          url: 'pages/import/ImportPage',
          params: { ctx: 'person', ownerId: `${this.personId}` }
        });
      })
      Button('进入建议页壳页').onClick((): void => {
        router.pushUrl({ url: 'pages/suggest/SuggestPage' });
      })
        }
      }
    }
    .padding(16)
    .width('100%')
    .height('100%')
  }
}
