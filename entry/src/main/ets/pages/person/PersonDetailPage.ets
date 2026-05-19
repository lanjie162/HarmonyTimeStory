import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import BuildProfile from 'BuildProfile';
import type { PersonModel, PhotoRefModel, StoryModel } from '../../domain/model/Models';
import { getPersonService } from '../../features/person/PersonFeature';
import { getStoryService } from '../../features/story/StoryFeature';
import { dismissSoftKeyboard } from '../../common/ime/SoftKeyboard';

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
  /** Hypium：仅 DEBUG 展示，便于断言加图结果（不依赖 Toast）。 */
  @State debugLastAlbumInject: string = '';

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
    dismissSoftKeyboard();
    const ok = getPersonService().updatePerson(this.personId, this.draftName);
    if (!ok) {
      promptAction.showToast({ message: '保存失败：人物不存在或名称为空' });
      return;
    }
    promptAction.showToast({ message: '已保存显示名' });
    this.refresh();
  }

  private createStoryQuick(): void {
    dismissSoftKeyboard();
    const sid = getStoryService().createStory(this.newStoryTitle);
    if (sid < 0) {
      promptAction.showToast({ message: '故事标题不能为空' });
      return;
    }
    this.newStoryTitle = '';
    promptAction.showToast({ message: `已创建故事 #${sid}，可选择「关联」` });
    this.refresh();
  }

  /** 相册等价路径：与 pickPhotosFromAlbum 成功分支同一 Service，不打开系统相册。 */
  private injectDebugAlbumEquivUri(uri: string): void {
    if (this.personId <= 0) {
      this.debugLastAlbumInject = '【E2E】inject skip：无 personId';
      return;
    }
    const res = getPersonService().addPhotoToPerson(this.personId, uri);
    if (res.duplicate) {
      this.debugLastAlbumInject = '【E2E】上次加图：重复跳过（PH-01）';
    } else if (res.success) {
      this.debugLastAlbumInject = '【E2E】上次加图：成功 file://e2e/album-equiv-1';
    } else {
      this.debugLastAlbumInject = '【E2E】上次加图：失败（人物不存在或 URI 为空）';
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
    dismissSoftKeyboard();
    const svc = getPersonService();
    if (this.linkedStoryIds.indexOf(s.id) >= 0) {
      svc.unlinkPersonFromStory(this.personId, s.id);
    } else {
      svc.linkPersonToStory(this.personId, s.id);
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
        Text('人物详情')
          .fontSize($r('app.float.ts_font_title'))
          .fontColor($r('app.color.ts_text_primary'))
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })
      .alignItems(VerticalAlign.Center)

      if (this.person !== null && this.personId > 0) {
        Scroll() {
          Column({ space: 14 }) {
            Column({ space: 6 }) {
              Text(this.person.displayName)
                .fontSize($r('app.float.ts_font_headline'))
                .fontColor($r('app.color.ts_text_primary'))
                .fontWeight(FontWeight.Medium)
                .width('100%')
              Text(`人物 · id=${this.person.id}`)
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
              TextInput({ placeholder: '显示名', text: this.draftName })
                .onChange((v: string): void => {
                  this.draftName = v;
                })
                .enterKeyType(EnterKeyType.Done)
                .onSubmit((): void => {
                  this.saveName();
                })
                .width('100%')
                .height(48)
                .backgroundColor($r('app.color.ts_surface_container_high'))
                .borderRadius(10)
                .padding({ left: 12, right: 12 })
              Button('保存显示名')
                .width('100%')
                .height(44)
                .fontSize($r('app.float.ts_font_support'))
                .fontWeight(FontWeight.Medium)
                .backgroundColor($r('app.color.ts_brand_primary'))
                .fontColor($r('app.color.ts_import_bar_on_bg'))
                .onClick((): void => {
                  this.saveName();
                })
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.ts_surface_container'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.ts_outline') })

            Column({ space: 12 }) {
              Text('关联故事')
                .fontSize($r('app.float.ts_font_label'))
                .fontColor($r('app.color.ts_text_primary'))
                .fontWeight(FontWeight.Medium)
                .width('100%')
              Text('可新建故事后点「关联 / 解除关联」写入 PersonStory（内存）。')
                .fontSize($r('app.float.ts_font_caption'))
                .fontColor($r('app.color.ts_text_tertiary'))
                .width('100%')
              Row({ space: 8 }) {
                TextInput({ placeholder: '新故事标题', text: this.newStoryTitle })
                  .layoutWeight(1)
                  .height(48)
                  .backgroundColor($r('app.color.ts_surface_container_high'))
                  .borderRadius(10)
                  .padding({ left: 12, right: 12 })
                  .onChange((v: string): void => {
                    this.newStoryTitle = v;
                  })
                  .enterKeyType(EnterKeyType.Done)
                  .onSubmit((): void => {
                    this.createStoryQuick();
                  })
                Button('创建')
                  .height(48)
                  .fontSize($r('app.float.ts_font_support'))
                  .backgroundColor($r('app.color.ts_color_info_container'))
                  .fontColor($r('app.color.ts_color_info'))
                  .onClick((): void => {
                    this.createStoryQuick();
                  })
              }
              .width('100%')

              if (this.storiesAll.length === 0) {
                Text('暂无故事，可先创建或与故事主线并行补充。')
                  .fontSize($r('app.float.ts_font_caption'))
                  .fontColor($r('app.color.ts_text_tertiary'))
                  .width('100%')
              }
              Column({ space: 8 }) {
                ForEach(this.storiesAll, (s: StoryModel) => {
                  Row({ space: 8 }) {
                    Text(s.title)
                      .layoutWeight(1)
                      .fontSize($r('app.float.ts_font_support'))
                      .fontColor($r('app.color.ts_text_primary'))
                    Button(this.linkedStoryIds.indexOf(s.id) >= 0 ? '解除关联' : '关联')
                      .height(36)
                      .fontSize($r('app.float.ts_font_overline'))
                      .backgroundColor($r('app.color.ts_surface_container_high'))
                      .fontColor($r('app.color.ts_brand_primary'))
                      .onClick((): void => {
                        this.toggleStoryLink(s);
                      })
                  }
                  .padding(12)
                  .width('100%')
                  .backgroundColor($r('app.color.ts_surface_container_high'))
                  .borderRadius(10)
                  .border({ width: 1, color: $r('app.color.ts_outline') })
                }, (s: StoryModel): string => `story-row-${s.id}`)
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.ts_surface_container'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.ts_outline') })

            Column({ space: 12 }) {
              Text('照片（PhotoOwnerLink）')
                .fontSize($r('app.float.ts_font_label'))
                .fontColor($r('app.color.ts_text_primary'))
                .fontWeight(FontWeight.Medium)
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
                      this.injectDebugAlbumEquivUri('file://e2e/album-equiv-1');
                    })
                  Button('【DEBUG】再注相同 URI')
                    .fontSize($r('app.float.ts_font_overline'))
                    .layoutWeight(1)
                    .height(36)
                    .backgroundColor($r('app.color.ts_surface_container_high'))
                    .fontColor($r('app.color.ts_text_secondary'))
                    .onClick((): void => {
                      this.injectDebugAlbumEquivUri('file://e2e/album-equiv-1');
                    })
                }
                .width('100%')
              }

              if (BuildProfile.DEBUG) {
                Text(`【E2E】照片数=${this.photos.length}`)
                  .fontSize($r('app.float.ts_font_overline'))
                  .fontColor($r('app.color.ts_debug_banner'))
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
                  }, (ph: PhotoRefModel): string => `ph-${ph.id}`)
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
              Text('走相册向导：选图 → 准备 → 条件 → 扫描 → 确认写入（形态二）。')
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
                    params: { ctx: 'person', ownerId: `${this.personId}` }
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
          Text('未找到人物或路由参数缺失（需要 personId）。')
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
