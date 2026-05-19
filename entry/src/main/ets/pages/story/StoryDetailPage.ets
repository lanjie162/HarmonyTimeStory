import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import BuildProfile from 'BuildProfile';
import type { PersonModel, PhotoRefModel, StoryModel } from '../../domain/model/Models';
import { getPersonService } from '../../features/person/PersonFeature';
import { getStoryService } from '../../features/story/StoryFeature';
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
  @State debugLastAlbumInject: string = '';

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
    dismissSoftKeyboard();
    const ok = getStoryService().updateStory(this.storyId, this.draftTitle);
    if (!ok) {
      promptAction.showToast({ message: '保存失败：故事不存在或标题为空' });
      return;
    }
    promptAction.showToast({ message: '已保存标题' });
    this.refresh();
  }

  private createPersonQuick(): void {
    dismissSoftKeyboard();
    const pid = getPersonService().createPerson(this.newPersonName);
    if (pid < 0) {
      promptAction.showToast({ message: '人物显示名不能为空' });
      return;
    }
    this.newPersonName = '';
    promptAction.showToast({ message: `已创建人物 #${pid}，可选择「关联」` });
    this.refresh();
  }

  private injectDebugAlbumEquivUri(uri: string): void {
    if (this.storyId <= 0) {
      this.debugLastAlbumInject = '【E2E】inject skip：无 storyId';
      return;
    }
    const res = getStoryService().addPhotoToStory(this.storyId, uri);
    if (res.duplicate) {
      this.debugLastAlbumInject = '【E2E】上次加图：重复跳过（PH-01）';
    } else if (res.success) {
      this.debugLastAlbumInject = '【E2E】上次加图：成功 file://e2e/album-equiv-story-1';
    } else {
      this.debugLastAlbumInject = '【E2E】上次加图：失败（故事不存在或 URI 为空）';
    }
    this.refresh();
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
    dismissSoftKeyboard();
    const svc = getStoryService();
    if (this.linkedPersonIds.indexOf(p.id) >= 0) {
      svc.unlinkStoryFromPerson(this.storyId, p.id);
    } else {
      svc.linkStoryToPerson(this.storyId, p.id);
    }
    this.refresh();
  }

  build() {
    Column({ space: 0 }) {
      Row({ space: 10 }) {
        Button('返回列表')
          .height(36)
          .fontSize($r('app.float.ts_font_support'))
          .backgroundColor($r('app.color.ts_surface_container_high'))
          .fontColor($r('app.color.ts_text_secondary'))
          .onClick((): void => {
            dismissSoftKeyboard();
            router.back();
          })
        Text('故事详情')
          .fontSize($r('app.float.ts_font_title'))
          .fontColor($r('app.color.ts_text_primary'))
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })
      .alignItems(VerticalAlign.Center)

      if (this.story !== null && this.storyId > 0) {
        Scroll() {
          Column({ space: 14 }) {
            Column({ space: 6 }) {
              Text(this.story.title)
                .fontSize($r('app.float.ts_font_headline'))
                .fontColor($r('app.color.ts_text_primary'))
                .fontWeight(FontWeight.Medium)
                .width('100%')
              Text(`故事 · id=${this.story.id}`)
                .fontSize($r('app.float.ts_font_caption'))
                .fontColor($r('app.color.ts_text_tertiary'))
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.ts_surface_container'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.ts_outline') })

            Column({ space: 12 }) {
              Text('编辑')
                .fontSize($r('app.float.ts_font_label'))
                .fontColor($r('app.color.ts_text_primary'))
                .fontWeight(FontWeight.Medium)
                .width('100%')
              TextInput({ placeholder: '标题', text: this.draftTitle })
                .onChange((v: string): void => {
                  this.draftTitle = v;
                })
                .enterKeyType(EnterKeyType.Done)
                .onSubmit((): void => {
                  this.saveTitle();
                })
                .width('100%')
                .height(48)
                .backgroundColor($r('app.color.ts_surface_container_high'))
                .borderRadius(10)
                .padding({ left: 12, right: 12 })
              Button('保存标题')
                .width('100%')
                .height(44)
                .fontSize($r('app.float.ts_font_support'))
                .fontWeight(FontWeight.Medium)
                .backgroundColor($r('app.color.ts_brand_primary'))
                .fontColor($r('app.color.ts_import_bar_on_bg'))
                .onClick((): void => {
                  this.saveTitle();
                })
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.ts_surface_container'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.ts_outline') })

            Column({ space: 12 }) {
              Text('关联人物')
                .fontSize($r('app.float.ts_font_label'))
                .fontColor($r('app.color.ts_text_primary'))
                .fontWeight(FontWeight.Medium)
                .width('100%')
              Text('通过 PersonStory 与人物主链共用同一内存关联表。')
                .fontSize($r('app.float.ts_font_caption'))
                .fontColor($r('app.color.ts_text_tertiary'))
                .width('100%')
              Row({ space: 8 }) {
                TextInput({ placeholder: '新人物显示名', text: this.newPersonName })
                  .layoutWeight(1)
                  .height(48)
                  .backgroundColor($r('app.color.ts_surface_container_high'))
                  .borderRadius(10)
                  .padding({ left: 12, right: 12 })
                  .onChange((v: string): void => {
                    this.newPersonName = v;
                  })
                  .enterKeyType(EnterKeyType.Done)
                  .onSubmit((): void => {
                    this.createPersonQuick();
                  })
                Button('创建人物')
                  .height(48)
                  .fontSize($r('app.float.ts_font_support'))
                  .backgroundColor($r('app.color.ts_color_info_container'))
                  .fontColor($r('app.color.ts_color_info'))
                  .onClick((): void => {
                    this.createPersonQuick();
                  })
              }
              .width('100%')

              if (this.personsAll.length === 0) {
                Text('暂无人物，可先创建后与故事关联。')
                  .fontSize($r('app.float.ts_font_caption'))
                  .fontColor($r('app.color.ts_text_tertiary'))
                  .width('100%')
              }
              Column({ space: 8 }) {
                ForEach(this.personsAll, (p: PersonModel) => {
                  Row({ space: 8 }) {
                    Text(p.displayName)
                      .layoutWeight(1)
                      .fontSize($r('app.float.ts_font_support'))
                      .fontColor($r('app.color.ts_text_primary'))
                    Button(this.linkedPersonIds.indexOf(p.id) >= 0 ? '解除关联' : '关联')
                      .height(36)
                      .fontSize($r('app.float.ts_font_overline'))
                      .backgroundColor($r('app.color.ts_surface_container_high'))
                      .fontColor($r('app.color.ts_brand_primary'))
                      .onClick((): void => {
                        this.togglePersonLink(p);
                      })
                  }
                  .padding(12)
                  .width('100%')
                  .backgroundColor($r('app.color.ts_surface_container_high'))
                  .borderRadius(10)
                  .border({ width: 1, color: $r('app.color.ts_outline') })
                }, (p: PersonModel): string => `person-row-${p.id}`)
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.ts_surface_container'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.ts_outline') })

            Column({ space: 12 }) {
              Text('照片（故事 · PhotoOwnerLink）')
                .fontSize($r('app.float.ts_font_label'))
                .fontColor($r('app.color.ts_text_primary'))
                .fontWeight(FontWeight.Medium)
                .width('100%')
              Text('与人物页一致：会话内可追溯；单次选择最多 9 张（picker 上限），ST-07 以计划为准。')
                .fontSize($r('app.float.ts_font_caption'))
                .fontColor($r('app.color.ts_text_tertiary'))
                .width('100%')
              Button('从相册选择照片（可多选）')
                .width('100%')
                .height(44)
                .fontSize($r('app.float.ts_font_support'))
                .fontWeight(FontWeight.Medium)
                .backgroundColor($r('app.color.ts_color_info_container'))
                .fontColor($r('app.color.ts_color_info'))
                .onClick((): void => {
                  this.pickPhotosFromAlbum();
                })

              if (BuildProfile.DEBUG) {
                Text(this.debugLastAlbumInject.length > 0 ? this.debugLastAlbumInject : '【E2E】尚未注入 mock URI')
                  .fontSize($r('app.float.ts_font_overline'))
                  .fontColor($r('app.color.ts_debug_banner'))
                  .width('100%')
                Row({ space: 8 }) {
                  Button('【DEBUG】注入相册等价 URI')
                    .fontSize($r('app.float.ts_font_overline'))
                    .layoutWeight(1)
                    .height(36)
                    .backgroundColor($r('app.color.ts_surface_container_high'))
                    .fontColor($r('app.color.ts_text_secondary'))
                    .onClick((): void => {
                      this.injectDebugAlbumEquivUri('file://e2e/album-equiv-story-1');
                    })
                  Button('【DEBUG】再注相同 URI')
                    .fontSize($r('app.float.ts_font_overline'))
                    .layoutWeight(1)
                    .height(36)
                    .backgroundColor($r('app.color.ts_surface_container_high'))
                    .fontColor($r('app.color.ts_text_secondary'))
                    .onClick((): void => {
                      this.injectDebugAlbumEquivUri('file://e2e/album-equiv-story-1');
                    })
                }
                .width('100%')
              }

              if (this.photos.length === 0) {
                Text('暂无挂载照片')
                  .fontColor($r('app.color.ts_text_tertiary'))
                  .fontSize($r('app.float.ts_font_caption'))
                  .width('100%')
              } else {
                Grid() {
                  ForEach(this.photos, (ph: PhotoRefModel) => {
                    GridItem() {
                      Column() {
                        Image(ph.uri).width('100%').height(96).objectFit(ImageFit.Cover).borderRadius(8)
                        Text(`ref#${ph.id}`)
                          .fontSize($r('app.float.ts_font_overline'))
                          .fontColor($r('app.color.ts_text_caption'))
                          .margin({ top: 4 })
                      }
                    }
                  }, (ph: PhotoRefModel): string => `sph-${ph.id}`)
                }
                .columnsTemplate('1fr 1fr 1fr')
                .columnsGap(8)
                .rowsGap(8)
                .width('100%')
                .scrollBar(BarState.Off)
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.ts_surface_container'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.ts_outline') })

            Column({ space: 10 }) {
              Text('批量导入')
                .fontSize($r('app.float.ts_font_label'))
                .fontColor($r('app.color.ts_text_primary'))
                .fontWeight(FontWeight.Medium)
                .width('100%')
              Text('走相册向导：选图 → 准备 → 条件 → 扫描 → 确认写入（形态一）。')
                .fontSize($r('app.float.ts_font_caption'))
                .fontColor($r('app.color.ts_text_tertiary'))
                .width('100%')
              Button('进入导入向导壳页')
                .width('100%')
                .height(48)
                .fontSize($r('app.float.ts_font_body'))
                .fontWeight(FontWeight.Medium)
                .backgroundColor($r('app.color.ts_brand_primary'))
                .fontColor($r('app.color.ts_import_bar_on_bg'))
                .onClick((): void => {
                  dismissSoftKeyboard();
                  router.pushUrl({
                    url: 'pages/import/ImportPage',
                    params: { ctx: 'story', ownerId: `${this.storyId}` }
                  });
                })
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.ts_brand_primary_container'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.ts_outline') })
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
        Column({ space: 8 }) {
          Text('未找到故事或路由参数缺失（需要 storyId）。')
            .fontSize($r('app.float.ts_font_body'))
            .fontColor($r('app.color.ts_color_warning'))
            .width('100%')
        }
        .width('100%')
        .padding(16)
        .margin({ left: 16, right: 16 })
        .backgroundColor($r('app.color.ts_surface_container'))
        .borderRadius(12)
        .border({ width: 1, color: $r('app.color.ts_outline') })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.ts_surface'))
  }
}
