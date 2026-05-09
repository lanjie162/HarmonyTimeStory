import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import type { PersonModel, PhotoRefModel, StoryModel } from '../../domain/model/Models';
import { getPersonService } from '../../features/person/PersonFeature';
import { getStoryService } from '../../features/story/StoryFeature';

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

@Entry
@Component
export struct StoryDetailPage {
  @State storyId: number = 0;
  @State story: StoryModel | null = null;
  @State draftTitle: string = '';
  @State personsAll: PersonModel[] = [];
  @State linkedPersonIds: number[] = [];
  @State photos: PhotoRefModel[] = [];
  @State newPersonName: string = '';

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
    this.draftTitle = this.story?.title ?? '';
    this.personsAll = getPersonService().listPersons();
    this.linkedPersonIds = sSvc.listLinkedPersons(this.storyId).map((p): number => p.id);
    this.photos = sSvc.listStoryPhotos(this.storyId);
  }

  private saveTitle(): void {
    const ok = getStoryService().updateStory(this.storyId, this.draftTitle);
    if (!ok) {
      promptAction.showToast({ message: '保存失败：故事不存在或标题为空' });
      return;
    }
    promptAction.showToast({ message: '已保存标题' });
    this.refresh();
  }

  private createPersonQuick(): void {
    const pid = getPersonService().createPerson(this.newPersonName);
    if (pid < 0) {
      promptAction.showToast({ message: '人物显示名不能为空' });
      return;
    }
    this.newPersonName = '';
    promptAction.showToast({ message: `已创建人物 #${pid}，可选择「关联」` });
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
      const svc = getStoryService();
      for (const uri of uris) {
        const res = svc.addPhotoToStory(this.storyId, uri);
        if (res.duplicate) {
          promptAction.showToast({ message: '检测到重复 URI，已跳过（PH-01）' });
        }
      }
      promptAction.showToast({ message: '已处理相册选择（故事 PhotoOwnerLink）' });
      this.refresh();
    } catch (_e) {
      promptAction.showToast({ message: '选图取消或不可用，可稍后重试' });
    }
  }

  private togglePersonLink(p: PersonModel): void {
    const svc = getStoryService();
    if (this.linkedPersonIds.indexOf(p.id) >= 0) {
      svc.unlinkStoryFromPerson(this.storyId, p.id);
    } else {
      svc.linkStoryToPerson(this.storyId, p.id);
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
        Text('故事详情').fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1)
      }

      if (this.story === null || this.storyId <= 0) {
        Text('未找到故事或路由参数缺失（需要 storyId）。')
          .fontColor('#BF360C')
          .width('100%')
      } else {
        Column({ space: 14 }) {
          Text(`${this.story.title}  ·  id=${this.story.id}`)
            .fontSize(16)
            .width('100%')

          Divider()
          Text('编辑').fontWeight(FontWeight.Medium).width('100%')
          TextInput({ placeholder: '标题', text: this.draftTitle })
            .onChange((v: string): void => {
              this.draftTitle = v;
            })
          Button('保存标题').onClick((): void => {
            this.saveTitle();
          })

          Divider()
          Text('关联人物').fontWeight(FontWeight.Medium).width('100%')
          Text('通过 PersonStory 与人物主链共用同一内存关联表。').fontColor('#666666').fontSize(12)

          Row({ space: 8 }) {
            TextInput({ placeholder: '新人物显示名', text: this.newPersonName })
              .layoutWeight(1)
              .onChange((v: string): void => {
                this.newPersonName = v;
              })
            Button('创建人物')
              .onClick((): void => {
                this.createPersonQuick();
              })
          }
          .width('100%')

          if (this.personsAll.length === 0) {
            Text('暂无人物，可先创建后与故事关联。').fontColor('#666666')
          }
          Column({ space: 6 }) {
            ForEach(this.personsAll, (p: PersonModel) => {
              Row({ space: 8 }) {
                Text(p.displayName).layoutWeight(1)
                Button(this.linkedPersonIds.indexOf(p.id) >= 0 ? '解除关联' : '关联')
                  .onClick((): void => {
                    this.togglePersonLink(p);
                  })
              }
              .padding(8)
              .width('100%')
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
            }, (p: PersonModel): string => `person-row-${p.id}`)
          }

          Divider()
          Text('照片（故事 · PhotoOwnerLink）').fontWeight(FontWeight.Medium).width('100%')
          Text('与人物页一致：会话内可追溯；单次选择最多 9 张（-picker 上限），见 ST-07 范围以计划为准。')
            .fontColor('#666666')
            .fontSize(12)

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
              }, (ph: PhotoRefModel): string => `sph-${ph.id}`)
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
              params: { ctx: 'story', ownerId: `${this.storyId}` }
            });
          })
        }
      }
    }
    .padding(16)
    .width('100%')
    .height('100%')
  }
}
