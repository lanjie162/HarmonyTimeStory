import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type { StoryModel } from '../../domain/model/Models';
import { getStoryService } from '../../features/story/StoryFeature';
import { dismissSoftKeyboard } from '../../common/ime/SoftKeyboard';
import { MainTabBar } from '../../common/ui/MainTabBar';

@Entry
@Component
export struct StoryPage {
  @State private stories: StoryModel[] = [];
  @State private newTitle: string = '';

  aboutToAppear(): void {
    this.reload();
  }

  private reload(): void {
    this.stories = getStoryService().listStories();
  }

  private createStory(): void {
    dismissSoftKeyboard();
    const svc = getStoryService();
    const id = svc.createStory(this.newTitle);
    if (id < 0) {
      promptAction.showToast({ message: '请输入非空标题' });
      return;
    }
    this.newTitle = '';
    promptAction.showToast({ message: `已创建故事 #${id}` });
    this.reload();
  }

  build() {
    Column({ space: 0 }) {
      Column({ space: 0 }) {
        Row({ space: 10 }) {
          Button('返回')
            .height(36)
            .fontSize($r('app.float.ts_font_support'))
            .backgroundColor($r('app.color.ts_surface_container_high'))
            .fontColor($r('app.color.ts_text_secondary'))
            .onClick((): void => {
              dismissSoftKeyboard();
              router.replaceUrl({ url: 'pages/shell/ShellPage' });
            })
          Text('故事')
            .fontSize($r('app.float.ts_font_title'))
            .fontColor($r('app.color.ts_text_primary'))
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 16, top: 12, bottom: 10 })

        Column({ space: 14 }) {
          Text('新建故事')
            .fontSize($r('app.float.ts_font_label'))
            .fontColor($r('app.color.ts_text_secondary'))
            .fontWeight(FontWeight.Medium)
            .width('100%')
          TextInput({ placeholder: '标题（必填）', text: this.newTitle })
            .onChange((v: string): void => {
              this.newTitle = v;
            })
            .enterKeyType(EnterKeyType.Done)
            .onSubmit((): void => {
              this.createStory();
            })
            .width('100%')
            .height(48)
            .backgroundColor($r('app.color.ts_surface_container_high'))
            .borderRadius(10)
            .padding({ left: 12, right: 12 })
          Button('创建故事')
            .width('100%')
            .height(48)
            .fontSize($r('app.float.ts_font_body'))
            .fontWeight(FontWeight.Medium)
            .backgroundColor($r('app.color.ts_brand_primary'))
            .fontColor($r('app.color.ts_import_bar_on_bg'))
            .onClick((): void => {
              this.createStory();
            })
        }
        .width('100%')
        .padding(16)
        .margin({ left: 16, right: 16, bottom: 12 })
        .backgroundColor($r('app.color.ts_surface_container'))
        .borderRadius(12)
        .border({ width: 1, color: $r('app.color.ts_outline') })

        Divider().color($r('app.color.ts_outline')).margin({ left: 16, right: 16 })

        if (this.stories.length === 0) {
          Column({ space: 8 }) {
            Text('还没有故事')
              .fontSize($r('app.float.ts_font_headline'))
              .fontColor($r('app.color.ts_text_secondary'))
            Text('用故事串起一段时间与地点；创建后可在详情里加照片或导入相册。')
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
                Column({ space: 6 }) {
                  Row() {
                    Text(s.title)
                      .fontSize($r('app.float.ts_font_headline'))
                      .fontColor($r('app.color.ts_text_primary'))
                      .fontWeight(FontWeight.Medium)
                      .layoutWeight(1)
                    Text(`#${s.id}`)
                      .fontSize($r('app.float.ts_font_caption'))
                      .fontColor($r('app.color.ts_text_muted'))
                  }
                  .width('100%')
                  Text('时间线与关联人物')
                    .fontSize($r('app.float.ts_font_overline'))
                    .fontColor($r('app.color.ts_text_tertiary'))
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                .padding({ left: 16, right: 16, top: 14, bottom: 14 })
                .backgroundColor($r('app.color.ts_surface_container'))
                .borderRadius(12)
                .border({ width: 1, color: $r('app.color.ts_outline') })
                .onClick((): void => {
                  dismissSoftKeyboard();
                  router.pushUrl({
                    url: 'pages/story/StoryDetailPage',
                    params: { storyId: `${s.id}` }
                  });
                })
              }
            }, (s: StoryModel): string => `story-${s.id}`)
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        }
      }
      .layoutWeight(1)
      .width('100%')

      MainTabBar({ currentTab: 'story' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.ts_surface'))
  }
}
