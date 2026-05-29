import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type { StoryModel } from '../../domain/model/Models';
import { getStoryService } from '../../features/story/StoryFeature';
import { dismissSoftKeyboard } from '../../common/ime/SoftKeyboard';
import { TextInputWithKeyboard } from '../../common/ui/KeyboardAwareInput';

function timeRangeLabel(s: StoryModel): string {
  if (s.timeStart === null || s.timeStart <= 0) {
    return '';
  }
  if (s.timeEnd !== null && s.timeEnd > 0 && s.timeEnd !== s.timeStart) {
    return `${formatDate(s.timeStart)} ~ ${formatDate(s.timeEnd)}`;
  }
  return formatDate(s.timeStart);
}

function formatDate(ts: number | null): string {
  if (ts === null || ts <= 0) {
    return '';
  }
  const d = new Date(ts);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

@CustomDialog
export struct CreateStoryBottomSheet {
  controller: CustomDialogController;
  @State title: string = '';
  onCreated?: () => void;

  build() {
    Column({ space: 16 }) {
      Text('新建故事')
        .fontSize($r('app.float.ts_font_title'))
        .fontColor($r('app.color.ts_text_primary'))
        .fontWeight(FontWeight.Bold)
        .width('100%')

      TextInputWithKeyboard({
        placeholder: '标题（必填）',
        value: this.title,
        onChange: (v: string): void => {
          this.title = v;
        },
        onSubmit: (): void => {
          this.doCreate();
        }
      })

      Button('创建')
        .width('100%')
        .height(48)
        .fontSize($r('app.float.ts_font_body'))
        .fontWeight(FontWeight.Medium)
        .backgroundColor($r('app.color.ts_brand_primary'))
        .fontColor($r('app.color.ts_import_bar_on_bg'))
        .onClick((): void => {
          this.doCreate();
        })
    }
    .width('100%')
    .padding(24)
    .backgroundColor($r('app.color.ts_surface'))
    .borderRadius({ topLeft: 16, topRight: 16 })
  }

  private doCreate(): void {
    const svc = getStoryService();
    const id = svc.createStory(this.title);
    if (id < 0) {
      promptAction.showToast({ message: '请输入非空标题' });
      return;
    }
    this.title = '';
    promptAction.showToast({ message: `已创建故事 #${id}` });
    this.controller.close();
    this.onCreated?.();
  }
}

@Component
export struct StoryPage {
  @State private stories: StoryModel[] = [];
  @State private swipedStoryId: number = -1;
  createDialogController: CustomDialogController | null = new CustomDialogController({
    builder: CreateStoryBottomSheet({ onCreated: (): void => this.reload() }),
    alignment: DialogAlignment.Bottom,
    customStyle: true,
    autoCancel: true,
    cornerRadius: { topLeft: 16, topRight: 16 }
  });

  aboutToAppear(): void {
    this.reload();
  }

  private reload(): void {
    this.stories = getStoryService().listStories();
  }

  private openCreateSheet(): void {
    dismissSoftKeyboard();
    this.createDialogController?.open();
  }

  private confirmDeleteStory(s: StoryModel): void {
    AlertDialog.show({
      title: '确认删除',
      message: `确定要删除"${s.title}"吗？此操作不可撤销，将同时移除该故事的所有关联与照片挂载。`,
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
          const ok = svc.deleteStory(s.id);
          if (ok) {
            promptAction.showToast({ message: `已删除"${s.title}"` });
          } else {
            promptAction.showToast({ message: '删除失败：故事不存在' });
          }
          this.reload();
        }
      }
    });
  }

  @Builder
  swipeDeleteBuilder() {
    Button('删除')
      .height('100%')
      .fontSize($r('app.float.ts_font_body'))
      .fontColor(Color.White)
      .backgroundColor(Color.Red)
      .borderRadius(0)
      .padding({ left: 16, right: 16 })
      .onClick((): void => {
        const s = this.getSwipedStory();
        if (s !== null) {
          this.confirmDeleteStory(s);
        }
      })
  }

  private getSwipedStory(): StoryModel | null {
    for (const s of this.stories) {
      if (s.id === this.swipedStoryId) {
        return s;
      }
    }
    return null;
  }

  private photoCount(story: StoryModel): number {
    return getStoryService().listStoryPhotos(story.id).length;
  }

  private tagSummary(tags: string[]): string {
    if (tags.length === 0) {
      return '';
    }
    return tags.slice(0, 2).map((t: string): string => `#${t}`).join(' ');
  }

  private locationTagLine(story: StoryModel): string {
    const parts: string[] = [];
    if (story.location.length > 0) {
      parts.push(story.location);
    }
    const tagStr = this.tagSummary(story.tags);
    if (tagStr.length > 0) {
      parts.push(tagStr);
    }
    return parts.join(' · ');
  }

  build() {
    Column({ space: 0 }) {
      Column({ space: 0 }) {
        Row({ space: 10 }) {
          Text('故事')
            .fontSize($r('app.float.ts_font_title'))
            .fontColor($r('app.color.ts_text_primary'))
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)

          Button('+ 创建')
            .fontSize($r('app.float.ts_font_support'))
            .height(36)
            .padding({ left: 14, right: 14 })
            .backgroundColor($r('app.color.ts_brand_primary'))
            .fontColor($r('app.color.ts_import_bar_on_bg'))
            .onClick((): void => {
              this.openCreateSheet();
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 16, top: 12, bottom: 10 })

        Divider().color($r('app.color.ts_outline')).margin({ left: 16, right: 16 })

        if (this.stories.length === 0) {
          Column({ space: 8 }) {
            Text('还没有故事')
              .fontSize($r('app.float.ts_font_headline'))
              .fontColor($r('app.color.ts_text_secondary'))
            Text('点击右上角 [+ 创建] 来新建故事；创建后可在详情里加照片或导入相册。')
              .fontSize($r('app.float.ts_font_caption'))
              .fontColor($r('app.color.ts_text_tertiary'))
              .lineHeight(18)
          }
          .width('100%')
          .padding({ top: 32, left: 24, right: 24 })
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        } else {
          List({ space: 10 }) {
            ForEach(this.stories, (s: StoryModel) => {
              ListItem() {
                Row({ space: 12 }) {
                  Stack() {
                    if (s.coverUri.length > 0) {
                      Image(s.coverUri)
                        .width(48)
                        .height(48)
                        .borderRadius(8)
                        .objectFit(ImageFit.Cover)
                    } else {
                      Row()
                        .width(48)
                        .height(48)
                        .borderRadius(8)
                        .backgroundColor($r('app.color.ts_surface_container_high'))
                    }
                  }
                  .width(48)
                  .height(48)

                  Column({ space: 2 }) {
                    Text(s.title)
                      .fontSize(18)
                      .fontColor($r('app.color.ts_text_primary'))
                      .fontWeight(FontWeight.Medium)
                      .lineHeight(26)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    Text(timeRangeLabel(s))
                      .fontSize(13)
                      .fontColor($r('app.color.ts_text_tertiary'))
                      .lineHeight(18)

                    Text(this.locationTagLine(s))
                      .fontSize(13)
                      .fontColor($r('app.color.ts_text_caption'))
                      .lineHeight(18)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    Text(`${this.photoCount(s)} 张照片`)
                      .fontSize(12)
                      .fontColor($r('app.color.ts_text_muted'))
                      .lineHeight(16)
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)
                .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                .onClick((): void => {
                  dismissSoftKeyboard();
                  router.pushUrl({
                    url: 'pages/story/StoryDetailPage',
                    params: { storyId: `${s.id}` }
                  });
                })
              }
              .swipeAction({
                end: {
                  builder: (): void => {
                    this.swipeDeleteBuilder();
                  },
                  onAction: (): void => {
                    this.confirmDeleteStory(s);
                  },
                  actionAreaDistance: 56
                },
                edgeEffect: SwipeEdgeEffect.Spring,
                onOffsetChange: (_offset: number): void => {
                  this.swipedStoryId = s.id;
                }
              })
            }, (s: StoryModel): string => `story-${s.id}`)
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        }
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.ts_surface'))
  }
}