import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import BuildProfile from 'BuildProfile';
import type { PersonModel, PhotoRefModel, StoryModel } from '../../domain/model/Models';
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
  return new Date(2000, 0, 1);
}

@Entry
@Component
export struct StoryDetailPage {
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

  onPageShow(): void {
    if (this.storyId > 0) {
      this.refresh();
    }
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

  /** T-31 UriHealthChecker：进一步区分本地已删 vs 云端不可访问，并更新 DB 状态。 */
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
    this.refresh();
  }

  private confirmDeleteCurrentStory(): void {
    AlertDialog.show({
      title: '确认删除',
      message: `确定要删除"${this.story?.title ?? ''}"吗？此操作不可撤销。`,
      primaryButton: {
        value: '取消',
        action: (): void => {
          // do nothing
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
          // do nothing
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
      // user cancelled
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
            // ====== 档案摘要 ======
            Column({ space: 6 }) {
              Text(this.story.title)
                .fontSize($r('app.float.ts_font_headline'))
                .fontColor($r('app.color.ts_text_primary'))
                .fontWeight(FontWeight.Medium)
                .width('100%')
              Text(`故事 · id=${this.story.id} · ${formatDate(this.story.timeStart)} ~ ${formatDate(this.story.timeEnd)}`)
                .fontSize($r('app.float.ts_font_caption'))
                .fontColor($r('app.color.ts_text_tertiary'))
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.ts_surface_container'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.ts_outline') })

            // ====== 编辑（全部字段） ======
            Column({ space: 12 }) {
              Text('编辑')
                .fontSize($r('app.float.ts_font_label'))
                .fontColor($r('app.color.ts_text_primary'))
                .fontWeight(FontWeight.Medium)
                .width('100%')

              // 标题
              TextInputWithKeyboard({
                placeholder: '标题（必填）',
                value: this.draftTitle,
                onChange: (v: string): void => { this.draftTitle = v; }
              })

              // 描述
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

              // 封面 URI
              Row({ space: 8 }) {
                Text('封面')
                  .fontSize($r('app.float.ts_font_support'))
                  .fontColor($r('app.color.ts_text_secondary'))
                if (this.draftCoverUri.length > 0) {
                  Text(this.draftCoverUri.length > 30 ? this.draftCoverUri.substring(0, 30) + '...' : this.draftCoverUri)
                    .fontSize($r('app.float.ts_font_overline'))
                    .fontColor($r('app.color.ts_text_primary'))
                    .layoutWeight(1)
                    .maxLines(1)
                  Button('移除')
                    .height(32)
                    .fontSize($r('app.float.ts_font_overline'))
                    .backgroundColor($r('app.color.ts_surface_container_high'))
                    .fontColor($r('app.color.ts_color_warning'))
                    .onClick((): void => {
                      this.removeCover();
                    })
                } else {
                  Button('选择封面')
                    .height(32)
                    .fontSize($r('app.float.ts_font_overline'))
                    .backgroundColor($r('app.color.ts_color_info_container'))
                    .fontColor($r('app.color.ts_color_info'))
                    .onClick((): void => {
                      this.pickCoverFromAlbum();
                    })
                }
              }
              .width('100%')

              // 地点
              TextInputWithKeyboard({
                placeholder: '地点（可选）',
                value: this.draftLocation,
                onChange: (v: string): void => { this.draftLocation = v; }
              })

              // 时间范围 - 开始日期
              Row({ space: 8 }) {
                Text('开始日期')
                  .fontSize($r('app.float.ts_font_support'))
                  .fontColor($r('app.color.ts_text_secondary'))
                Text(this.draftTimeStartText)
                  .fontSize($r('app.float.ts_font_support'))
                  .fontColor($r('app.color.ts_text_primary'))
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

              // 时间范围 - 结束日期
              Row({ space: 8 }) {
                Text('结束日期')
                  .fontSize($r('app.float.ts_font_support'))
                  .fontColor($r('app.color.ts_text_secondary'))
                Text(this.draftTimeEndText)
                  .fontSize($r('app.float.ts_font_support'))
                  .fontColor($r('app.color.ts_text_primary'))
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

              // 标签
              Column({ space: 6 }) {
                Text('自定义标签')
                  .fontSize($r('app.float.ts_font_support'))
                  .fontColor($r('app.color.ts_text_secondary'))
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
                    .fontSize($r('app.float.ts_font_overline'))
                    .backgroundColor($r('app.color.ts_color_info_container'))
                    .fontColor($r('app.color.ts_color_info'))
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
                          .fontSize($r('app.float.ts_font_overline'))
                          .fontColor($r('app.color.ts_brand_primary'))
                        Button('x')
                          .height('20vp')
                          .width('20vp')
                          .fontSize('10fp')
                          .backgroundColor($r('app.color.ts_surface_container_high'))
                          .fontColor($r('app.color.ts_color_warning'))
                          .onClick((): void => {
                            this.removeTag(idx);
                          })
                      }
                      .padding({ left: 8, right: 4, top: 2, bottom: 2 })
                      .backgroundColor($r('app.color.ts_brand_primary_container'))
                      .borderRadius(14)
                    })
                  }
                  .width('100%')
                }
              }
              .width('100%')

              // 保存按钮
              Button('保存全部字段')
                .width('100%')
                .height(44)
                .fontSize($r('app.float.ts_font_support'))
                .fontWeight(FontWeight.Medium)
                .backgroundColor($r('app.color.ts_brand_primary'))
                .fontColor($r('app.color.ts_import_bar_on_bg'))
                .onClick((): void => {
                  this.saveAll();
                })
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.ts_surface_container'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.ts_outline') })

            // ====== 关联人物 ======
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
                TextInputWithKeyboard({
                  placeholder: '新人物显示名',
                  value: this.newPersonName,
                  onChange: (v: string): void => { this.newPersonName = v; },
                  onSubmit: (): void => { this.createPersonQuick(); },
                  layoutWeight: 1
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

            // ====== 照片 ======
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
                Button('【DEBUG】GC 孤儿 PhotoRef')
                  .fontSize($r('app.float.ts_font_overline'))
                  .backgroundColor($r('app.color.ts_surface_container_high'))
                  .fontColor($r('app.color.ts_text_secondary'))
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
                  .fontColor($r('app.color.ts_text_tertiary'))
                  .fontSize($r('app.float.ts_font_caption'))
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
                          // T-31：当 Image 加载失败时，用 UriHealthChecker 进一步区分本地已删 vs 云端不可访问
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
            .backgroundColor($r('app.color.ts_surface_container'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.ts_outline') })

            // ====== 批量导入入口 ======
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

            // ====== 危险操作：删除故事 ======
            Column({ space: 10 }) {
              Button('删除故事')
                .width('100%')
                .height(44)
                .fontSize($r('app.float.ts_font_support'))
                .fontWeight(FontWeight.Medium)
                .backgroundColor('#CC0000')
                .fontColor($r('app.color.ts_import_bar_on_bg'))
                .onClick((): void => {
                  this.confirmDeleteCurrentStory();
                })
              Text('删除后将同时移除该故事的所有关联与照片挂载，不可撤销。')
                .fontSize($r('app.float.ts_font_overline'))
                .fontColor($r('app.color.ts_text_caption'))
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.ts_surface_container'))
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