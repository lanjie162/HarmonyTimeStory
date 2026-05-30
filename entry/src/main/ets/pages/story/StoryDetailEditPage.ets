import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import BuildProfile from 'BuildProfile';
import type { PersonModel, PhotoMetadata, PhotoRefModel, StoryModel } from '../../domain/model/Models';
import { getPersonService } from '../../features/person/PersonFeature';
import { getStoryService } from '../../features/story/StoryFeature';
import { getPhotoLibraryService } from '../../features/photolibrary/PhotoLibraryFeature';
import { PhotoGridItem } from '../../common/ui/PhotoGridItem';
import { UriHealthChecker } from '../../infrastructure/media/UriHealthChecker';
import { dismissSoftKeyboard } from '../../common/ime/SoftKeyboard';
import { TextInputWithKeyboard, TextAreaWithKeyboard } from '../../common/ui/KeyboardAwareInput';

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

function buildPickerDate(ts: number | null): Date {
  if (ts !== null && ts > 0) {
    return new Date(ts);
  }
  return new Date();
}

@Entry
@Component
export struct StoryDetailEditPage {
  @State storyId: number = 0;
  @State story: StoryModel | null = null;
  @State draftTitle: string = '';
  @State draftDescription: string = '';
  @State draftTimeStart: number = 0;
  @State draftTimeEnd: number = 0;
  @State draftTimeStartText: string = '选择开始日期';
  @State draftTimeEndText: string = '选择结束日期';
  @State draftCoverUri: string = '';
  @State draftLocation: string = '';
  @State draftTags: string[] = [];
  @State draftTagInput: string = '';
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

  private refresh(): void {
    const sSvc = getStoryService();
    this.story = sSvc.getStory(this.storyId);
    if (this.story !== null) {
      this.draftTitle = this.story.title;
      this.draftDescription = this.story.description;
      this.draftTimeStart = this.story.timeStart ?? 0;
      this.draftTimeEnd = this.story.timeEnd ?? 0;
      this.draftTimeStartText = formatDate(this.story.timeStart);
      this.draftTimeEndText = formatDate(this.story.timeEnd);
      this.draftCoverUri = this.story.coverUri;
      this.draftLocation = this.story.location;
      this.draftTags = [...this.story.tags];
    }
    this.personsAll = getPersonService().listPersons();
    this.linkedPersonIds = sSvc.listLinkedPersons(this.storyId).map((p): number => p.id);
    this.photos = sSvc.listStoryPhotos(this.storyId);
  }

  private async checkPhotoHealthAndUpdate(photoRefId: number, uri: string): Promise<void> {
    const health = await UriHealthChecker.check(uri);
    if (health > 1) {
      getPhotoLibraryService().markPhotoAsFailed(photoRefId, health);
      this.refresh();
    }
  }

  private saveAll(): void {
    dismissSoftKeyboard();
    const svc = getStoryService();
    const ok = svc.updateStoryAll!(this.storyId, this.draftTitle,
      this.draftDescription,
      this.draftTimeStart > 0 ? this.draftTimeStart : null,
      this.draftTimeEnd > 0 ? this.draftTimeEnd : null,
      this.draftCoverUri,
      this.draftLocation,
      this.draftTags
    );
    if (!ok) {
      promptAction.showToast({ message: '保存失败：故事不存在或标题为空' });
      return;
    }
    promptAction.showToast({ message: '已保存全部字段' });
    router.back();
  }

  private confirmDeleteCurrentStory(): void {
    AlertDialog.show({
      title: '确认删除',
      message: `确定要删除"${this.story?.title ?? ''}"吗？此操作不可撤销。`,
      primaryButton: {
        value: '取消',
        action: (): void => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#CC0000',
        action: (): void => {
          dismissSoftKeyboard();
          const svc = getStoryService();
          const ok = svc.deleteStory(this.storyId);
          if (ok) {
            promptAction.showToast({ message: '已删除' });
            router.back();
          } else {
            promptAction.showToast({ message: '删除失败：故事不存在' });
          }
        }
      }
    });
  }

  private confirmRemovePhoto(photoRefId: number): void {
    AlertDialog.show({
      title: '确认移除',
      message: `确定移除该照片（ref#${photoRefId}）？仅解除关联，不删系统原图。`,
      primaryButton: {
        value: '取消',
        action: (): void => {
        }
      },
      secondaryButton: {
        value: '移除',
        fontColor: '#CC0000',
        action: (): void => {
          dismissSoftKeyboard();
          const svc = getStoryService();
          const ok = svc.removePhotoFromStory(this.storyId, photoRefId);
          if (ok) {
            promptAction.showToast({ message: '已移除照片' });
          } else {
            promptAction.showToast({ message: '移除失败' });
          }
          this.refresh();
        }
      }
    });
  }

  private async pickCoverFromAlbum(): Promise<void> {
    dismissSoftKeyboard();
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.maxSelectNumber = 1;
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select(options);
      const uris = result.photoUris;
      if (!uris || uris.length === 0) {
        return;
      }
      this.draftCoverUri = uris[0];
    } catch (_e) {
    }
  }

  private removeCover(): void {
    this.draftCoverUri = '';
  }

  private addTag(): void {
    dismissSoftKeyboard();
    const t = this.draftTagInput.trim();
    if (t.length === 0) {
      return;
    }
    if (this.draftTags.indexOf(t) >= 0) {
      promptAction.showToast({ message: '标签已存在' });
      return;
    }
    this.draftTags.push(t);
    this.draftTagInput = '';
  }

  private removeTag(index: number): void {
    this.draftTags.splice(index, 1);
    this.draftTags = [...this.draftTags];
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
      
      // 添加照片
      for (const uri of uris) {
        const metadata: PhotoMetadata = {};
        // 暂时简化，不获取元数据
        const res = svc.addPhotoToStory(this.storyId, uri, metadata);
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
        Button('←')
          .height(36)
          .fontSize(24)
          .backgroundColor(Color.Transparent)
          .fontColor('#FFFFFF')
          .onClick((): void => {
            dismissSoftKeyboard();
            router.back();
          })
        Text('编辑故事')
          .fontSize(20)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Button('保存')
          .height(36)
          .fontSize(16)
          .backgroundColor('#67C31F')
          .fontColor('#FFFFFF')
          .onClick((): void => {
            this.saveAll();
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .backgroundColor('#333333')
      .alignItems(VerticalAlign.Center)

      if (this.story !== null && this.storyId > 0) {
        Scroll() {
          Column({ space: 14 }) {
            Column({ space: 12 }) {
              Text('编辑')
                .fontSize(16)
                .fontColor('#FFFFFF')
                .fontWeight(FontWeight.Medium)
                .width('100%')

              TextInputWithKeyboard({
                placeholder: '标题（必填）',
                value: this.draftTitle,
                onChange: (v: string): void => { this.draftTitle = v; }
              })

              Column() {
                TextAreaWithKeyboard({
                  placeholder: '描述（可选）',
                  value: this.draftDescription,
                  onChange: (v: string): void => { this.draftDescription = v; }
                })
              }
              .width('100%')
              .onClick((): void => {
                dismissSoftKeyboard();
              })

              Row({ space: 8 }) {
                Text('封面')
                  .fontSize(14)
                  .fontColor('#AAAAAA')
                if (this.draftCoverUri.length > 0) {
                  Text(this.draftCoverUri.length > 30 ? this.draftCoverUri.substring(0, 30) + '...' : this.draftCoverUri)
                    .fontSize(12)
                    .fontColor('#FFFFFF')
                    .layoutWeight(1)
                    .maxLines(1)
                  Button('移除')
                    .height(32)
                    .fontSize(12)
                    .backgroundColor('#444444')
                    .fontColor('#FF5555')
                    .onClick((): void => {
                      this.removeCover();
                    })
                } else {
                  Button('选择封面')
                    .height(32)
                    .fontSize(12)
                    .backgroundColor('#1E88E5')
                    .fontColor('#FFFFFF')
                    .onClick((): void => {
                      this.pickCoverFromAlbum();
                    })
                }
              }
              .width('100%')

              TextInputWithKeyboard({
                placeholder: '地点（可选）',
                value: this.draftLocation,
                onChange: (v: string): void => { this.draftLocation = v; }
              })

              Row({ space: 8 }) {
                Text('开始日期')
                  .fontSize(14)
                  .fontColor('#AAAAAA')
                Text(this.draftTimeStartText)
                  .fontSize(14)
                  .fontColor('#FFFFFF')
              }
              .width('100%')
              CalendarPicker({
                hintRadius: 16,
                selected: buildPickerDate(this.draftTimeStart > 0 ? this.draftTimeStart : null)
              })
                .width('100%')
                .onChange((value: Date): void => {
                  this.draftTimeStart = value.getTime();
                  this.draftTimeStartText = formatDate(this.draftTimeStart);
                })

              Row({ space: 8 }) {
                Text('结束日期')
                  .fontSize(14)
                  .fontColor('#AAAAAA')
                Text(this.draftTimeEndText)
                  .fontSize(14)
                  .fontColor('#FFFFFF')
              }
              .width('100%')
              CalendarPicker({
                hintRadius: 16,
                selected: buildPickerDate(this.draftTimeEnd > 0 ? this.draftTimeEnd : null),
                start: this.draftTimeStart > 0 ? new Date(this.draftTimeStart) : new Date(1900, 0, 1)
              })
                .width('100%')
                .onChange((value: Date): void => {
                  this.draftTimeEnd = value.getTime();
                  this.draftTimeEndText = formatDate(this.draftTimeEnd);
                })

              Column({ space: 6 }) {
                Text('自定义标签')
                  .fontSize(14)
                  .fontColor('#AAAAAA')
                  .width('100%')
                Row({ space: 8 }) {
                  TextInputWithKeyboard({
                    placeholder: '输入标签',
                    value: this.draftTagInput,
                    onChange: (v: string): void => { this.draftTagInput = v; },
                    onSubmit: (): void => { this.addTag(); },
                    layoutWeight: 1,
                    height: 40
                  })
                  Button('添加')
                    .height(40)
                    .fontSize(12)
                    .backgroundColor('#1E88E5')
                    .fontColor('#FFFFFF')
                    .onClick((): void => {
                      this.addTag();
                    })
                }
                .width('100%')

                if (this.draftTags.length > 0) {
                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(this.draftTags, (tag: string, idx: number) => {
                      Row({ space: 4 }) {
                        Text(tag)
                          .fontSize(12)
                          .fontColor('#67C31F')
                        Button('x')
                          .height('20vp')
                          .width('20vp')
                          .fontSize('10fp')
                          .backgroundColor('#444444')
                          .fontColor('#FF5555')
                          .onClick((): void => {
                            this.removeTag(idx);
                          })
                      }
                      .padding({ left: 8, right: 4, top: 2, bottom: 2 })
                      .backgroundColor('#333333')
                      .borderRadius(14)
                    })
                  }
                  .width('100%')
                }
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#222222')
            .borderRadius(12)
            .border({ width: 1, color: '#444444' })

            Column({ space: 10 }) {
              Button('删除故事')
                .width('100%')
                .height(44)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .backgroundColor('#CC0000')
                .fontColor('#FFFFFF')
                .onClick((): void => {
                  this.confirmDeleteCurrentStory();
                })
              Text('删除后将同时移除该故事的所有关联与照片挂载，不可撤销。')
                .fontSize(12)
                .fontColor('#AAAAAA')
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#222222')
            .borderRadius(12)
            .border({ width: 1, color: '#444444' })

            Column({ space: 12 }) {
              Text('关联人物')
                .fontSize(16)
                .fontColor('#FFFFFF')
                .fontWeight(FontWeight.Medium)
                .width('100%')
              Row({ space: 8 }) {
                TextInputWithKeyboard({
                  placeholder: '新人物显示名',
                  value: this.newPersonName,
                  onChange: (v: string): void => { this.newPersonName = v; },
                  onSubmit: (): void => { this.createPersonQuick(); },
                  layoutWeight: 1
                })
                Button('创建人物')
                  .height(48)
                  .fontSize(14)
                  .backgroundColor('#1E88E5')
                  .fontColor('#FFFFFF')
                  .onClick((): void => {
                    this.createPersonQuick();
                  })
              }
              .width('100%')

              if (this.personsAll.length === 0) {
                Text('暂无人物，可先创建后与故事关联。')
                  .fontSize(12)
                  .fontColor('#AAAAAA')
                  .width('100%')
              }
              Column({ space: 8 }) {
                ForEach(this.personsAll, (p: PersonModel) => {
                  Row({ space: 8 }) {
                    Text(p.displayName)
                      .layoutWeight(1)
                      .fontSize(14)
                      .fontColor('#FFFFFF')
                    Button(this.linkedPersonIds.indexOf(p.id) >= 0 ? '解除关联' : '关联')
                      .height(36)
                      .fontSize(12)
                      .backgroundColor('#444444')
                      .fontColor('#67C31F')
                      .onClick((): void => {
                        this.togglePersonLink(p);
                      })
                  }
                  .padding(12)
                  .width('100%')
                  .backgroundColor('#444444')
                  .borderRadius(10)
                  .border({ width: 1, color: '#555555' })
                }, (p: PersonModel): string => `person-row-${p.id}`)
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#222222')
            .borderRadius(12)
            .border({ width: 1, color: '#444444' })

            Column({ space: 12 }) {
              Text('照片')
                .fontSize(16)
                .fontColor('#FFFFFF')
                .fontWeight(FontWeight.Medium)
                .width('100%')
              Button('从相册选择照片（可多选）')
                .width('100%')
                .height(44)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .backgroundColor('#1E88E5')
                .fontColor('#FFFFFF')
                .onClick((): void => {
                  this.pickPhotosFromAlbum();
                })

              if (BuildProfile.DEBUG) {
                Text(this.debugLastAlbumInject.length > 0 ? this.debugLastAlbumInject : '【E2E】尚未注入 mock URI')
                  .fontSize(12)
                  .fontColor('#FFFF00')
                  .width('100%')
                Row({ space: 8 }) {
                  Button('【DEBUG】注入相册等价 URI')
                    .fontSize(12)
                    .layoutWeight(1)
                    .height(36)
                    .backgroundColor('#444444')
                    .fontColor('#AAAAAA')
                    .onClick((): void => {
                      this.injectDebugAlbumEquivUri('file://e2e/album-equiv-story-1');
                    })
                  Button('【DEBUG】再注相同 URI')
                    .fontSize(12)
                    .layoutWeight(1)
                    .height(36)
                    .backgroundColor('#444444')
                    .fontColor('#AAAAAA')
                    .onClick((): void => {
                      this.injectDebugAlbumEquivUri('file://e2e/album-equiv-story-1');
                    })
                }
                .width('100%')
                Button('【DEBUG】GC 孤儿 PhotoRef')
                  .fontSize(12)
                  .backgroundColor('#444444')
                  .fontColor('#AAAAAA')
                  .width('100%')
                  .height(36)
                  .onClick((): void => {
                    const n = getStoryService().gcOrphanPhotoRefs();
                    promptAction.showToast({ message: `GC 完成：清理 ${n} 个孤儿 PhotoRef` });
                    this.refresh();
                  })
              }

              if (this.photos.length === 0) {
                Text('暂无挂载照片')
                  .fontColor('#AAAAAA')
                  .fontSize(12)
                  .width('100%')
              } else {
                Grid() {
                  ForEach(this.photos, (ph: PhotoRefModel) => {
                    GridItem() {
                      PhotoGridItem({
                        ph: ph,
                        onRemove: (photoRefId: number): void => {
                          this.confirmRemovePhoto(photoRefId);
                        },
                        onStatusChanged: (photoRefId: number, status: number): void => {
                          getPhotoLibraryService().markPhotoAsFailed(photoRefId, status);
                          this.checkPhotoHealthAndUpdate(photoRefId, ph.uri);
                        }
                      })
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
            .backgroundColor('#222222')
            .borderRadius(12)
            .border({ width: 1, color: '#444444' })

            Column({ space: 10 }) {
              Text('批量导入')
                .fontSize(16)
                .fontColor('#FFFFFF')
                .fontWeight(FontWeight.Medium)
                .width('100%')
              Text('走相册向导：选图 → 准备 → 条件 → 扫描 → 确认写入。')
                .fontSize(12)
                .fontColor('#AAAAAA')
                .width('100%')
              Button('进入导入向导壳页')
                .width('100%')
                .height(48)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .backgroundColor('#67C31F')
                .fontColor('#FFFFFF')
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
            .backgroundColor('#333333')
            .borderRadius(12)
            .border({ width: 1, color: '#444444' })
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
            .fontSize(16)
            .fontColor('#FF5555')
            .width('100%')
        }
        .width('100%')
        .padding(16)
        .margin({ left: 16, right: 16 })
        .backgroundColor('#222222')
        .borderRadius(12)
        .border({ width: 1, color: '#444444' })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#111111')
  }
}
